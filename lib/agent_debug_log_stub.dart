/// Web / non-IO targets: debug logging is a no-op.
Future<void> agentDebugNdjsonLog({
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
}) async {}
