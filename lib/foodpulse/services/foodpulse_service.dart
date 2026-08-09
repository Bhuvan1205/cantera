import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class FoodPulseService {
  // Base URL for FoodPulse FastAPI backend.
  static String get baseUrl => '${AppConfig.backendBaseUrl}/foodpulse';

  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Submits a new food suggestion.
  static Future<Map<String, dynamic>> submitSuggestion({
    required String name,
    required String description,
    required String category,
    int? suggestedPrice,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/suggestions'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'category': category,
        'suggested_price': suggestedPrice,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to submit suggestion');
    }
  }

  /// Lists suggestions, optionally filtered by status.
  static Future<List<dynamic>> getSuggestions({String? status}) async {
    final headers = await _getHeaders();
    final uri = status != null
        ? Uri.parse('$baseUrl/suggestions?status=$status')
        : Uri.parse('$baseUrl/suggestions');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch suggestions');
    }
  }

  /// Gets suggestions created by the current user.
  static Future<List<dynamic>> getMySuggestions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/suggestions/mine'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch my suggestions');
    }
  }

  /// Votes for a suggestion.
  static Future<Map<String, dynamic>> vote(String suggestionId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/vote/$suggestionId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to cast vote');
    }
  }

  /// Removes vote for a suggestion.
  static Future<Map<String, dynamic>> removeVote(String suggestionId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/vote/$suggestionId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to remove vote');
    }
  }

  /// Gets trending food suggestions.
  static Future<List<dynamic>> getTrending() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/trending'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception('Failed to fetch trending suggestions');
    }
  }

  /// Gets notifications for the current user.
  static Future<List<dynamic>> getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  /// Gets active community poll.
  static Future<Map<String, dynamic>?> getActivePoll() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/polls/active'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Votes in a community poll.
  static Future<Map<String, dynamic>> votePoll({
    required String pollId,
    required String optionId,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/polls/$pollId/vote'),
      headers: headers,
      body: jsonEncode({'option_id': optionId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to submit vote');
    }
  }

  /// Marks a notification as read.
  static Future<void> markNotificationRead(String notifId) async {
    final headers = await _getHeaders();
    await http.patch(
      Uri.parse('$baseUrl/notifications/$notifId/read'),
      headers: headers,
    );
  }
}



