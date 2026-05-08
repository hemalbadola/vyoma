import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SessionStorageStats {
  const SessionStorageStats({
    required this.totalSessionFiles,
    required this.totalSizeBytes,
    required this.oldestSessionDate,
  });

  final int totalSessionFiles;
  final int totalSizeBytes;
  final DateTime? oldestSessionDate;
}

class SessionManager {
  static const int _maxSessionFiles = 30;
  static const int _maxSessionBytes = 1572864; // 1.5 MB

  static Future<void> enforce() async {
    final files = await _listSessionFiles();
    if (files.isEmpty) return;

    final sorted = List<File>.from(files)
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    final toDeleteCount = sorted.length - _maxSessionFiles;
    if (toDeleteCount > 0) {
      for (final file in sorted.take(toDeleteCount)) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('[SESSION_MANAGER] delete failed: $e');
        }
      }
    }

    final retained = await _listSessionFiles();
    for (final file in retained) {
      try {
        final size = await file.length();
        if (size > _maxSessionBytes) {
          await _truncateOversizedSession(file);
        }
      } catch (e) {
        debugPrint('[SESSION_MANAGER] size check failed: $e');
      }
    }
  }

  // DEAD: no callers found (kept for future storage diagnostics UI).
  static Future<SessionStorageStats> getStorageStats() async {
    final files = await _listSessionFiles();
    if (files.isEmpty) {
      return const SessionStorageStats(
        totalSessionFiles: 0,
        totalSizeBytes: 0,
        oldestSessionDate: null,
      );
    }

    int totalBytes = 0;
    DateTime? oldest;
    for (final file in files) {
      totalBytes += await file.length();
      final modified = await file.lastModified();
      if (oldest == null || modified.isBefore(oldest)) {
        oldest = modified;
      }
    }

    return SessionStorageStats(
      totalSessionFiles: files.length,
      totalSizeBytes: totalBytes,
      oldestSessionDate: oldest,
    );
  }

  static Future<List<File>> _listSessionFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final entities = dir.listSync();
    return entities
        .whereType<File>()
        .where((f) => f.path.split(Platform.pathSeparator).last.startsWith('session_'))
        .where((f) => f.path.endsWith('.json'))
        .toList();
  }

  static Future<void> _truncateOversizedSession(File file) async {
    try {
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;

      final messages = parsed.cast<Map<String, dynamic>>();
      if (messages.length < 8) return;

      final keepTail = messages.length > 20 ? 20 : messages.length;
      final archivedCount = messages.length - keepTail;
      if (archivedCount <= 0) return;

      final archivedPreview = messages
          .take(archivedCount)
          .map((m) => (m['text'] ?? '').toString())
          .where((t) => t.trim().isNotEmpty)
          .take(8)
          .join(' | ');

      final archivedEntry = <String, dynamic>{
        'sender': 'SYSTEM',
        'text':
            '[ARCHIVED] $archivedCount older messages summarized: ${archivedPreview.length > 280 ? '${archivedPreview.substring(0, 280)}...' : archivedPreview}',
        'timestamp': DateTime.now().toIso8601String(),
        'imageBytes': null,
      };

      final truncated = <Map<String, dynamic>>[
        archivedEntry,
        ...messages.skip(archivedCount),
      ];
      await file.writeAsString(jsonEncode(truncated), flush: true);
    } catch (e) {
      debugPrint('[SESSION_MANAGER] truncate failed: $e');
    }
  }
}
