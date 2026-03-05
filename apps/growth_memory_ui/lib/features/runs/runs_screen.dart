import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/id.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../data/providers.dart';
import '../../services/pack_runner.dart';

class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final refresh = ref.watch(refreshTickProvider);

    if (repo == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    refresh;

    final orgs = repo.listOrgs();
    final cycles = repo.listCycles();
    final fmt = DateFormat.yMMMd().add_Hm();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Runs'),
        actions: [
          OutlinedButton.icon(
            onPressed: orgs.isEmpty
                ? null
                : () async {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => _RunPackDialog(orgIds: orgs.map((o) => o.orgId).toList()),
                    );
                    ref.read(refreshTickProvider.notifier).state++;
                  },
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Run pack (beta)'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: orgs.isEmpty
                ? null
                : () async {
                    final result = await showDialog<_RunNowResult>(
                      context: context,
                      builder: (context) => _RunNowDialog(orgIds: orgs.map((o) => o.orgId).toList()),
                    );
                    if (result == null) return;

                    repo.createCycle(
                      cycleId: result.cycleId,
                      orgId: result.orgId,
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
                  },
            icon: const Icon(Icons.play_circle_rounded),
            label: const Text('New run'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cycles.isEmpty
          ? EmptyState(
              title: 'No runs yet',
              subtitle: orgs.isEmpty
                  ? 'Create an org first.'
                  : 'Start your first cycle to store a snapshot + artifact trail.',
              action: orgs.isEmpty
                  ? FilledButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create an org in the Orgs tab first.')),
                      ),
                      icon: const Icon(Icons.apartment_rounded),
                      label: const Text('Go to Orgs'),
                    )
                  : FilledButton.icon(
                      onPressed: () => showDialog<_RunNowResult>(
                        context: context,
                        builder: (context) => _RunNowDialog(orgIds: orgs.map((o) => o.orgId).toList()),
                      ).then((result) {
                        if (result == null) return;
                        repo.createCycle(
                          cycleId: result.cycleId,
                          orgId: result.orgId,
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
                      }),
                      icon: const Icon(Icons.play_circle_rounded),
                      label: const Text('Start run'),
                    ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cycles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cycle = cycles[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt_rounded),
                    title: Text('${cycle.cycleType} • ${fmt.format(cycle.createdAt.toLocal())}'),
                    subtitle: Text('org_id: ${cycle.orgId}\n${cycle.goal}'),
                    isThreeLine: true,
                    trailing: _InputsChip(json: cycle.inputsJson),
                  ),
                );
              },
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
      final value = jsonDecode(json);
      if (value is Map && value.isNotEmpty) {
        return Chip(label: Text('${value.length} inputs'));
      }
    } catch (_) {}
    return const Chip(label: Text('inputs'));
  }
}

class _RunNowResult {
  const _RunNowResult({
    required this.cycleId,
    required this.orgId,
    required this.goal,
    required this.inputs,
    this.reportPath,
  });

  final String cycleId;
  final String orgId;
  final String goal;
  final Map<String, Object?> inputs;
  final String? reportPath;
}

class _RunNowDialog extends StatefulWidget {
  const _RunNowDialog({required this.orgIds});

  final List<String> orgIds;

  @override
  State<_RunNowDialog> createState() => _RunNowDialogState();
}

