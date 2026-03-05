import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/id.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../data/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final refresh = ref.watch(refreshTickProvider);

    if (repo == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    refresh;

    final artifacts = repo.listArtifacts();
    final cycles = repo.listCycles();
    final fmt = DateFormat.yMMMd().add_Hm();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          FilledButton.icon(
            onPressed: cycles.isEmpty
                ? null
                : () async {
                    final attached = await showDialog<_AttachResult>(
                      context: context,
                      builder: (context) => _AttachDialog(cycleIds: cycles.map((c) => c.cycleId).toList()),
                    );
                    if (attached == null) return;
                    repo.attachReportArtifact(
                      artifactId: newId('artifact'),
                      cycleId: attached.cycleId,
                      reportPath: attached.path,
                      meta: {'source': 'manual_attach', ...attached.meta},
                    );
                    ref.read(refreshTickProvider.notifier).state++;
                  },
            icon: const Icon(Icons.attach_file_rounded),
            label: const Text('Attach report'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: artifacts.isEmpty
          ? const EmptyState(
              title: 'No report artifacts yet',
              subtitle: 'Attach an HTML/PDF report to a cycle to build the evidence trail.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: artifacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final a = artifacts[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.article_rounded),
                    title: Text(a.path),
                    subtitle: Text('${a.kind} • cycle_id: ${a.cycleId}\n${fmt.format(a.createdAt.toLocal())}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_looksLikeUrlOrFile(a.path))
                          IconButton(
                            tooltip: 'Open',
                            onPressed: () => _openPath(a.path),
                            icon: const Icon(Icons.open_in_new_rounded),
                          ),
                        _MetaChip(json: a.metaJson),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

bool _looksLikeUrlOrFile(String path) {
  final p = path.trim();
  return p.startsWith('http://') || p.startsWith('https://') || p.startsWith('file://') || p.endsWith('.html') || p.endsWith('.pdf');
}

Future<void> _openPath(String path) async {
  final p = path.trim();
  final uri = p.startsWith('http') || p.startsWith('file://') ? Uri.parse(p) : Uri.file(p);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    try {
      final value = jsonDecode(json);
      if (value is Map && value.isNotEmpty) {
        return Chip(label: Text('${value.length} meta'));
      }
    } catch (_) {}
    return const Chip(label: Text('meta'));
  }
}

class _AttachResult {
  const _AttachResult({required this.cycleId, required this.path, required this.meta});

  final String cycleId;
  final String path;
  final Map<String, Object?> meta;
}

class _AttachDialog extends StatefulWidget {
  const _AttachDialog({required this.cycleIds});

  final List<String> cycleIds;

  @override
  State<_AttachDialog> createState() => _AttachDialogState();
}

class _AttachDialogState extends State<_AttachDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _cycleId = widget.cycleIds.first;
  final _path = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Attach report artifact'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _cycleId,
                items: [for (final id in widget.cycleIds) DropdownMenuItem(value: id, child: Text(id))],
                onChanged: (v) => setState(() => _cycleId = v ?? _cycleId),
                decoration: const InputDecoration(labelText: 'cycle_id'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _path,
                decoration: const InputDecoration(labelText: 'Report path (HTML/PDF) or URL'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _AttachResult(
                cycleId: _cycleId,
                path: _path.text.trim(),
                meta: _note.text.trim().isEmpty ? {} : {'note': _note.text.trim()},
              ),
            );
          },
          child: const Text('Attach'),
        ),
      ],
    );
  }
}

