import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/providers/rider_tracking_provider.dart';
import 'package:tnt_lh/services/auth_service.dart';

class LiveTrackingPanel extends ConsumerStatefulWidget {
  final dynamic order;
  const LiveTrackingPanel({super.key, required this.order});

  @override
  ConsumerState<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends ConsumerState<LiveTrackingPanel> {
  bool _isLoading = true;
  bool _hasDelivery = false;
  final MapController _mapController = MapController();

  LatLng? _riderLoc;
  LatLng? _pickupLoc;
  LatLng? _deliveryLoc;
  List<LatLng> _routeCoords = [];

  String _riderName = "Rider Assigned";
  String _deliveryStatus = "Rider is heading to pickup...";

  DateTime? _lastRouteFetch;
  double _apiDurationMinutes = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchActiveDelivery();
  }

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

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['success'] == true && resData['data'] != null) {
          final data = resData['data'];
          final riderData = data['rider'];
          final pickup = data['pickupLocation'];
          final delivery = data['deliveryLocation'];

          double? rLat, rLng;
          if (riderData != null && riderData['currentLocation'] != null) {
            final coords = riderData['currentLocation']['coordinates'];
            if (coords is List && coords.length >= 2) {
              rLng = (coords[0]).toDouble();
              rLat = (coords[1]).toDouble();
            }
          }

          double? pLat, pLng;
          if (pickup != null && pickup['coordinates'] != null) {
            final coords = pickup['coordinates'];
            if (coords is List && coords.length >= 2) {
              pLng = (coords[0]).toDouble();
              pLat = (coords[1]).toDouble();
            }
          }

          double? dLat, dLng;
          if (delivery != null && delivery['coordinates'] != null) {
            final coords = delivery['coordinates'];
            if (coords is List && coords.length >= 2) {
              dLng = (coords[0]).toDouble();
              dLat = (coords[1]).toDouble();
            }
          }

          if (mounted) {
            setState(() {
              _hasDelivery = true;
              _riderName = riderData?['name'] ?? 'Cafe Rider';

              _pickupLoc = pLat != null && pLng != null
                  ? LatLng(pLat, pLng)
                  : LatLng(16.3142, 80.4187);
              _deliveryLoc = dLat != null && dLng != null
                  ? LatLng(dLat, dLng)
                  : LatLng(16.3090, 80.4309);

              _riderLoc = rLat != null && rLng != null
                  ? LatLng(rLat, rLng)
                  : _pickupLoc;

              _updateStatusText();
              _isLoading = false;
            });

            _fetchRoadRoute();
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching active delivery: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoadRoute() async {
    if (_riderLoc == null || _pickupLoc == null || _deliveryLoc == null) return;

    try {
      final waypoints = [
        '${_riderLoc!.longitude},${_riderLoc!.latitude}',
        '${_pickupLoc!.longitude},${_pickupLoc!.latitude}',
        '${_deliveryLoc!.longitude},${_deliveryLoc!.latitude}',
      ].join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$waypoints?overview=full&geometries=geojson',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List coords = route['geometry']['coordinates'];
          final double durSeconds = (route['duration'] ?? 0.0).toDouble();

          if (mounted) {
            setState(() {
              _routeCoords = coords
                  .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                  .toList();
              _apiDurationMinutes = durSeconds / 60.0;
              _lastRouteFetch = DateTime.now();
              _updateStatusText();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Route fetch error: $e");
    }
  }

  void _checkDeviation(LatLng currentPos) {
    if (_routeCoords.isEmpty) return;

    double minD = double.infinity;
    final distHelper = Distance();
    int limit = _routeCoords.length > 20 ? 20 : _routeCoords.length;

    for (int i = 0; i < limit; i++) {
      final d = distHelper.as(LengthUnit.Meter, currentPos, _routeCoords[i]);
      if (d < minD) minD = d;
    }

    if (minD > 150) {
      final now = DateTime.now();
      if (_lastRouteFetch == null ||
          now.difference(_lastRouteFetch!).inSeconds > 20) {
        debugPrint(
          "📡 Rider deviated (${minD.round()}m). Recalculating customer view...",
        );
        _fetchRoadRoute();
      }
    }
  }

  void _pruneRoute(LatLng currentPos) {
    if (_routeCoords.isEmpty) return;

    int nearestIdx = -1;
    double minDistance = double.infinity;
    final distanceHelper = Distance();

    int searchLimit = _routeCoords.length > 40 ? 40 : _routeCoords.length;

    for (int i = 0; i < searchLimit; i++) {
      final dist = distanceHelper.as(
        LengthUnit.Meter,
        currentPos,
        _routeCoords[i],
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestIdx = i;
      }
    }

    if (nearestIdx != -1 && minDistance < 40) {
      setState(() {
        _routeCoords.removeRange(0, nearestIdx);
      });
    }
  }

  void _updateStatusText() {
    if (_riderLoc == null || _deliveryLoc == null) {
      if (mounted)
        setState(() => _deliveryStatus = "Rider is preparing for trip...");
      return;
    }

    final double dist =
        Distance().as(LengthUnit.Meter, _riderLoc!, _deliveryLoc!) /
        1000.0;

    int mins = 0;
    if (_apiDurationMinutes > 0 && _routeCoords.isNotEmpty) {
      mins = (dist * 2.1).ceil() + 1;
    } else {
      mins = (dist * 2.5).ceil() + 2;
    }

    if (mounted) {
      setState(() {
        _deliveryStatus = dist < 0.1
            ? "Rider has arrived at your location!"
            : "Rider is ${dist.toStringAsFixed(1)}km away • $mins mins away";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(riderTrackingProvider);
    final myRiderState = trackingState[widget.order.id];

    if (myRiderState != null && myRiderState.location != _riderLoc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _riderLoc = myRiderState.location;
            _updateStatusText();
            _pruneRoute(_riderLoc!);
            _checkDeviation(_riderLoc!);
          });
          _mapController.move(_riderLoc!, _mapController.camera.zoom);
        }
      });
    }

    if (_isLoading) {
      return Container(
        height: 150.h,
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(color: Colors.blue.shade100, width: 2.5.w),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFA9BCA4)),
        ),
      );
    }

    if (!_hasDelivery) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Color(0xFF5D9ECC), width: 2.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
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
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _riderLoc ?? LatLng(16.3142, 80.4187),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.teasntrees.tnt_lh',
                      ),
                      if (_routeCoords.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routeCoords,
                              strokeWidth: 4.5,
                              color: Color(0xFF5D9ECC),
                            ),
                          ],
                        )
                      else if (_pickupLoc != null && _deliveryLoc != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_pickupLoc!, _deliveryLoc!],
                              strokeWidth: 4.5,
                              color: Color(0xFF5D9ECC).withOpacity(0.3),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_riderLoc != null)
                            Marker(
                              point: _riderLoc!,
                              width: 32.w,
                              height: 32.h,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(
                                    0xFF5D9ECC,
                                  ).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14.w,
                                    height: 14.h,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF267CB9),
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(
                                        BorderSide(
                                          color: Colors.white,
                                          width: 2.0.w,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_pickupLoc != null)
                            Marker(
                              point: _pickupLoc!,
                              width: 30.w,
                              height: 30.h,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFA9BCA4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.coffee,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                            ),
                          if (_deliveryLoc != null)
                            Marker(
                              point: _deliveryLoc!,
                              width: 30.w,
                              height: 30.h,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFC76B6B),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.home,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: "locate_rider_${widget.order.id}",
                      onPressed: () {
                        if (_riderLoc != null) {
                          _mapController.move(_riderLoc!, 15.0);
                        }
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF267CB9),
                      child: Icon(Icons.my_location),
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
                    Text(
                      "Tracking Order #${widget.order.orderNumber}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF5D9ECC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _riderName,
                        style: GoogleFonts.poppins(
                          color: Color(0xFF267CB9),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
