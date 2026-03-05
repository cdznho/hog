import 'pack_runner_web.dart' if (dart.library.io) 'pack_runner_io.dart';

abstract class PackRunner {
  static PackRunner create() => PackRunnerImpl.create();

  Future<PackRunResult> runLlmSeo({
    required String orgId,
    required String siteUrl,
    String? industry,
    String? audience,
    String? competitors,
    String? goal,
    List<String> inspectUrls = const [],
    String? sectionFilter,
  });
}

class PackRunResult {
  const PackRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.reportPath,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final String? reportPath;
}

