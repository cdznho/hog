import 'dart:io';

import 'report_importer.dart';
import 'report_parser.dart';

class ReportImporterImpl implements ReportImporter {
  static ReportImporter create() => ReportImporterImpl();

  @override
  Future<ParsedReportInsights> importFromPath(String path) async {
    final html = await _loadHtml(path);
    return parseReportHtml(html);
  }
}

Future<String> _loadHtml(String source) async {
  final trimmed = source.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(trimmed));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Failed to fetch report: HTTP ${response.statusCode}', uri: Uri.parse(trimmed));
      }
      return await response.transform(SystemEncoding().decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  final file = File(trimmed);
  if (!await file.exists()) {
    throw FileSystemException('Report file not found', trimmed);
  }
  return file.readAsString();
}
