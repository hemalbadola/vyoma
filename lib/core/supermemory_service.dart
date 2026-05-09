import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with Supermemory's vector memory API.
/// Provides long-term, semantic memory capabilities for Vyoma.
class SupermemoryService {
  final String _apiKey;
  final String _baseUrl = "https://api.supermemory.ai/v3";
  final String? projectTag;
  final Duration _timeout = const Duration(seconds: 8);
  SupermemoryDiagnostics _diagnostics = const SupermemoryDiagnostics();

  SupermemoryDiagnostics get diagnostics => _diagnostics;
  
  SupermemoryService({required String apiKey, this.projectTag}) : _apiKey = apiKey;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    ...?projectTag != null ? {'x-sm-project': projectTag!} : null,
  };

  void _updateDiagnostics({
    DateTime? lastHealthCheckAt,
    int? lastHealthStatusCode,
    DateTime? lastSaveAt,
    int? lastSaveStatusCode,
    bool? lastSaveOk,
    DateTime? lastRecallAt,
    int? lastRecallStatusCode,
    int? lastRecallResultCount,
    double? lastRecallTopScore,
    DateTime? lastProfileAt,
    int? lastProfileStatusCode,
    int? saveSuccessCount,
    int? saveFailureCount,
    int? recallSuccessCount,
    int? recallFailureCount,
    String? lastError,
    bool clearError = false,
  }) {
    _diagnostics = _diagnostics.copyWith(
      lastHealthCheckAt: lastHealthCheckAt,
      lastHealthStatusCode: lastHealthStatusCode,
      lastSaveAt: lastSaveAt,
      lastSaveStatusCode: lastSaveStatusCode,
      lastSaveOk: lastSaveOk,
      lastRecallAt: lastRecallAt,
      lastRecallStatusCode: lastRecallStatusCode,
      lastRecallResultCount: lastRecallResultCount,
      lastRecallTopScore: lastRecallTopScore,
      lastProfileAt: lastProfileAt,
      lastProfileStatusCode: lastProfileStatusCode,
      saveSuccessCount: saveSuccessCount,
      saveFailureCount: saveFailureCount,
      recallSuccessCount: recallSuccessCount,
      recallFailureCount: recallFailureCount,
      lastError: clearError ? null : lastError,
    );
  }

  /// Save a memory to the vector database.
  /// [content] - The text content to remember.
  /// [tags] - Optional list of tags for organization.
  /// [type] - Memory type: 'note', 'link', 'file'. Default: 'note'.
  Future<bool> saveMemory(String content, {List<String>? tags, String type = 'note'}) async {
    final now = DateTime.now();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/documents'),
        headers: _headers,
        body: jsonEncode({
          'content': content,
          'type': type,
          ...?tags != null ? {'tags': tags} : null,
        }),
      ).timeout(_timeout);

      final ok = response.statusCode == 200 || response.statusCode == 201;
      _updateDiagnostics(
        lastSaveAt: now,
        lastSaveStatusCode: response.statusCode,
        lastSaveOk: ok,
        saveSuccessCount: ok ? _diagnostics.saveSuccessCount + 1 : _diagnostics.saveSuccessCount,
        saveFailureCount: ok ? _diagnostics.saveFailureCount : _diagnostics.saveFailureCount + 1,
        clearError: ok,
        lastError: ok ? null : 'save failed status ${response.statusCode}',
      );

      if (ok) {
        debugPrint("SUPERMEMORY: Saved memory successfully.");
        return true;
      } else {
        debugPrint("SUPERMEMORY: Failed to save - ${response.statusCode}: ${response.body}");
        return false;
      }
    } catch (e) {
      _updateDiagnostics(
        lastSaveAt: now,
        lastSaveOk: false,
        saveFailureCount: _diagnostics.saveFailureCount + 1,
        lastError: 'save exception: $e',
      );
      debugPrint("SUPERMEMORY: Error saving memory - $e");
      return false;
    }
  }

  /// Forget a memory (mark for deletion).
  /// [query] - Description of the memory to forget.
  Future<bool> forgetMemory(String query) async {
    // Supermemory uses a different approach - we'd need to search and delete
    // For now, we'll save a "forget" intent that the system can process
    try {
      final memories = await recall(query, limit: 1);
      if (memories.isNotEmpty) {
        final memoryId = memories.first.id;
        final response = await http.delete(
          Uri.parse('$_baseUrl/documents/$memoryId'),
          headers: _headers,
        ).timeout(_timeout);
        return response.statusCode == 200 || response.statusCode == 204;
      }
      return false;
    } catch (e) {
      debugPrint("SUPERMEMORY: Error forgetting memory - $e");
      return false;
    }
  }

  /// Search for relevant memories using semantic search.
  /// [query] - Natural language search query.
  /// [limit] - Maximum number of results to return.
  Future<List<SuperMemory>> recall(String query, {int limit = 5}) async {
    final now = DateTime.now();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: _headers,
        body: jsonEncode({
          'q': query,
          'limit': limit,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? data['data'] as List? ?? [];
        final parsed = results.map((r) => SuperMemory.fromJson(r)).toList();
        _updateDiagnostics(
          lastRecallAt: now,
          lastRecallStatusCode: response.statusCode,
          lastRecallResultCount: parsed.length,
          lastRecallTopScore: parsed.isNotEmpty ? parsed.first.score : null,
          recallSuccessCount: _diagnostics.recallSuccessCount + 1,
          clearError: true,
        );
        return parsed;
      } else {
        _updateDiagnostics(
          lastRecallAt: now,
          lastRecallStatusCode: response.statusCode,
          lastRecallResultCount: 0,
          recallFailureCount: _diagnostics.recallFailureCount + 1,
          lastError: 'recall failed status ${response.statusCode}',
        );
        debugPrint("SUPERMEMORY: Search failed - ${response.statusCode}");
        return [];
      }
    } catch (e) {
      _updateDiagnostics(
        lastRecallAt: now,
        lastRecallResultCount: 0,
        recallFailureCount: _diagnostics.recallFailureCount + 1,
        lastError: 'recall exception: $e',
      );
      debugPrint("SUPERMEMORY: Error recalling memories - $e");
      return [];
    }
  }

  /// Get the user's profile summary from Supermemory.
  Future<String?> getUserProfile() async {
    final now = DateTime.now();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: _headers,
      ).timeout(_timeout);

      _updateDiagnostics(
        lastProfileAt: now,
        lastProfileStatusCode: response.statusCode,
        clearError: response.statusCode == 200 || response.statusCode == 404,
        lastError: response.statusCode == 200 || response.statusCode == 404
            ? null
            : 'profile failed status ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['summary'] as String?;
      }
      return null;
    } catch (e) {
      _updateDiagnostics(
        lastProfileAt: now,
        lastError: 'profile exception: $e',
      );
      debugPrint("SUPERMEMORY: Error fetching profile - $e");
      return null;
    }
  }

  /// Check if the service is configured and reachable.
  Future<bool> isAvailable() async {
    final now = DateTime.now();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      _updateDiagnostics(
        lastHealthCheckAt: now,
        lastHealthStatusCode: response.statusCode,
        clearError: ok,
        lastError: ok ? null : 'health failed status ${response.statusCode}',
      );
      return ok;
    } catch (e) {
      _updateDiagnostics(
        lastHealthCheckAt: now,
        lastError: 'health exception: $e',
      );
      return false;
    }
  }
}

