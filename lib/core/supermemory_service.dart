import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for interacting with Supermemory's vector memory API.
/// Provides long-term, semantic memory capabilities for Vyoma.
class SupermemoryService {
  final String _apiKey;
  final String _baseUrl = "https://api.supermemory.ai/v3";
  final String? projectTag;
  
  SupermemoryService({required String apiKey, this.projectTag}) : _apiKey = apiKey;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    if (projectTag != null) 'x-sm-project': projectTag!,
  };

  /// Save a memory to the vector database.
  /// [content] - The text content to remember.
  /// [tags] - Optional list of tags for organization.
  /// [type] - Memory type: 'note', 'link', 'file'. Default: 'note'.
  Future<bool> saveMemory(String content, {List<String>? tags, String type = 'note'}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/documents'),
        headers: _headers,
        body: jsonEncode({
          'content': content,
          'type': type,
          if (tags != null) 'tags': tags,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("SUPERMEMORY: Saved memory successfully.");
        return true;
      } else {
        print("SUPERMEMORY: Failed to save - ${response.statusCode}: ${response.body}");
        return false;
      }
    } catch (e) {
      print("SUPERMEMORY: Error saving memory - $e");
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
        );
        return response.statusCode == 200;
      }
      return false;
    } catch (e) {
      print("SUPERMEMORY: Error forgetting memory - $e");
      return false;
    }
  }

  /// Search for relevant memories using semantic search.
  /// [query] - Natural language search query.
  /// [limit] - Maximum number of results to return.
  Future<List<SuperMemory>> recall(String query, {int limit = 5}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'limit': limit,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        return results.map((r) => SuperMemory.fromJson(r)).toList();
      } else {
        print("SUPERMEMORY: Search failed - ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("SUPERMEMORY: Error recalling memories - $e");
      return [];
    }
  }

  /// Get the user's profile summary from Supermemory.
  Future<String?> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['summary'] as String?;
      }
      return null;
    } catch (e) {
      print("SUPERMEMORY: Error fetching profile - $e");
      return null;
    }
  }

  /// Check if the service is configured and reachable.
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : null,
    );
  }

  @override
  String toString() => content;
}
