import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';

class AddressPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const AddressPickerScreen({super.key, this.initialLocation});

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  late LatLng _selectedLoc;
  LatLng? _realGPSLoc;
  final MapController _mapController = MapController();
  String _addressText = "Loading address...";
  final TextEditingController _nameController = TextEditingController(
    text: "Home",
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to Guntur if no initial location
    _selectedLoc = widget.initialLocation ?? LatLng(16.3142, 80.4187);
    _reverseGeocode(_selectedLoc);
    _fetchRealLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _fetchRealLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _realGPSLoc = LatLng(pos.latitude, pos.longitude);
          });
        }
      }
    } catch (e) {
      debugPrint("Initial GPS fetch failed: $e");
    }
  }

  Future<void> _reverseGeocode(LatLng loc) async {
    setState(() => _isLoading = true);
    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _addressText =
              "${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}";
        });
      }
    } catch (e) {
      setState(() {
        _addressText =
            "Address not found (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location services are disabled.")),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Location permissions denied.")),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location permissions permanently denied."),
          ),
        );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final newLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _realGPSLoc = newLoc;
        _selectedLoc = newLoc;
      });
      _mapController.move(newLoc, 16);
      _reverseGeocode(newLoc);
    } catch (e) {
      debugPrint("Error getting current location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _zoomMap(double delta) {
    final newZoom = _mapController.camera.zoom + delta;
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _resetNorth() {
    _mapController.rotate(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Select Delivery Location",
          style: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 280.0), // Above the address card
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom In
            FloatingActionButton(
              heroTag: "zoom_in",
              onPressed: () => _zoomMap(1.0),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: Icon(Icons.add),
            ),
            SizedBox(height: 8.h),
            // Zoom Out
            FloatingActionButton(
              heroTag: "zoom_out",
              onPressed: () => _zoomMap(-1.0),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: Icon(Icons.remove),
            ),
            SizedBox(height: 16.h),
            // Reset North
            FloatingActionButton(
              heroTag: "reset_north",
              onPressed: _resetNorth,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: Icon(Icons.explore_outlined),
            ),
            SizedBox(height: 8.h),
            // Locate Me
            FloatingActionButton(
              heroTag: "locate_me",
              onPressed: _isLoading ? null : _goToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: _isLoading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(Icons.my_location),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLoc,
              initialZoom: 16,
              onMapEvent: (event) {
                if (event is MapEventMove) {
                  setState(() {
                    _selectedLoc = event.camera.center;
                  });
                }
                if (event is MapEventMoveEnd) {
                  _reverseGeocode(_selectedLoc);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.teasntrees.tnt_lh',
              ),
              if (_realGPSLoc != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _realGPSLoc!,
                      width: 20.w,
                      height: 20.h,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.w),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Center Marker (Selection)
          Center(
            child: Container(
              margin: EdgeInsets.all(0.r),
              child: Icon(Icons.location_on, color: Colors.red, size: 45.sp),
            ),
          ),

          // Address Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Location Name",
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "e.g. Home, Office, Friend's House",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "Address Details",
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18.sp,
                        color: Colors.black54,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _addressText,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoading)
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 55.h,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'address': _addressText,
                                'lat': _selectedLoc.latitude,
                                'lng': _selectedLoc.longitude,
                                'name': _nameController.text.trim(),
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Confirm Location",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