class SupermemoryDiagnostics {
  final DateTime? lastHealthCheckAt;
  final int? lastHealthStatusCode;
  final DateTime? lastSaveAt;
  final int? lastSaveStatusCode;
  final bool? lastSaveOk;
  final DateTime? lastRecallAt;
  final int? lastRecallStatusCode;
  final int lastRecallResultCount;
  final double? lastRecallTopScore;
  final DateTime? lastProfileAt;
  final int? lastProfileStatusCode;
  final int saveSuccessCount;
  final int saveFailureCount;
  final int recallSuccessCount;
  final int recallFailureCount;
  final String? lastError;

  const SupermemoryDiagnostics({
    this.lastHealthCheckAt,
    this.lastHealthStatusCode,
    this.lastSaveAt,
    this.lastSaveStatusCode,
    this.lastSaveOk,
    this.lastRecallAt,
    this.lastRecallStatusCode,
    this.lastRecallResultCount = 0,
    this.lastRecallTopScore,
    this.lastProfileAt,
    this.lastProfileStatusCode,
    this.saveSuccessCount = 0,
    this.saveFailureCount = 0,
    this.recallSuccessCount = 0,
    this.recallFailureCount = 0,
    this.lastError,
  });

  SupermemoryDiagnostics copyWith({
    DateTime? lastHealthCheckAt,
    int? lastHealthStatusCode,
    DateTime? lastSaveAt,
    int? lastSaveStatusCode,
    bool? lastSaveOk,
    DateTime? lastRecallAt,
    int? lastRecallStatusCode,
    int? lastRecallResultCount,
    double? lastRecallTopScore,
    DateTime? lastProfileAt,
    int? lastProfileStatusCode,
    int? saveSuccessCount,
    int? saveFailureCount,
    int? recallSuccessCount,
    int? recallFailureCount,
    String? lastError,
  }) {
    return SupermemoryDiagnostics(
      lastHealthCheckAt: lastHealthCheckAt ?? this.lastHealthCheckAt,
      lastHealthStatusCode: lastHealthStatusCode ?? this.lastHealthStatusCode,
      lastSaveAt: lastSaveAt ?? this.lastSaveAt,
      lastSaveStatusCode: lastSaveStatusCode ?? this.lastSaveStatusCode,
      lastSaveOk: lastSaveOk ?? this.lastSaveOk,
      lastRecallAt: lastRecallAt ?? this.lastRecallAt,
      lastRecallStatusCode: lastRecallStatusCode ?? this.lastRecallStatusCode,
      lastRecallResultCount: lastRecallResultCount ?? this.lastRecallResultCount,
      lastRecallTopScore: lastRecallTopScore ?? this.lastRecallTopScore,
      lastProfileAt: lastProfileAt ?? this.lastProfileAt,
      lastProfileStatusCode: lastProfileStatusCode ?? this.lastProfileStatusCode,
      saveSuccessCount: saveSuccessCount ?? this.saveSuccessCount,
      saveFailureCount: saveFailureCount ?? this.saveFailureCount,
      recallSuccessCount: recallSuccessCount ?? this.recallSuccessCount,
      recallFailureCount: recallFailureCount ?? this.recallFailureCount,
      lastError: lastError,
    );
  }
}

/// Represents a memory retrieved from Supermemory.
class SuperMemory {
  final String id;
  final String content;
  final double score;
  final List<String> tags;
  final DateTime? createdAt;

  SuperMemory({
    required this.id,
    required this.content,
    required this.score,
    this.tags = const [],
    this.createdAt,
  });

  factory SuperMemory.fromJson(Map<String, dynamic> json) {
    return SuperMemory(
      id: json['id'] ?? '',
      content: json['content'] ?? json['text'] ?? '',
      score: (json['score'] ?? json['similarity'] ?? 0.0).toDouble(),
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.tryParse((json['createdAt'] ?? json['created_at']).toString())
          : null,
    );
  }

  @override
  String toString() => content;
}
