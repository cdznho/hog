import 'package:http/http.dart' as http;

import 'report_importer.dart';
import 'report_parser.dart';

class ReportImporterImpl implements ReportImporter {
  static ReportImporter create() => ReportImporterImpl();

  @override
  Future<ParsedReportInsights> importFromPath(String path) async {
    final trimmed = path.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      throw UnsupportedError('Web builds can only import from report URLs, not local file paths.');
    }

    final response = await http.get(Uri.parse(trimmed));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch report: HTTP ${response.statusCode}');
    }
    return parseReportHtml(response.body);
  }
}
