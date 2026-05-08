import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AuditLogger {
  static const int _maxLines = 500;

  static Future<void> log({
    required String eventType,
    required String source,
    required String result,
    String? inputSnippet,
    String? aiIntent,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/audit_log.jsonl');

      final payload = <String, dynamic>{
        'ts': DateTime.now().toIso8601String(),
        'eventType': eventType,
        'source': source,
        'result': result,
        if (inputSnippet != null && inputSnippet.trim().isNotEmpty)
          'inputSnippet': _trim(inputSnippet.trim(), 100),
        if (aiIntent != null && aiIntent.trim().isNotEmpty) 'aiIntent': aiIntent.trim(),
      };

      final line = '${jsonEncode(payload)}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
      await _trimIfNeeded(file);
      debugPrint('[AUDIT] ${jsonEncode(payload)}');
    } catch (e) {
      debugPrint('[AUDIT] log failure: $e');
    }
  }

  static String _trim(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  }

  static Future<void> _trimIfNeeded(File file) async {
    final content = await file.readAsString();
    final lines = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length <= _maxLines) return;
    final trimmed = lines.sublist(lines.length - _maxLines).join('\n');
    await file.writeAsString('$trimmed\n', flush: true);
  }
}
