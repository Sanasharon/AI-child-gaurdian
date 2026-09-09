// ============================================================
// place_suggestion_model.dart
// ------------------------------------------------------------
// Model representing a place prediction returned by place search
// and autocomplete. Stores display name, address, and coordinates.
// ============================================================

class PlaceSuggestion {
  final String id;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  const PlaceSuggestion({
    required this.id,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  String get fullAddress =>
      secondaryText.isEmpty ? mainText : '$mainText, $secondaryText';

  PlaceSuggestion copyWith({
    String? id,
    String? mainText,
    String? secondaryText,
    double? latitude,
    double? longitude,
  }) {
    return PlaceSuggestion(
      id: id ?? this.id,
      mainText: mainText ?? this.mainText,
      secondaryText: secondaryText ?? this.secondaryText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() => 'PlaceSuggestion($mainText, lat: $latitude, lng: $longitude)';
}
