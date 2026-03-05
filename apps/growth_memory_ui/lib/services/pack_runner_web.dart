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
    return const PackRunResult(
      exitCode: 2,
      stdout: '',
      stderr: 'Pack runner is not available on web. Use the CLI runner locally and attach the report artifact.',
    );
  }
}

