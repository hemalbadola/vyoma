import 'dart:convert';
import 'dart:io';

/// Cursor debug ingest + optional file append (workspace path fails under macOS sandbox).
const _sessionId = '154eff';
const _ingestUri =
    'http://127.0.0.1:7610/ingest/aea1c334-8052-4a3e-9c4e-b9d009d4a560';
const _workspaceLogPath =
    '/Users/hemalbadola/Documents/Vyoma/.cursor/debug-154eff.log';

Future<void> agentDebugNdjsonLog({
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
}) async {
  try {
    final payload = <String, dynamic>{
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? <String, dynamic>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final bodyStr = jsonEncode(payload);
    final line = '$bodyStr\n';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 600);
      final req = await client.postUrl(Uri.parse(_ingestUri));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('X-Debug-Session-Id', _sessionId);
      final bytes = utf8.encode(bodyStr);
      req.contentLength = bytes.length;
      req.add(bytes);
      await req.close().timeout(const Duration(seconds: 2));
      client.close(force: true);
    } catch (_) {}

    try {
      await File(_workspaceLogPath)
          .writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}

    try {
      final tmpPath =
          '${Directory.systemTemp.path}/vyoma-debug-$_sessionId.ndjson';
      await File(tmpPath).writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  } catch (_) {}
}
