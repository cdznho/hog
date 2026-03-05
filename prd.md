# PRD: Outcome-Verified “LLM SEO Strategy Pack” + Growth Memory (GSC-Backed)

## 1) Summary
Build a narrow productized workflow (“pack”) that produces an LLM SEO / GEO strategy report **grounded in verified Google Search Console (GSC) data** and persists everything into an org-scoped **system of record** (“Growth Memory”). The same org can re-run weekly to compound context, measure deltas, and reuse prior learnings.

This is designed to be:
- Sellable as a fixed-scope deliverable (a sprint)
- Sticky via weekly re-runs (retention)
- Defensible via accumulating org-specific history (memory + evidence)

## 2) Problem
Current LLM SEO strategy outputs are often perceived as:
- Generic (not specific to the site’s current reality)
- Unverified (“baseline needed”, “audit required”, unknown pass/fail)
- Hard to measure over time (no canonical snapshots, no deltas, no evidence trail)

Founders will pay more and trust more if:
- The report uses their real GSC data, URL inspection, and index coverage
- The system stores baselines and subsequent snapshots
- The system can say what changed week-over-week

## 3) Goals (MVP)
1. Produce a strategy report where key baseline sections are **auto-populated from GSC**.
2. Provide a **Technical Readiness Gate** backed by evidence (URL inspection, index coverage summary).
3. Persist org + cycle + inputs + outputs + snapshots into a queryable store.
4. Enable a weekly cadence: every new run creates a new cycle and computes deltas vs last cycle.

## 4) Non-Goals (MVP)
- Full “do the work” execution (publishing content, editing Webflow, etc.)
- Full ROI attribution to revenue/pipeline (can come later via HubSpot/Stripe)
- OAuth multi-tenant web app (start with BYOC credentials + local runner)

## 5) Target Users
- Primary: Sales-led SaaS founder (or founder-led growth owner) who wants “LLM visibility”
- Secondary: Consultant/agency delivering the sprint to clients

## 6) Product Concept: Packs + Memory
### Pack
A pack is a repeatable workflow producing a structured output.
MVP pack: `llm-seo`.

### Growth Memory (System of Record)
The store holds:
- Org profile (site, niche, audience, competitors, goals)
- Cycles (weekly runs) with inputs
- Evidence snapshots (GSC metrics + URL inspection summaries)
- Artifacts (report files, CSV exports, prompt logs)

## 7) User Flow (MVP)
### A) One-time Setup (BYOC credentials)
1. User creates/uses Google service account JSON.
2. User grants it access to their GSC property (read-only is acceptable for MVP; “Full” if URL Inspection/Sitemaps required).
3. User sets env vars:
   - `GOOGLE_APPLICATION_CREDENTIALS=/path/key.json`
   - `GSC_SITE_URL=https://domain.com/` or `sc-domain:domain.com`

### B) Run Pack (Week 1)
1. User runs CLI with org context (site URL, industry, audience, competitors, goal).
2. System pulls a GSC baseline snapshot (last 28 days, ends 3 days ago).
3. System optionally runs URL inspection checks for a set of critical URLs:
   - homepage
   - /blog or /learn hub (if exists)
   - top 3 money pages / service pages (provided by user or inferred later)
4. System generates the report:
   - Includes “Verified Baseline” tables (queries/pages/index coverage)
   - Marks unknowns only when a signal truly can’t be obtained from GSC
5. System persists cycle + snapshots + report artifact.

### C) Weekly Re-run (Week 2+)
1. User runs CLI again (same org_id).
2. System pulls current snapshot and compares to prior cycle:
   - deltas for non-brand impressions/clicks/CTR
   - changes in indexed pages / coverage issues
   - page winners/losers, CTR gap list
3. Report includes “Since last week” section + updated priorities.

## 8) Requirements

### 8.1 CLI
Command:
- `run_pack llm-seo --org-id ... --site-url ... --industry ... --audience ...`

