import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../data/providers.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(dbProvider);
    final refresh = ref.watch(refreshTickProvider);
    final repo = ref.watch(repositoryProvider);

    return dbAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('DB error: $e'))),
      data: (_) {
        if (repo == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Consume refresh to invalidate recomputation.
        refresh;
        final orgs = repo.listOrgs();
        final cycles = repo.listCycles();
        final artifacts = repo.listArtifacts();

        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Overview'),
            actions: [
              TextButton.icon(
                onPressed: () => context.go('/orgs'),
                icon: const Icon(Icons.apartment_rounded),
                label: const Text('Orgs'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Hero(
                orgCount: orgs.length,
                cycleCount: cycles.length,
                artifactCount: artifacts.length,
              ),
              const SizedBox(height: 20),
              SectionHeader(
                'What you can do',
                trailing: FilledButton.icon(
                  onPressed: () => context.go('/runs'),
                  icon: const Icon(Icons.play_circle_rounded),
                  label: const Text('Start run'),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 740 ? 2 : 1);
                  return _CardsGrid(
                    columns: cols,
                    children: const [
                      _ActionCard(
                        icon: Icons.data_object_rounded,
                        title: 'Verified baseline',
                        subtitle: 'Store GSC-backed snapshots per org + cycle.',
                      ),
                      _ActionCard(
                        icon: Icons.auto_fix_high_rounded,
                        title: 'Outcome-ready report',
                        subtitle: 'Attach HTML/PDF artifacts to every run.',
                      ),
                      _ActionCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Weekly deltas',
                        subtitle: 'Compare cycles and prioritize what changed.',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              SectionHeader('Next best step'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Create an org profile (site URL + context), then run the llm-seo pack.'),
                      ),
                      FilledButton(
                        onPressed: () => context.go('/orgs'),
                        child: const Text('Create org'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.orgCount,
    required this.cycleCount,
    required this.artifactCount,
  });

  final int orgCount;
  final int cycleCount;
  final int artifactCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outcome‑Verified LLM SEO', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'A local Growth Memory UI for cycles, snapshots, and artifacts — grounded in GSC evidence.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricPill(label: 'Orgs', value: '$orgCount', color: scheme.primary),
                _MetricPill(label: 'Cycles', value: '$cycleCount', color: scheme.tertiary),
                _MetricPill(label: 'Artifacts', value: '$artifactCount', color: scheme.secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({required this.children, required this.columns});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(
        Row(
          children: [
            for (var j = 0; j < columns; j++) ...[
              Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
              if (j < columns - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
      if (i + columns < children.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

