import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/gradient_scaffold.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final dbAsync = ref.watch(dbProvider);

    return dbAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('DB error: $e'))),
      data: (_) {
        if (repo == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        return GradientScaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Database', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      SelectableText(repo.dbPath),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => launchUrl(Uri.file(repo.dbPath), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open db file'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => ref.read(refreshTickProvider.notifier).state++,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh UI'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GSC verified mode', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      const SelectableText('''
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export GSC_SITE_URL="https://domain.com/"   # or sc-domain:domain.com
'''),
                      const SizedBox(height: 10),
                      Text(
                        'MVP stance: BYOC + local execution. Do not upload or store credentials in the app.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Runner integration (next)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Text(
                        'This UI currently stores orgs/cycles/artifacts and can attach reports. Next step is wiring it to your CLI pack runner (`run_pack llm-seo ...`) to execute runs and auto-attach the output artifact path.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

