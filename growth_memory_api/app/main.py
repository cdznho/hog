from __future__ import annotations

import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from datetime import UTC, datetime
from typing import Any

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


DEFAULT_SQLITE_PATH = (
    Path(__file__).resolve().parent.parent / ".data" / "growth_memory.sqlite3"
)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"sqlite:///{DEFAULT_SQLITE_PATH}",
)

app = FastAPI(title="Growth Memory API")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@contextmanager
def get_conn():
    if DATABASE_URL.startswith("postgresql://"):
        conn = psycopg.connect(DATABASE_URL)
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()
        return

    sqlite_path = DATABASE_URL.removeprefix("sqlite:///")
    Path(sqlite_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def execute_sql(conn: Any, sql: str, params: tuple[Any, ...] = ()) -> Any:
    if isinstance(conn, sqlite3.Connection):
        return conn.execute(sql.replace("%s", "?"), params)
    return conn.execute(sql, params)


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


def json_dumps(value: Any) -> str:
    return json.dumps(value or {})


class OrgUpsert(BaseModel):
    org_id: str
    name: str
    profile: dict[str, Any] = Field(default_factory=dict)


class CycleCreate(BaseModel):
    cycle_id: str
    org_id: str
    cycle_type: str
    goal: str
    inputs: dict[str, Any] = Field(default_factory=dict)


class SnapshotCreate(BaseModel):
    snapshot_id: str
    cycle_id: str
    source: str
    window_start: str
    window_end: str
    data: dict[str, Any] = Field(default_factory=dict)


class ArtifactCreate(BaseModel):
    artifact_id: str
    cycle_id: str
    kind: str
    path: str
    meta: dict[str, Any] = Field(default_factory=dict)


class CoverageInsightRow(BaseModel):
    insight_id: str
    category: str
    subcategory: str
    pillar_status: str
    cluster_current: int
    cluster_target: int
    coverage: str
    priority: str
    meta: dict[str, Any] = Field(default_factory=dict)


class RecommendationInsightRow(BaseModel):
    insight_id: str
    title: str
    status: str
    priority: str
    owner: str
    meta: dict[str, Any] = Field(default_factory=dict)


class InsightReplace(BaseModel):
    rows: list[dict[str, Any]] = Field(default_factory=list)


def migrate() -> None:
    with get_conn() as conn:
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS orgs (
              org_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              profile_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS cycles (
              cycle_id TEXT PRIMARY KEY,
              org_id TEXT NOT NULL REFERENCES orgs(org_id),
              cycle_type TEXT NOT NULL,
              goal TEXT NOT NULL,
              inputs_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS snapshots (
              snapshot_id TEXT PRIMARY KEY,
              cycle_id TEXT NOT NULL REFERENCES cycles(cycle_id),
              source TEXT NOT NULL,
              window_start TEXT NOT NULL,
              window_end TEXT NOT NULL,
              data_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS artifacts (
              artifact_id TEXT PRIMARY KEY,
              cycle_id TEXT NOT NULL REFERENCES cycles(cycle_id),
              kind TEXT NOT NULL,
              path TEXT NOT NULL,
              meta_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS coverage_insights (
              insight_id TEXT PRIMARY KEY,
              cycle_id TEXT NOT NULL REFERENCES cycles(cycle_id),
              category TEXT NOT NULL,
              subcategory TEXT NOT NULL,
              pillar_status TEXT NOT NULL,
              cluster_current INTEGER NOT NULL,
              cluster_target INTEGER NOT NULL,
              coverage TEXT NOT NULL,
              priority TEXT NOT NULL,
              meta_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        execute_sql(
            conn,
            """
            CREATE TABLE IF NOT EXISTS recommendation_insights (
              insight_id TEXT PRIMARY KEY,
              cycle_id TEXT NOT NULL REFERENCES cycles(cycle_id),
              title TEXT NOT NULL,
              status TEXT NOT NULL,
              priority TEXT NOT NULL,
              owner TEXT NOT NULL,
              meta_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )


@app.on_event("startup")
def on_startup() -> None:
    migrate()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/bootstrap")
def bootstrap() -> dict[str, Any]:
    with get_conn() as conn:
        return {
            "orgs": fetch_all(conn, "SELECT org_id, name, profile_json, created_at FROM orgs ORDER BY created_at DESC"),
            "cycles": fetch_all(conn, "SELECT cycle_id, org_id, cycle_type, goal, inputs_json, created_at FROM cycles ORDER BY created_at DESC"),
            "snapshots": fetch_all(conn, "SELECT snapshot_id, cycle_id, source, window_start, window_end, data_json, created_at FROM snapshots ORDER BY created_at DESC"),
            "artifacts": fetch_all(conn, "SELECT artifact_id, cycle_id, kind, path, meta_json, created_at FROM artifacts ORDER BY created_at DESC"),
            "coverage_insights": fetch_all(
                conn,
                "SELECT insight_id, cycle_id, category, subcategory, pillar_status, cluster_current, cluster_target, coverage, priority, meta_json, created_at FROM coverage_insights ORDER BY created_at DESC",
            ),
            "recommendation_insights": fetch_all(
                conn,
                "SELECT insight_id, cycle_id, title, status, priority, owner, meta_json, created_at FROM recommendation_insights ORDER BY created_at DESC",
            ),
        }


def fetch_all(conn: Any, sql: str) -> list[dict[str, Any]]:
    if isinstance(conn, sqlite3.Connection):
        rows = conn.execute(sql).fetchall()
        return [dict(row) for row in rows]

    with conn.cursor() as cur:
        cur.execute(sql)
        columns = [col.name for col in cur.description]
        return [dict(zip(columns, row)) for row in cur.fetchall()]


@app.put("/orgs/{org_id}")
def upsert_org(org_id: str, payload: OrgUpsert) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(
            conn,
            """
            INSERT INTO orgs(org_id, name, profile_json, created_at)
            VALUES(%s, %s, %s, %s)
            ON CONFLICT(org_id) DO UPDATE SET
              name = EXCLUDED.name,
              profile_json = EXCLUDED.profile_json;
            """,
            (org_id, payload.name, json_dumps(payload.profile), utc_now()),
        )
    return {"status": "ok"}


@app.post("/cycles")
def create_cycle(payload: CycleCreate) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(
            conn,
            """
            INSERT INTO cycles(cycle_id, org_id, cycle_type, goal, inputs_json, created_at)
            VALUES(%s, %s, %s, %s, %s, %s);
            """,
            (payload.cycle_id, payload.org_id, payload.cycle_type, payload.goal, json_dumps(payload.inputs), utc_now()),
        )
    return {"status": "ok"}


@app.post("/snapshots")
def create_snapshot(payload: SnapshotCreate) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(
            conn,
            """
            INSERT INTO snapshots(snapshot_id, cycle_id, source, window_start, window_end, data_json, created_at)
            VALUES(%s, %s, %s, %s, %s, %s, %s);
            """,
            (
                payload.snapshot_id,
                payload.cycle_id,
                payload.source,
                payload.window_start,
                payload.window_end,
                json_dumps(payload.data),
                utc_now(),
            ),
        )
    return {"status": "ok"}


@app.post("/artifacts")
def create_artifact(payload: ArtifactCreate) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(
            conn,
            """
            INSERT INTO artifacts(artifact_id, cycle_id, kind, path, meta_json, created_at)
            VALUES(%s, %s, %s, %s, %s, %s);
            """,
            (payload.artifact_id, payload.cycle_id, payload.kind, payload.path, json_dumps(payload.meta), utc_now()),
        )
    return {"status": "ok"}


@app.put("/cycles/{cycle_id}/coverage-insights")
def replace_coverage_insights(cycle_id: str, payload: InsightReplace) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(conn, "DELETE FROM coverage_insights WHERE cycle_id = %s;", (cycle_id,))
        for raw_row in payload.rows:
            row = CoverageInsightRow(**raw_row)
            execute_sql(
                conn,
                """
                INSERT INTO coverage_insights(insight_id, cycle_id, category, subcategory, pillar_status, cluster_current, cluster_target, coverage, priority, meta_json, created_at)
                VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (
                    row.insight_id,
                    cycle_id,
                    row.category,
                    row.subcategory,
                    row.pillar_status,
                    row.cluster_current,
                    row.cluster_target,
                    row.coverage,
                    row.priority,
                    json_dumps(row.meta),
                    utc_now(),
                ),
            )
    return {"status": "ok"}


@app.put("/cycles/{cycle_id}/recommendation-insights")
def replace_recommendation_insights(cycle_id: str, payload: InsightReplace) -> dict[str, str]:
    with get_conn() as conn:
        execute_sql(conn, "DELETE FROM recommendation_insights WHERE cycle_id = %s;", (cycle_id,))
        for raw_row in payload.rows:
            row = RecommendationInsightRow(**raw_row)
            execute_sql(
                conn,
                """
                INSERT INTO recommendation_insights(insight_id, cycle_id, title, status, priority, owner, meta_json, created_at)
                VALUES(%s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (
                    row.insight_id,
                    cycle_id,
                    row.title,
                    row.status,
                    row.priority,
                    row.owner,
                    json_dumps(row.meta),
                    utc_now(),
                ),
            )
    return {"status": "ok"}
