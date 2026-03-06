import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/id.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../data/providers.dart';
import '../../services/report_importer.dart';

class OrgDetailScreen extends ConsumerWidget {
  const OrgDetailScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final refresh = ref.watch(refreshTickProvider);

    if (repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    refresh;
    final org = repo.getOrg(orgId);
    if (org == null) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Org')),
        body: const EmptyState(title: 'Org not found', subtitle: 'This org_id does not exist in your database.'),
      );
    }

    final profile = repo.decodeProfile(org);
    final cycles = repo.listCycles(orgId: orgId);
    final latestCycle = cycles.isNotEmpty ? cycles.first : null;
    final previousCycle = cycles.length > 1 ? cycles[1] : null;
    final latestCoverage = latestCycle == null ? const <dynamic>[] : repo.listCoverageInsights(cycleId: latestCycle.cycleId);
    final previousCoverage = previousCycle == null ? const <dynamic>[] : repo.listCoverageInsights(cycleId: previousCycle.cycleId);
    final latestRecommendations =
        latestCycle == null ? const <dynamic>[] : repo.listRecommendationInsights(cycleId: latestCycle.cycleId);
    final fmt = DateFormat.yMMMd().add_Hm();

    return GradientScaffold(
      appBar: AppBar(
        title: Text(org.name),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final workingCycleIds = <String>[...cycles.map((item) => item.cycleId)];
              if (workingCycleIds.isEmpty) {
                final cycleId = newId('cycle');
                repo.createCycle(
                  cycleId: cycleId,
                  orgId: org.orgId,
                  goal: 'Imported report insights',
                  inputs: const {'source': 'import_from_report'},
                );
                workingCycleIds.add(cycleId);
              }

              final imported = await showDialog<String>(
                context: context,
                builder: (context) => _ImportFromReportDialog(
                  cycleIds: workingCycleIds,
                  onImport: (cycleId, reportPath) async {
                    final importer = ReportImporter.create();
                    final parsed = await importer.importFromPath(reportPath);
                    repo.replaceCoverageInsights(cycleId: cycleId, rows: parsed.coverageRows);
                    repo.replaceRecommendationInsights(cycleId: cycleId, rows: parsed.recommendationRows);
                    repo.attachReportArtifact(
                      artifactId: newId('artifact'),
                      cycleId: cycleId,
                      reportPath: reportPath,
                      meta: {
                        'source': 'html_import',
                        'coverage_count': parsed.coverageRows.length,
                        'recommendation_count': parsed.recommendationRows.length,
                      },
                    );
                  },
                ),
              );
              if (imported != null) {
                ref.read(refreshTickProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported report insights into $imported.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.file_download_done_rounded),
            label: const Text('Import from report'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final workingCycleIds = <String>[...cycles.map((item) => item.cycleId)];
              if (workingCycleIds.isEmpty) {
                final cycleId = newId('cycle');
                repo.createCycle(
                  cycleId: cycleId,
                  orgId: org.orgId,
                  goal: 'Imported structured insights',
                  inputs: const {'source': 'manual_insight_import'},
                );
                workingCycleIds.add(cycleId);
              }

              final cycleId = await showDialog<String>(
                context: context,
                builder: (context) => _ImportInsightsDialog(
                  cycleIds: workingCycleIds,
                  onImport: (cycleId, coverageRows, recommendationRows) {
                    repo.replaceCoverageInsights(cycleId: cycleId, rows: coverageRows);
                    repo.replaceRecommendationInsights(cycleId: cycleId, rows: recommendationRows);
                  },
                ),
              );
              if (cycleId != null) {
                ref.read(refreshTickProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Imported structured insights into $cycleId.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import insights'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () async {
              final result = await showDialog<_NewCycleResult>(
                context: context,
                builder: (context) => _NewCycleDialog(
                  orgName: org.name,
                  hasExistingCycles: cycles.isNotEmpty,
                ),
              );
              if (result == null) return;

              repo.createCycle(
                cycleId: result.cycleId,
                orgId: org.orgId,
                goal: result.goal,
                inputs: result.inputs,
              );
              if (result.reportPath != null && result.reportPath!.trim().isNotEmpty) {
                repo.attachReportArtifact(
                  artifactId: newId('artifact'),
                  cycleId: result.cycleId,
                  reportPath: result.reportPath!.trim(),
                  meta: {'source': 'manual_attach'},
                );
                try {
                  final importer = ReportImporter.create();
                  final parsed = await importer.importFromPath(result.reportPath!.trim());
                  repo.replaceCoverageInsights(cycleId: result.cycleId, rows: parsed.coverageRows);
                  repo.replaceRecommendationInsights(cycleId: result.cycleId, rows: parsed.recommendationRows);
                } catch (_) {
                  // Keep cycle creation resilient even when report parsing fails.
                }
              }
              ref.read(refreshTickProvider.notifier).state++;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle created.')));
              }
            },
            icon: const Icon(Icons.play_circle_rounded),
            label: const Text('New run'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 540,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Org profile'),
                        const SizedBox(height: 12),
                        _KeyValue(label: 'org_id', value: org.orgId),
                        _KeyValue(label: 'created', value: fmt.format(org.createdAt.toLocal())),
                        _KeyValue(label: 'site_url', value: (profile['site_url'] ?? '').toString()),
                        if (profile['industry'] != null) _KeyValue(label: 'industry', value: profile['industry'].toString()),
                        if (profile['audience'] != null) _KeyValue(label: 'audience', value: profile['audience'].toString()),
                        if (profile['competitors'] != null) _KeyValue(label: 'competitors', value: profile['competitors'].toString()),
                        if (profile['goal'] != null) _KeyValue(label: 'goal', value: profile['goal'].toString()),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 540,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Quick commands'),
                        const SizedBox(height: 12),
                        SelectableText(
                          'run_pack llm-seo --org-id ${org.orgId} --site-url ${(profile['site_url'] ?? '').toString()} --industry "${(profile['industry'] ?? '').toString()}" --audience "${(profile['audience'] ?? '').toString()}"',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tip: Set GOOGLE_APPLICATION_CREDENTIALS + GSC_SITE_URL to enable verified mode.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionHeader(
            'Coverage delta',
            trailing: Text(
              latestCycle == null
                  ? 'No cycle'
                  : previousCycle == null
                      ? 'First tracked cycle'
                      : '${latestCycle.cycleId} vs ${previousCycle.cycleId}',
            ),
          ),
          const SizedBox(height: 10),
          if (latestCycle == null)
            const EmptyState(
              title: 'No structured insights yet',
              subtitle: 'Create a run first, then import coverage/recommendation JSON for that cycle.',
            )
          else
            _CoverageDeltaCard(
              currentCycleId: latestCycle.cycleId,
              previousCycleId: previousCycle?.cycleId,
              currentRows: latestCoverage,
              previousRows: previousCoverage,
            ),
          const SizedBox(height: 14),
          SectionHeader('Latest recommendations', trailing: Text('${latestRecommendations.length} tracked')),
          const SizedBox(height: 10),
          if (latestRecommendations.isEmpty)
            const EmptyState(
              title: 'No recommendations stored',
              subtitle: 'Import recommendation rows to track execution status across cycles.',
            )
          else
            ...latestRecommendations.take(8).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: _PriorityDot(priority: item.priority),
                    title: Text(item.title),
                    subtitle: Text('${item.status} • owner: ${item.owner}'),
                    trailing: Chip(label: Text(item.priority)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          SectionHeader('Cycles', trailing: Text('${cycles.length} total')),
          const SizedBox(height: 10),
          if (cycles.isEmpty)
            const EmptyState(
              title: 'No cycles yet',
              subtitle: 'Create a run to store a new cycle + artifacts.',
            )
          else
            ...cycles.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt_rounded),
                    title: Text('${c.cycleType} • ${fmt.format(c.createdAt.toLocal())}'),
                    subtitle: Text(c.goal),
                    trailing: _InputsChip(json: c.inputsJson),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverageDeltaCard extends StatelessWidget {
  const _CoverageDeltaCard({
    required this.currentCycleId,
    required this.previousCycleId,
    required this.currentRows,
    required this.previousRows,
  });

  final String currentCycleId;
  final String? previousCycleId;
  final List<dynamic> currentRows;
  final List<dynamic> previousRows;

  @override
  Widget build(BuildContext context) {
    final previousMap = {
      for (final row in previousRows) _coverageKey(row.category, row.subcategory): row,
    };
    final improved = <dynamic>[];
    final unchanged = <dynamic>[];
    final regressed = <dynamic>[];
    final added = <dynamic>[];

    for (final row in currentRows) {
      final key = _coverageKey(row.category, row.subcategory);
      final prev = previousMap[key];
      if (prev == null) {
        added.add(row);
        continue;
      }
      final scoreDelta = _coverageScore(row.coverage) - _coverageScore(prev.coverage);
      final clusterDelta = row.clusterCurrent - prev.clusterCurrent;
      if (scoreDelta > 0 || clusterDelta > 0) {
        improved.add({'current': row, 'previous': prev, 'clusterDelta': clusterDelta});
      } else if (scoreDelta < 0 || clusterDelta < 0) {
        regressed.add({'current': row, 'previous': prev, 'clusterDelta': clusterDelta});
      } else {
        unchanged.add({'current': row, 'previous': prev, 'clusterDelta': clusterDelta});
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text('Improved ${improved.length}')),
                Chip(label: Text('Regressed ${regressed.length}')),
                Chip(label: Text('Unchanged ${unchanged.length}')),
                Chip(label: Text('New ${added.length}')),
              ],
            ),
            const SizedBox(height: 14),
            if (currentRows.isEmpty)
              const Text('No coverage rows imported for the latest cycle yet.')
            else ...[
              Text('Current cycle: $currentCycleId', style: Theme.of(context).textTheme.titleSmall),
              if (previousCycleId != null) Text('Previous cycle: $previousCycleId'),
              const SizedBox(height: 14),
              ...currentRows.take(8).map((row) {
                final key = _coverageKey(row.category, row.subcategory);
                final prev = previousMap[key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CoverageDeltaRow(current: row, previous: prev),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

String _coverageKey(Object? category, Object? subcategory) {
  String normalize(Object? value) => (value?.toString() ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return '${normalize(category)}::${normalize(subcategory)}';
}

class _CoverageDeltaRow extends StatelessWidget {
  const _CoverageDeltaRow({required this.current, required this.previous});

  final dynamic current;
  final dynamic previous;

  @override
  Widget build(BuildContext context) {
    final currentScore = _coverageScore(current.coverage);
    final previousScore = previous == null ? null : _coverageScore(previous.coverage);
    final currentClusters = current.clusterCurrent as int;
    final previousClusters = previous == null ? null : previous.clusterCurrent as int;
    final theme = Theme.of(context);
    final deltaText = previous == null
        ? 'New'
        : '${_formatSigned(currentScore - previousScore!)} coverage, ${_formatSigned(currentClusters - previousClusters!)} clusters';
    Color deltaColor;
    if (previous == null) {
      deltaColor = theme.colorScheme.secondary;
    } else if (currentScore > previousScore! || currentClusters > previousClusters!) {
      deltaColor = Colors.green;
    } else if (currentScore < previousScore || currentClusters < previousClusters) {
      deltaColor = Colors.red;
    } else {
      deltaColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _CoverageDot(coverage: current.coverage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${current.category} / ${current.subcategory}', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '${current.coverage} • ${current.clusterCurrent}/${current.clusterTarget} clusters • pillar ${current.pillarStatus}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(deltaText, style: TextStyle(color: deltaColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CoverageDot extends StatelessWidget {
  const _CoverageDot({required this.coverage});

  final String coverage;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (coverage.toLowerCase()) {
      case 'empty':
        color = Colors.red;
      case 'thin':
        color = Colors.deepOrange;
      case 'partial':
        color = Colors.amber.shade700;
      case 'strong':
      case 'complete':
        color = Colors.green;
      default:
        color = Theme.of(context).colorScheme.primary;
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.red;
      case 'med':
      case 'medium':
        color = Colors.amber.shade700;
      case 'low':
        color = Colors.green;
      default:
        color = Theme.of(context).colorScheme.primary;
    }
    return CircleAvatar(radius: 10, backgroundColor: color);
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _InputsChip extends StatelessWidget {
  const _InputsChip({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    try {
      final map = jsonDecode(json);
      if (map is Map && map.isNotEmpty) {
        final keys = map.keys.take(2).map((k) => k.toString()).join(', ');
        return Chip(label: Text('inputs: $keys'));
      }
    } catch (_) {}
    return const Chip(label: Text('inputs'));
  }
}

class _NewCycleResult {
  const _NewCycleResult({
    required this.cycleId,
    required this.goal,
    required this.inputs,
    this.reportPath,
  });

  final String cycleId;
  final String goal;
  final Map<String, Object?> inputs;
  final String? reportPath;
}

class _NewCycleDialog extends StatefulWidget {
  const _NewCycleDialog({
    required this.orgName,
    required this.hasExistingCycles,
  });

  final String orgName;
  final bool hasExistingCycles;

  @override
  State<_NewCycleDialog> createState() => _NewCycleDialogState();
}

class _NewCycleDialogState extends State<_NewCycleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _goal = TextEditingController(
    text: widget.hasExistingCycles ? 'Measure delta vs previous cycle' : 'Generate verified baseline + priorities',
  );
  final _sectionFilter = TextEditingController();
  final _inspectUrls = TextEditingController();
  final _reportPath = TextEditingController();

  @override
  void dispose() {
    _goal.dispose();
    _sectionFilter.dispose();
    _inspectUrls.dispose();
    _reportPath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.hasExistingCycles ? 'New cycle for ${widget.orgName}' : 'New first run for ${widget.orgName}';
    final reportHelper = widget.hasExistingCycles
        ? 'Paste this cycle\'s report URL or HTML path and the app will try to import the new insights automatically.'
        : 'Optional for the first cycle. You can import later via the org page.';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _goal,
                  decoration: InputDecoration(
                    labelText: 'Goal',
                    helperText: widget.hasExistingCycles
                        ? 'Describe what changed since the last cycle or what you want to measure next.'
                        : 'Describe the baseline you want this first cycle to establish.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sectionFilter,
                  decoration: const InputDecoration(
                    labelText: 'Section filter (optional, e.g. /learn/)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _inspectUrls,
                  decoration: const InputDecoration(
                    labelText: 'Inspect URLs (optional, comma-separated)',
                    helperText: 'Homepage, hub, and top money pages (kept small for quota).',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reportPath,
                  decoration: InputDecoration(
                    labelText: 'Report HTML path or URL (optional)',
                    helperText: reportHelper,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final cycleId = newId('cycle');
            final inputs = <String, Object?>{
              if (_sectionFilter.text.trim().isNotEmpty) 'section_filter': _sectionFilter.text.trim(),
              if (_inspectUrls.text.trim().isNotEmpty)
                'inspect_urls': _inspectUrls.text
                    .split(',')
                    .map((u) => u.trim())
                    .where((u) => u.isNotEmpty)
                    .toList(),
            };
            Navigator.of(context).pop(
              _NewCycleResult(
                cycleId: cycleId,
                goal: _goal.text.trim(),
                inputs: inputs,
                reportPath: _reportPath.text.trim().isEmpty ? null : _reportPath.text.trim(),
              ),
            );
          },
          child: const Text('Create run'),
        ),
      ],
    );
  }
}

class _ImportInsightsDialog extends StatefulWidget {
  const _ImportInsightsDialog({
    required this.cycleIds,
    required this.onImport,
  });

  final List<String> cycleIds;
  final void Function(
    String cycleId,
    List<Map<String, Object?>> coverageRows,
    List<Map<String, Object?>> recommendationRows,
  ) onImport;

  @override
  State<_ImportInsightsDialog> createState() => _ImportInsightsDialogState();
}

class _ImportFromReportDialog extends StatefulWidget {
  const _ImportFromReportDialog({
    required this.cycleIds,
    required this.onImport,
  });

  final List<String> cycleIds;
  final Future<void> Function(String cycleId, String reportPath) onImport;

  @override
  State<_ImportFromReportDialog> createState() => _ImportFromReportDialogState();
}

class _ImportFromReportDialogState extends State<_ImportFromReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _cycleId = widget.cycleIds.first;
  final _path = TextEditingController(text: '/Users/cedricdeschaut/code/hog/mbrella/index.html');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from HTML report'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _cycleId,
                items: [for (final id in widget.cycleIds) DropdownMenuItem(value: id, child: Text(id))],
                onChanged: _busy ? null : (v) => setState(() => _cycleId = v ?? _cycleId),
                decoration: const InputDecoration(labelText: 'cycle_id'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _path,
                decoration: const InputDecoration(labelText: 'HTML report path or URL'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Supported today: coverage heatmap rows and Phase 5 quick wins from generated HTML reports.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await widget.onImport(_cycleId, _path.text.trim());
                    if (!mounted) return;
                    Navigator.of(context).pop(_cycleId);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _error = e.toString();
                      _busy = false;
                    });
                  }
                },
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Import'),
        ),
      ],
    );
  }
}

class _ImportInsightsDialogState extends State<_ImportInsightsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _cycleId = widget.cycleIds.first;
  final _coverageJson = TextEditingController();
  final _recommendationsJson = TextEditingController();

  @override
  void dispose() {
    _coverageJson.dispose();
    _recommendationsJson.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import structured insights'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _cycleId,
                  items: [for (final id in widget.cycleIds) DropdownMenuItem(value: id, child: Text(id))],
                  onChanged: (v) => setState(() => _cycleId = v ?? _cycleId),
                  decoration: const InputDecoration(labelText: 'cycle_id'),
                ),
                const SizedBox(height: 12),
                Text('Coverage JSON', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Paste an array of rows. Required keys: category, subcategory, pillar_status, cluster_current, cluster_target, coverage, priority.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _coverageJson,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: '[{"category":"Mobility Budget","subcategory":"Legal Framework","pillar_status":"Missing","cluster_current":0,"cluster_target":5,"coverage":"Empty","priority":"High"}]',
                  ),
                  validator: (value) => _validateJsonArray(value),
                ),
                const SizedBox(height: 12),
                Text('Recommendations JSON', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Optional array. Keys: title, status, priority, owner.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recommendationsJson,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '[{"title":"Publish legal framework pillar","status":"Open","priority":"High","owner":"SEO"}]',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    return _validateJsonArray(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final coverageRows = _decodeRows(_coverageJson.text.trim());
            final recommendationRows = _recommendationsJson.text.trim().isEmpty
                ? <Map<String, Object?>>[]
                : _decodeRows(_recommendationsJson.text.trim());
            widget.onImport(_cycleId, coverageRows, recommendationRows);
            Navigator.of(context).pop(_cycleId);
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}

String? _validateJsonArray(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Required';
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return 'Must be a JSON array';
    return null;
  } catch (_) {
    return 'Invalid JSON';
  }
}

List<Map<String, Object?>> _decodeRows(String text) {
  final decoded = jsonDecode(text) as List;
  return [
    for (final row in decoded)
      if (row is Map) row.map((key, value) => MapEntry(key.toString(), value))
  ];
}

int _coverageScore(String coverage) {
  switch (coverage.toLowerCase()) {
    case 'empty':
      return 0;
    case 'thin':
      return 1;
    case 'partial':
      return 2;
    case 'strong':
    case 'complete':
      return 3;
    default:
      return 0;
  }
}

String _formatSigned(int value) {
  if (value > 0) return '+$value';
  return '$value';
}
