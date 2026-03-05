import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/id.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../data/providers.dart';

class OrgsScreen extends ConsumerWidget {
  const OrgsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(dbProvider);
    final refresh = ref.watch(refreshTickProvider);
    final repo = ref.watch(repositoryProvider);

    return dbAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('DB error: $e'))),
      data: (_) {
        if (repo == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        refresh;
        final orgs = repo.listOrgs();

        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Orgs'),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  final created = await showDialog<_CreateOrgResult>(
                    context: context,
                    builder: (context) => const _CreateOrgDialog(),
                  );
                  if (created == null) return;
                  repo.upsertOrg(
                    orgId: created.orgId,
                    name: created.name,
                    siteUrl: created.siteUrl,
                    industry: created.industry,
                    audience: created.audience,
                    competitors: created.competitors,
                    goal: created.goal,
                  );
                  ref.read(refreshTickProvider.notifier).state++;
                  if (context.mounted) context.go('/orgs/${created.orgId}');
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New org'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: orgs.isEmpty
              ? EmptyState(
                  title: 'No orgs yet',
                  subtitle: 'Create an org profile (site URL + context). Then run the llm-seo pack and attach the report.',
                  action: FilledButton.icon(
                    onPressed: () => showDialog<_CreateOrgResult>(
                      context: context,
                      builder: (context) => const _CreateOrgDialog(),
                    ).then((created) {
                      if (created == null) return;
                      repo.upsertOrg(
                        orgId: created.orgId,
                        name: created.name,
                        siteUrl: created.siteUrl,
                        industry: created.industry,
                        audience: created.audience,
                        competitors: created.competitors,
                        goal: created.goal,
                      );
                      ref.read(refreshTickProvider.notifier).state++;
                      if (context.mounted) context.go('/orgs/${created.orgId}');
                    }),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create org'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orgs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final org = orgs[index];
                    final profile = repo.decodeProfile(org);
                    final siteUrl = (profile['site_url'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.apartment_rounded),
                        title: Text(org.name),
                        subtitle: Text(siteUrl.isEmpty ? org.orgId : '${org.orgId} • $siteUrl'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/orgs/${org.orgId}'),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _CreateOrgResult {
  const _CreateOrgResult({
    required this.orgId,
    required this.name,
    required this.siteUrl,
    this.industry,
    this.audience,
    this.competitors,
    this.goal,
  });

  final String orgId;
  final String name;
  final String siteUrl;
  final String? industry;
  final String? audience;
  final String? competitors;
  final String? goal;
}

class _CreateOrgDialog extends StatefulWidget {
  const _CreateOrgDialog();

  @override
  State<_CreateOrgDialog> createState() => _CreateOrgDialogState();
}

class _CreateOrgDialogState extends State<_CreateOrgDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _orgId = TextEditingController(text: newId('org'));
  final TextEditingController _name = TextEditingController();
  final TextEditingController _siteUrl = TextEditingController(text: 'https://');
  final TextEditingController _industry = TextEditingController();
  final TextEditingController _audience = TextEditingController();
  final TextEditingController _competitors = TextEditingController();
  final TextEditingController _goal = TextEditingController();

  @override
  void dispose() {
    _orgId.dispose();
    _name.dispose();
    _siteUrl.dispose();
    _industry.dispose();
    _audience.dispose();
    _competitors.dispose();
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create org'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _orgId,
                  decoration: const InputDecoration(labelText: 'org_id'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _siteUrl,
                  decoration: const InputDecoration(labelText: 'Site URL (GSC property)'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Required';
                    if (!value.startsWith('http') && !value.startsWith('sc-domain:')) return 'Use https://... or sc-domain:...';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _industry, decoration: const InputDecoration(labelText: 'Industry (optional)')),
                const SizedBox(height: 10),
                TextFormField(controller: _audience, decoration: const InputDecoration(labelText: 'Audience (optional)')),
                const SizedBox(height: 10),
                TextFormField(controller: _competitors, decoration: const InputDecoration(labelText: 'Competitors (optional)')),
                const SizedBox(height: 10),
                TextFormField(controller: _goal, decoration: const InputDecoration(labelText: 'Goal (optional)')),
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
            Navigator.of(context).pop(
              _CreateOrgResult(
                orgId: _orgId.text.trim(),
                name: _name.text.trim(),
                siteUrl: _siteUrl.text.trim(),
                industry: _industry.text.trim().isEmpty ? null : _industry.text.trim(),
                audience: _audience.text.trim().isEmpty ? null : _audience.text.trim(),
                competitors: _competitors.text.trim().isEmpty ? null : _competitors.text.trim(),
                goal: _goal.text.trim().isEmpty ? null : _goal.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
