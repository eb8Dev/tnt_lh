import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';

class AddressPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const AddressPickerScreen({super.key, this.initialLocation});

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const LatLng _defaultLoc = LatLng(16.3142, 80.4187); // Guntur

  late LatLng _selectedLoc;
  GoogleMapController? _mapController;
  String _addressText = "Loading address...";
  final TextEditingController _nameController = TextEditingController(
    text: "Home",
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLoc = widget.initialLocation ?? _defaultLoc;
    _reverseGeocode(_selectedLoc);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng loc) async {
    setState(() => _isLoading = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _addressText =
              "${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressText =
              "Address not found (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack("Location services are disabled.");
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _snack("Location permissions denied.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _snack("Location permissions permanently denied.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final newLoc = LatLng(position.latitude, position.longitude);
      _selectedLoc = newLoc;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLoc, 16),
      );
      _reverseGeocode(newLoc);
    } catch (e) {
      debugPrint("Error getting current location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Select Delivery Location",
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 280.h), // Above the address card
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "zoom_in",
              onPressed: () =>
                  _mapController?.animateCamera(CameraUpdate.zoomIn()),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: Icon(Icons.add_rounded),
            ),
            SizedBox(height: 8.h),
            FloatingActionButton(
              heroTag: "zoom_out",
              onPressed: () =>
                  _mapController?.animateCamera(CameraUpdate.zoomOut()),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              mini: true,
              child: Icon(Icons.remove_rounded),
            ),
            SizedBox(height: 16.h),
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
                  : Icon(Icons.my_location_rounded),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLoc,
              zoom: 16,
            ),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            // Track the map centre as the user pans (no setState per frame),
            // then reverse-geocode once the camera settles.
            onCameraMove: (pos) => _selectedLoc = pos.target,
            onCameraIdle: () => _reverseGeocode(_selectedLoc),
          ),

          // Fixed centre marker — the point the map is centred on is the
          // selected delivery location.
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 45.h), // tip points at centre
              child: Icon(Icons.location_on_rounded, color: Colors.red, size: 45.sp),
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
