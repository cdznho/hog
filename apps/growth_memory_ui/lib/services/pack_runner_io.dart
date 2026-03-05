import 'dart:io';

import 'pack_runner.dart';

class PackRunnerImpl implements PackRunner {
  static PackRunner create() => PackRunnerImpl();

  @override
  Future<PackRunResult> runLlmSeo({
    required String orgId,
    required String siteUrl,
    String? industry,
    String? audience,
    String? competitors,
    String? goal,
    List<String> inspectUrls = const [],
    String? sectionFilter,
  }) async {
    final args = <String>[
      'llm-seo',
      '--org-id',
      orgId,
      '--site-url',
      siteUrl,
      if (industry != null && industry.trim().isNotEmpty) ...['--industry', industry.trim()],
      if (audience != null && audience.trim().isNotEmpty) ...['--audience', audience.trim()],
      if (competitors != null && competitors.trim().isNotEmpty) ...['--competitors', competitors.trim()],
      if (goal != null && goal.trim().isNotEmpty) ...['--goal', goal.trim()],
      if (sectionFilter != null && sectionFilter.trim().isNotEmpty) ...['--section-filter', sectionFilter.trim()],
      if (inspectUrls.isNotEmpty) ...['--inspect-urls', inspectUrls.join(',')],
    ];

    final proc = await Process.start('run_pack', args);
    final out = await proc.stdout.transform(systemEncoding.decoder).join();
    final err = await proc.stderr.transform(systemEncoding.decoder).join();
    final exitCode = await proc.exitCode;

    // Optional: parse report path from stdout if runner prints it.
    final reportPath = _extractReportPath(out);

    return PackRunResult(exitCode: exitCode, stdout: out, stderr: err, reportPath: reportPath);
  }
}

String? _extractReportPath(String stdout) {
  final lines = stdout.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('report:') || trimmed.startsWith('report_path:')) {
      return trimmed.split(':').skip(1).join(':').trim();
    }
    if (trimmed.endsWith('.html') || trimmed.endsWith('.pdf')) {
      return trimmed;
    }
  }
  return null;
}
