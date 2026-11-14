class SavedAddress {
  final String id;
  final String label;

  /// The street-level address from the map pin (or as typed).
  final String addressLine;

  /// What the rider needs at the gate.
  final String flatNo;
  final String floor;
  final String landmark;

  /// Ordering for someone else at this address.
  final String receiverName;
  final String receiverPhone;

  final double? latitude;
  final double? longitude;
  final bool isDefault;

  SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    this.flatNo = '',
    this.floor = '',
    this.landmark = '',
    this.receiverName = '',
    this.receiverPhone = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  /// Home, Work, or a name of the customer's own.
  AddressKind get kind {
    final l = label.trim().toLowerCase();
    if (l == 'home') return AddressKind.home;
    if (l == 'work' || l == 'office') return AddressKind.work;
    return AddressKind.other;
  }

  bool get hasReceiver => receiverName.isNotEmpty || receiverPhone.isNotEmpty;

  /// Flat, floor and street on one line: what goes on the order.
  String get fullText {
    final parts = <String>[
      if (flatNo.isNotEmpty) flatNo,
      if (floor.isNotEmpty)
        RegExp(r'floor', caseSensitive: false).hasMatch(floor)
            ? floor
            : 'Floor $floor',
      if (addressLine.isNotEmpty) addressLine,
      if (landmark.isNotEmpty)
        landmark.toLowerCase().startsWith('near') ? landmark : 'Near $landmark',
    ];
    return parts.join(', ');
  }

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
    String s(String key) => (json[key] ?? '').toString().trim();
    return SavedAddress(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      label: s('label'),
      addressLine: s('addressLine'),
      flatNo: s('flatNo'),
      floor: s('floor'),
      landmark: s('landmark'),
      receiverName: s('receiverName'),
      receiverPhone: s('receiverPhone'),
      latitude: lat,
      longitude: lng,
      isDefault: json['isDefault'] ?? false,
    );
  }
}

enum AddressKind { home, work, other }