class _RunNowDialogState extends State<_RunNowDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _orgId = widget.orgIds.first;
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
      title: const Text('New run'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _orgId,
                  items: [for (final id in widget.orgIds) DropdownMenuItem(value: id, child: Text(id))],
                  onChanged: (v) => setState(() => _orgId = v ?? _orgId),
                  decoration: const InputDecoration(labelText: 'org_id'),
                ),
                const SizedBox(height: 10),
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
                  decoration: const InputDecoration(labelText: 'Inspect URLs (optional, comma-separated)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reportPath,
                  decoration: const InputDecoration(labelText: 'Attach report HTML path (optional)'),
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
              _RunNowResult(
                cycleId: newId('cycle'),
                orgId: _orgId,
                goal: _goal.text.trim(),
                inputs: inputs,
                reportPath: _reportPath.text.trim().isEmpty ? null : _reportPath.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _RunPackDialog extends ConsumerStatefulWidget {
  const _RunPackDialog({required this.orgIds});

  final List<String> orgIds;

  @override
  ConsumerState<_RunPackDialog> createState() => _RunPackDialogState();
}

class _RunPackDialogState extends ConsumerState<_RunPackDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _orgId = widget.orgIds.first;
  final _goal = TextEditingController(text: 'Generate verified baseline + priorities');
  final _sectionFilter = TextEditingController();
  final _inspectUrls = TextEditingController();

  bool _running = false;
  String? _stdout;
  String? _stderr;
  int? _exitCode;
  String? _reportPath;

  @override
  void dispose() {
    _goal.dispose();
    _sectionFilter.dispose();
    _inspectUrls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    if (repo == null) {
      return const AlertDialog(content: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())));
    }

    return AlertDialog(
      title: const Text('Run llm-seo pack (beta)'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _orgId,
                  items: [for (final id in widget.orgIds) DropdownMenuItem(value: id, child: Text(id))],
                  onChanged: _running ? null : (v) => setState(() => _orgId = v ?? _orgId),
                  decoration: const InputDecoration(labelText: 'org_id'),
                ),
                const SizedBox(height: 10),
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
                  decoration: const InputDecoration(labelText: 'Inspect URLs (optional, comma-separated)'),
                ),
                const SizedBox(height: 14),
                if (_exitCode != null) ...[
                  Row(
                    children: [
                      Chip(label: Text('exit: $_exitCode')),
                      const SizedBox(width: 10),
                      if (_reportPath != null) Expanded(child: SelectableText('report: $_reportPath')),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_stderr != null && _stderr!.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('stderr', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    ),
                    child: SelectableText(_stderr!),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_stdout != null && _stdout!.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('stdout', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    ),
                    child: SelectableText(_stdout!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _running ? null : () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton.icon(
          onPressed: _running
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  final org = repo.getOrg(_orgId);
                  if (org == null) return;
                  final profile = repo.decodeProfile(org);
                  final siteUrl = (profile['site_url'] ?? '').toString();
                  if (siteUrl.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Org is missing site_url.')));
                    return;
                  }

                  setState(() {
                    _running = true;
                    _stdout = null;
                    _stderr = null;
                    _exitCode = null;
                    _reportPath = null;
                  });

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
                  repo.createCycle(cycleId: cycleId, orgId: _orgId, goal: _goal.text.trim(), inputs: inputs);

                  final runner = PackRunner.create();
                  try {
                    final result = await runner.runLlmSeo(
                      orgId: _orgId,
                      siteUrl: siteUrl,
                      industry: profile['industry']?.toString(),
                      audience: profile['audience']?.toString(),
                      competitors: profile['competitors']?.toString(),
                      goal: _goal.text.trim(),
                      sectionFilter: _sectionFilter.text.trim().isEmpty ? null : _sectionFilter.text.trim(),
                      inspectUrls: (inputs['inspect_urls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
                    );

                    if (!mounted) return;
                    setState(() {
                      _exitCode = result.exitCode;
                      _stdout = result.stdout;
                      _stderr = result.stderr;
                      _reportPath = result.reportPath;
                    });

                    if (result.reportPath != null && result.reportPath!.trim().isNotEmpty) {
                      repo.attachReportArtifact(
                        artifactId: newId('artifact'),
                        cycleId: cycleId,
                        reportPath: result.reportPath!.trim(),
                        meta: {'source': 'runner_detected'},
                      );
                    }

                    ref.read(refreshTickProvider.notifier).state++;
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _stderr = 'Failed to run pack: $e';
                    });
                  } finally {
                    if (mounted) {
                      setState(() => _running = false);
                    }
                  }
                },
          icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded),
          label: const Text('Run now'),
        ),
      ],
    );
  }
}
