import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/id.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../data/providers.dart';

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
    final fmt = DateFormat.yMMMd().add_Hm();

    return GradientScaffold(
      appBar: AppBar(
        title: Text(org.name),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              final result = await showDialog<_NewCycleResult>(
                context: context,
                builder: (context) => _NewCycleDialog(orgName: org.name),
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
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 12),
              Expanded(
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
  const _NewCycleDialog({required this.orgName});

  final String orgName;

  @override
  State<_NewCycleDialog> createState() => _NewCycleDialogState();
}

class _NewCycleDialogState extends State<_NewCycleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _goal = TextEditingController(text: 'Generate verified baseline + priorities');
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
    return AlertDialog(
      title: Text('New run for ${widget.orgName}'),
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
                  decoration: const InputDecoration(labelText: 'Goal'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sectionFilter,
                  decoration: const InputDecoration(labelText: 'Section filter (optional, e.g. /learn/)'),
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
                  decoration: const InputDecoration(
                    labelText: 'Attach report HTML path (optional)',
                    helperText: 'You can attach later via Reports tab.',
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

