import 'report_importer.dart';

ParsedReportInsights parseReportHtml(String html) {
  return ParsedReportInsights(
    coverageRows: _parseCoverageRows(html),
    recommendationRows: _parseRecommendations(html),
  );
}

List<Map<String, Object?>> _parseCoverageRows(String html) {
  final sectionMatch = RegExp(
    r'<h3>Content Coverage Heatmap</h3>\s*<div class="table-wrap"><table><thead>.*?</thead><tbody>(.*?)</tbody></table></div>',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(html);
  if (sectionMatch == null) return const [];

  final tbody = sectionMatch.group(1)!;
  final rowMatches = RegExp(r'<tr>(.*?)</tr>', dotAll: true, caseSensitive: false).allMatches(tbody);
  final rows = <Map<String, Object?>>[];

  for (final rowMatch in rowMatches) {
    final rowHtml = rowMatch.group(1)!;
    final cells = RegExp(r'<td>(.*?)</td>', dotAll: true, caseSensitive: false)
        .allMatches(rowHtml)
        .map((m) => _stripHtml(m.group(1)!))
        .toList();
    if (cells.length < 6) continue;

    final clusterParts = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(cells[3]);
    rows.add({
      'category': cells[0],
      'subcategory': cells[1],
      'pillar_status': _removeDotEmoji(cells[2]),
      'cluster_current': int.tryParse(clusterParts?.group(1) ?? '') ?? 0,
      'cluster_target': int.tryParse(clusterParts?.group(2) ?? '') ?? 5,
      'coverage': cells[4],
      'priority': cells[5],
      'meta': <String, Object?>{'source': 'html_import'},
    });
  }

  return rows;
}

List<Map<String, Object?>> _parseRecommendations(String html) {
  final matches = RegExp(
    r'<li class="win-item">.*?<div class="win-title">(.*?)</div>.*?<span class="win-tag impact">Impact:\s*(.*?)</span>.*?<span class="win-tag effort">Effort:\s*(.*?)</span>.*?</li>',
    dotAll: true,
    caseSensitive: false,
  ).allMatches(html);

  return [
    for (final match in matches)
      <String, Object?>{
        'title': _stripHtml(match.group(1)!),
        'status': 'Open',
        'priority': _inferPriorityFromImpact(_stripHtml(match.group(2)!)),
        'owner': 'Unassigned',
        'meta': <String, Object?>{
          'impact': _stripHtml(match.group(2)!),
          'effort': _stripHtml(match.group(3)!),
          'source': 'html_import',
        },
      },
  ];
}

String _stripHtml(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _removeDotEmoji(String value) {
  return value.replaceAll(RegExp(r'^[^A-Za-z]+'), '').trim();
}

String _inferPriorityFromImpact(String impact) {
  final text = impact.toLowerCase();
  if (text.contains('immediate') || text.contains('highest') || text.contains('most-cited')) {
    return 'High';
  }
  if (text.contains('compound') || text.contains('strong')) {
    return 'Med';
  }
  return 'Low';
}

