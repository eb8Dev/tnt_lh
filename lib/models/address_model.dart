class SavedAddress {
  final String id;
  final String label;
  final String addressLine;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;
    final coords = json['location']?['coordinates'];
    if (coords is List && coords.length >= 2) {
      lng = (coords[0] as num?)?.toDouble();
      lat = (coords[1] as num?)?.toDouble();
      // A [0,0] point means "no real location" — treat as absent.
      if (lat == 0 && lng == 0) {
        lat = null;
        lng = null;
      }
    }
    return SavedAddress(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      label: json['label'] ?? '',
      addressLine: json['addressLine'] ?? '',
      latitude: lat,
      longitude: lng,
      isDefault: json['isDefault'] ?? false,
    );
  }
}