Options:
- `--use-gsc` (default true if env vars exist; otherwise warn and run in “unverified mode”)
- `--inspect-urls` list (optional)
- `--section-filter` (e.g., `/learn/`)
- `--dry-run` (no model call; still writes store + skeleton report)

Output:
- Print `cycle_id`, report path, db path.

### 8.2 GSC Data to Pull (MVP)
Using Search Console API:
- Query performance (top queries by impressions; filter by section if provided)
- Page performance (top pages by impressions; filter by section if provided)
- Index coverage summary (counts by state; sample URLs per state if available)
- URL inspection (optional; limited list to control quota/time)

Default time window:
- 28 days, end = 3 days ago (handle GSC lag)

### 8.3 Report Changes (MVP)
The report must contain:
- **Evidence block**: property used, date window, data freshness warning
- **Baseline table**: top pages + top queries + CTR gap list
- **Technical gate**: derived from inspection + coverage signals
  - If inspection shows blocked/excluded, gate fails with explicit evidence
- **Measurement dashboard**: “Current” populated, not “baseline needed”
- **Open questions**: clearly separated from verified facts

### 8.4 System of Record (Data Model)
Tables / entities (SQLite ok):
- `orgs(org_id, name, profile_json, created_at)`
- `cycles(cycle_id, org_id, cycle_type, goal, inputs_json, created_at)`
- `snapshots(snapshot_id, cycle_id, source, window_start, window_end, data_json, created_at)`
- `artifacts(artifact_id, cycle_id, kind, path, meta_json, created_at)`

Snapshot `data_json` (GSC):
- `top_queries[]` (query, impressions, clicks, ctr, position, flags)
- `top_pages[]` (url, impressions, clicks, ctr, position, flags)
- `coverage_summary` (indexed_count, excluded_count, errors_count, notes)
- `inspections[]` (url, verdict, canonical, last_crawl, issues[])

### 8.5 Verification Rules (MVP)
- Any “Pass/Fail” in the Technical Gate must cite a specific GSC-derived signal:
  - URL inspection verdict, coverage errors, or inability to fetch URLs (if implemented separately)
- If GSC is not connected:
  - Report must clearly label sections as “Unverified” and avoid hard pass/fail claims.

## 9) Security / Data Handling
MVP stance: **BYOC + local execution**
- Do not upload or store credentials.
- Store only derived metrics and report artifacts locally.
- Make export easy (zip of report + JSON snapshots).

Future (optional): hosted mode with OAuth + encryption + tenancy.

## 10) Success Metrics (MVP)
- Time to first “verified report”: < 15 minutes from install + env setup
- % of reports with “Current” populated for baseline dashboard: > 90% when GSC connected
- Weekly retention proxy: user re-runs pack ≥ 3 consecutive weeks
- Qualitative: founders say “this feels specific to my site” (not generic)

## 11) Milestones
1. CLI can run pack without model deps (help works, dry-run works).
2. GSC connector pulls snapshot and stores it.
3. Report template consumes snapshot and renders verified baseline.
4. Weekly delta computation + “since last cycle” section.
5. Packaging polish: clear docs, example commands, export.

## 12) Risks / Open Questions
- GSC API quotas and URL inspection limits: keep inspection list small and user-controlled.
- Some “technical readiness” items aren’t observable via GSC alone (canonicals/metadata/schema): either
  - add a lightweight crawler later, or
  - keep them as “requires site audit” with explicit confidence labels.
- Multi-tenant hosted version adds major scope (OAuth, storage, compliance); defer until the pack sells.

## 13) Acceptance Criteria (MVP)
- Running the pack with GSC configured produces a report with:
  - populated baseline metrics
  - explicit evidence block (property + date window)
  - no “baseline needed” placeholders for metrics available from GSC
- A second run for the same org produces:
  - a new cycle
  - a delta section comparing to the previous cycle
- Store contains org + cycles + snapshots + artifacts, all queryable by org_id.
