import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/providers/rider_tracking_provider.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/utils/map_markers.dart';

class LiveTrackingPanel extends ConsumerStatefulWidget {
  final dynamic order;
  const LiveTrackingPanel({super.key, required this.order});

  @override
  ConsumerState<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends ConsumerState<LiveTrackingPanel> {
  static const LatLng _defaultLoc = LatLng(16.3142, 80.4187); // Guntur
  static const Color _accent = Color(0xFF5D9ECC);

  bool _isLoading = true;
  bool _hasDelivery = false;
  GoogleMapController? _mapController;

  LatLng? _riderLoc;
  LatLng? _pickupLoc;
  LatLng? _deliveryLoc;
  List<LatLng> _routeCoords = [];

  String _riderName = "Rider Assigned";
  String _deliveryStatus = "Rider is heading to pickup...";
  String? _deliveryOtp; // shown persistently so a swiped notification isn't lost

  DateTime? _lastRouteFetch;
  double _apiDurationMinutes = 0.0;

  /// The rider's bearing, derived from successive positions — the tracking
  /// socket sends coordinates only, no heading. Held between moves so the
  /// sprite doesn't spin on the spot at a traffic light.
  double _riderBearing = 0;

  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _storeIcon;
  BitmapDescriptor? _destIcon;
  bool _iconsRequested = false;

  bool get _isBakery =>
      (widget.order.brand ?? '').toString().toLowerCase().contains('littleh');

  /// Marker bitmaps are async and not cheap; this widget rebuilds on every
  /// socket tick, so build them once.
  Future<void> _loadMarkerIcons() async {
    if (_iconsRequested) return;
    _iconsRequested = true;

    final ratio = MediaQuery.of(context).devicePixelRatio;
    final icons = await Future.wait([
      MapMarkers.rider(accent: _accent, ratio: ratio),
      MapMarkers.store(isBakery: _isBakery, ratio: ratio),
      MapMarkers.destination(accent: _accent, ratio: ratio),
    ]);
    if (!mounted) return;
    setState(() {
      _riderIcon = icons[0];
      _storeIcon = icons[1];
      _destIcon = icons[2];
    });
  }

  /// Initial bearing from `a` to `b`, in degrees clockwise from north.
  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  void initState() {
    super.initState();
    _fetchActiveDelivery();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  double _metersBetween(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  Future<void> _fetchActiveDelivery() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final url = AppConfig.buildUrl(
        '/customer/deliveries/order/${widget.order.id}',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final resData = json.decode(response.body);
      if (resData['success'] != true || resData['data'] == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = resData['data'];
      final riderData = data['rider'];
      final pickup = data['pickupLocation'];
      final delivery = data['deliveryLocation'];

      LatLng? parse(dynamic node) {
        final coords = node?['coordinates'];
        if (coords is List && coords.length >= 2) {
          return LatLng((coords[1]).toDouble(), (coords[0]).toDouble());
        }
        return null;
      }

      if (mounted) {
        setState(() {
          _hasDelivery = true;
          _riderName = riderData?['name'] ?? 'Cafe Rider';
          final otp = data['deliveryOtp'];
          _deliveryOtp = (otp != null && otp.toString().isNotEmpty)
              ? otp.toString()
              : null;
          _pickupLoc = parse(pickup) ?? _defaultLoc;
          _deliveryLoc = parse(delivery) ?? const LatLng(16.3090, 80.4309);
          _riderLoc = parse(riderData?['currentLocation']) ?? _pickupLoc;
          _updateStatusText();
          _isLoading = false;
        });
        _fetchRoadRoute();
      }
    } catch (e) {
      debugPrint("Error fetching active delivery: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoadRoute() async {
    if (_riderLoc == null || _pickupLoc == null || _deliveryLoc == null) return;

    try {
      final origin = '${_riderLoc!.latitude},${_riderLoc!.longitude}';
      final dest = '${_deliveryLoc!.latitude},${_deliveryLoc!.longitude}';
      final waypoint = '${_pickupLoc!.latitude},${_pickupLoc!.longitude}';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin&destination=$dest&waypoints=$waypoint'
        '&mode=driving&key=${AppConfig.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
        debugPrint("Directions API: ${data['status']}");
        return;
      }

      final route = data['routes'][0];
      final encoded = route['overview_polyline']?['points'] as String?;
      double durSeconds = 0;
      for (final leg in (route['legs'] as List? ?? [])) {
        durSeconds += (leg['duration']?['value'] ?? 0).toDouble();
      }

      if (encoded != null && mounted) {
        setState(() {
          _routeCoords = _decodePolyline(encoded);
          _apiDurationMinutes = durSeconds / 60.0;
          _lastRouteFetch = DateTime.now();
          _updateStatusText();
        });
      }
    } catch (e) {
      debugPrint("Route fetch error: $e");
    }
  }

  // Decode a Google "encoded polyline" string into coordinates.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _checkDeviation(LatLng currentPos) {
    if (_routeCoords.isEmpty) return;
    double minD = double.infinity;
    final limit = _routeCoords.length > 20 ? 20 : _routeCoords.length;
    for (int i = 0; i < limit; i++) {
      final d = _metersBetween(currentPos, _routeCoords[i]);
      if (d < minD) minD = d;
    }
    if (minD > 150) {
      final now = DateTime.now();
      if (_lastRouteFetch == null ||
          now.difference(_lastRouteFetch!).inSeconds > 20) {
        _fetchRoadRoute();
      }
    }
  }

  void _pruneRoute(LatLng currentPos) {
    if (_routeCoords.isEmpty) return;
    int nearestIdx = -1;
    double minDistance = double.infinity;
    final searchLimit = _routeCoords.length > 40 ? 40 : _routeCoords.length;
    for (int i = 0; i < searchLimit; i++) {
      final dist = _metersBetween(currentPos, _routeCoords[i]);
      if (dist < minDistance) {
        minDistance = dist;
        nearestIdx = i;
      }
    }
    if (nearestIdx != -1 && minDistance < 40) {
      setState(() => _routeCoords.removeRange(0, nearestIdx));
    }
  }

  void _updateStatusText() {
    if (_riderLoc == null || _deliveryLoc == null) {
      if (mounted) {
        setState(() => _deliveryStatus = "Rider is preparing for trip...");
      }
      return;
    }
    final double dist = _metersBetween(_riderLoc!, _deliveryLoc!) / 1000.0;
    final int mins = (_apiDurationMinutes > 0 && _routeCoords.isNotEmpty)
        ? (dist * 2.1).ceil() + 1
        : (dist * 2.5).ceil() + 2;
    if (mounted) {
      setState(() {
        _deliveryStatus = dist < 0.1
            ? "Rider has arrived at your location!"
            : "Rider is ${dist.toStringAsFixed(1)}km away • $mins mins away";
      });
    }
  }

  /// Three default teardrops (azure / green / red) used to stand for the rider,
  /// the outlet and your own front door — the same shape three times, and a
  /// legend you had to memorise. Now they're a scooter, the store, and a house.
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_riderLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderLoc!,
        icon: _riderIcon ?? BitmapDescriptor.defaultMarker,
        rotation: _riderBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 3,
        infoWindow: InfoWindow(title: _riderName),
      ));
    }
    if (_pickupLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLoc!,
        icon: _storeIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: 1,
        infoWindow: const InfoWindow(title: 'Your order was picked up here'),
      ));
    }
    if (_deliveryLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryLoc!,
        icon: _destIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: 2,
        infoWindow: const InfoWindow(title: 'Your address'),
      ));
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routeCoords.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routeCoords,
          width: 5,
          color: _accent,
        ),
      };
    }
    if (_pickupLoc != null && _deliveryLoc != null) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLoc!, _deliveryLoc!],
          width: 4,
          color: _accent.withValues(alpha: 0.3),
        ),
      };
    }
    return {};
  }

  /// The delivery OTP, always on screen — a swiped SMS/push used to be lost with
  /// no way to see it again. Give it to the rider on handoff.
  Widget _buildOtpCard(String otp) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.lock(), color: _accent, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Delivery OTP — share with the rider",
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  otp,
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: const Color(0xFF267CB9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(riderTrackingProvider);
    final myRiderState = trackingState[widget.order.id];

    _loadMarkerIcons();

    if (myRiderState != null && myRiderState.location != _riderLoc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final previous = _riderLoc;
          setState(() {
            // Only re-aim the sprite on a real move; sub-5m GPS jitter would
            // otherwise have the bike spinning while the rider stands still.
            if (previous != null &&
                _metersBetween(previous, myRiderState.location) > 5) {
              _riderBearing = _bearingBetween(previous, myRiderState.location);
            }
            _riderLoc = myRiderState.location;
            _updateStatusText();
            _pruneRoute(_riderLoc!);
            _checkDeviation(_riderLoc!);
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_riderLoc!));
        }
      });
    }

    if (_isLoading) {
      return Container(
        height: 150.h,
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(color: Colors.blue.shade100, width: 2.5.w),
        ),
        child: Center(
          child: CircularProgressIndicator(color: const Color(0xFFA9BCA4)),
        ),
      );
    }

    if (!_hasDelivery) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: _accent, width: 2.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(29.5.r),
              topRight: Radius.circular(29.5.r),
            ),
            child: SizedBox(
              height: 200.h,
              width: double.infinity,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _riderLoc ?? _pickupLoc ?? _defaultLoc,
                      zoom: 15,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  Positioned(
                    bottom: 12.h,
                    right: 12.w,
                    child: FloatingActionButton.small(
                      heroTag: "locate_rider_${widget.order.id}",
                      onPressed: () {
                        if (_riderLoc != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(_riderLoc!, 15),
                          );
                        }
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF267CB9),
                      child: Icon(PhosphorIcons.crosshair()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Tracking Order #${widget.order.orderNumber}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _riderName,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF267CB9),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  _deliveryStatus,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_deliveryOtp != null) ...[
                  SizedBox(height: 12.h),
                  _buildOtpCard(_deliveryOtp!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
