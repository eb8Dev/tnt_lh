import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tnt_lh/providers/socket_provider.dart';

class RiderLocationState {
  final String orderId;
  final LatLng location;
  final double bearing;
  final DateTime lastUpdated;

  RiderLocationState({
    required this.orderId,
    required this.location,
    this.bearing = 0,
    required this.lastUpdated,
  });
}

class RiderTrackingNotifier extends Notifier<Map<String, RiderLocationState>> {
  @override
  Map<String, RiderLocationState> build() {
    return {};
  }

  void updateWithEvent(SocketEvent event) {
    if (event.name == 'rider:location-update') {
      _handleLocationUpdate(event.data);
    }
  }

  void _handleLocationUpdate(dynamic data) {
    try {
      final orderId = data['orderId']?.toString();
      double? lat;
      double? lng;

      if (data['lat'] != null && data['lng'] != null) {
        lat = (data['lat'] as num).toDouble();
        lng = (data['lng'] as num).toDouble();
      } else if (data['location']?['coordinates'] is List) {
        final coords = data['location']['coordinates'];
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }

      if (orderId != null && lat != null && lng != null) {
        final bearing = (data['bearing'] ?? 0).toDouble();

        // Update existing state
        state = {
          ...state,
          orderId: RiderLocationState(
            orderId: orderId,
            location: LatLng(lat, lng),
            bearing: bearing,
            lastUpdated: DateTime.now(),
          ),
        };
      }
    } catch (e) {
      debugPrint("Error parsing rider location update: $e");
    }
  }

  RiderLocationState? getRiderForOrder(String orderId) => state[orderId];
}

final riderTrackingProvider =
    NotifierProvider<RiderTrackingNotifier, Map<String, RiderLocationState>>(
      () {
        return RiderTrackingNotifier();
      },
    );
