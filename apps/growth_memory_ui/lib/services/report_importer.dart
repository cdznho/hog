import 'report_importer_web.dart' if (dart.library.io) 'report_importer_io.dart';

abstract class ReportImporter {
  static ReportImporter create() => ReportImporterImpl.create();

  Future<ParsedReportInsights> importFromPath(String path);
}

class ParsedReportInsights {
  const ParsedReportInsights({
    required this.coverageRows,
    required this.recommendationRows,
  });

  final List<Map<String, Object?>> coverageRows;
  final List<Map<String, Object?>> recommendationRows;
}

