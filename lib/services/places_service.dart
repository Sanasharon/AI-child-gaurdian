// ============================================================
// places_service.dart
// ------------------------------------------------------------
// Dedicated service for place search and autocomplete using the
// Google Places API (New).
//
// Reads the existing Google Maps API Key directly from the native
// Android configuration via MethodChannel (no hardcoded keys).
//
// Gracefully handles errors (such as API_KEY_SERVICE_BLOCKED or
// disabled APIs) with human-readable error messages so the UI
// can inform the guardian clearly.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/place_suggestion_model.dart';

class PlacesException implements Exception {
  final String message;
  final String? code;

  const PlacesException(this.message, {this.code});

  @override
  String toString() => message;
}

class PlacesService {
  static const MethodChannel _configChannel =
      MethodChannel('com.example.ai_child_guardian/config');

  String? _cachedApiKey;

  // Retrieve existing API key dynamically from AndroidManifest configuration
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    try {
      final key = await _configChannel.invokeMethod<String>('getMapsApiKey');
      _cachedApiKey = key;
      return key;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // Autocomplete search using Google Places API (New)
  // Endpoint: https://places.googleapis.com/v1/places:autocomplete
  // ------------------------------------------------------------
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      throw const PlacesException(
        'Google Maps API Key is not configured in AndroidManifest.xml.',
        code: 'MISSING_KEY',
      );
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Goog-Api-Key', apiKey);

      final payload = jsonEncode({
        'input': trimmed,
      });
      request.write(payload);

      final response = await request.close().timeout(const Duration(seconds: 8));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final suggestionsJson = data['suggestions'] as List<dynamic>? ?? [];

        final results = <PlaceSuggestion>[];
        for (final item in suggestionsJson) {
          final placePrediction = item['placePrediction'] as Map<String, dynamic>?;
          if (placePrediction == null) continue;

          final placeId = placePrediction['placeId'] as String? ?? '';
          final textObj = placePrediction['text'] as Map<String, dynamic>?;
          final mainTextObj = placePrediction['structuredFormat']?['mainText'] as Map<String, dynamic>?;
          final secondaryTextObj = placePrediction['structuredFormat']?['secondaryText'] as Map<String, dynamic>?;

          final mainText = mainTextObj?['text'] as String? ?? textObj?['text'] as String? ?? 'Unknown Location';
          final secondaryText = secondaryTextObj?['text'] as String? ?? '';

          results.add(
            PlaceSuggestion(
              id: placeId,
              mainText: mainText,
              secondaryText: secondaryText,
            ),
          );
        }
        return results;
      } else {
        // Parse error response
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          final error = errJson['error'] as Map<String, dynamic>?;
          final status = error?['status'] as String? ?? 'ERROR';
          final message = error?['message'] as String? ?? 'Google Places request failed (${response.statusCode})';

          if (status == 'PERMISSION_DENIED' || response.statusCode == 403) {
            throw const PlacesException(
              'Google Places API (New) is not enabled for this project or restricted on this API key. Please enable "Places API (New)" in Google Cloud Console.',
              code: 'API_KEY_SERVICE_BLOCKED',
            );
          }

          throw PlacesException(message, code: status);
        } catch (e) {
          if (e is PlacesException) rethrow;
          throw PlacesException('Places API request failed with status ${response.statusCode}');
        }
      }
    } on SocketException {
      throw const PlacesException('Network unavailable. Please check your internet connection.');
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------
  // Place Details (New) to fetch latitude & longitude
  // Endpoint: https://places.googleapis.com/v1/places/{placeId}
  // ------------------------------------------------------------
  Future<PlaceSuggestion> getPlaceDetails(PlaceSuggestion suggestion) async {
    // If coordinates already populated, return as is
    if (suggestion.latitude != null && suggestion.longitude != null) {
      return suggestion;
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const PlacesException('API key is missing.');
    }

    final client = HttpClient();
    try {
      final uri = Uri.parse('https://places.googleapis.com/v1/places/${suggestion.id}');
      final request = await client.getUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-Goog-Api-Key', apiKey);
      request.headers.set('X-Goog-FieldMask', 'id,displayName,location,formattedAddress');

      final response = await request.close().timeout(const Duration(seconds: 8));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>?;

        if (location != null && location['latitude'] != null && location['longitude'] != null) {
          final lat = (location['latitude'] as num).toDouble();
          final lng = (location['longitude'] as num).toDouble();

          return suggestion.copyWith(
            latitude: lat,
            longitude: lng,
          );
        }
        throw const PlacesException('Location coordinates not available for this place.');
      } else {
        throw PlacesException('Failed to fetch place details (${response.statusCode})');
      }
    } finally {
      client.close();
    }
  }
}
