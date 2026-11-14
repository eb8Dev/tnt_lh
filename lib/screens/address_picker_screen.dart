import 'package:tnt_lh/core/responsive.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tnt_lh/services/places_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';

class AddressPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  /// Seed values, used when editing a saved address so the picker opens on the
  /// existing pin with the label/text already filled in.
  final double? initialLat;
  final double? initialLng;
  final String? initialLabel;
  final String? initialAddress;

  const AddressPickerScreen({
    super.key,
    this.initialLocation,
    this.initialLat,
    this.initialLng,
    this.initialLabel,
    this.initialAddress,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const LatLng _defaultLoc = LatLng(16.3142, 80.4187); // Guntur

  late LatLng _selectedLoc;
  GoogleMapController? _mapController;
  String _addressText = "Loading address...";
  late final TextEditingController _nameController;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;

  // Places search: suggestions as you type.
  String _session = PlacesService.newSessionToken();
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  int _query = 0;
  bool _placesDown = false;

  /// A picked place already set the address text; the camera settling on it
  /// must not replace that with a reverse-geocoded street.
  bool _keepNextAddress = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLabel?.trim().isNotEmpty == true
          ? widget.initialLabel!.trim()
          : "Home",
    );
    _selectedLoc =
        widget.initialLocation ??
        (widget.initialLat != null && widget.initialLng != null
            ? LatLng(widget.initialLat!, widget.initialLng!)
            : _defaultLoc);

    // If we were handed the address text (editing), show it immediately rather
    // than a "Loading…" flash, then refine from the pin.
    if (widget.initialAddress?.trim().isNotEmpty == true) {
      _addressText = widget.initialAddress!.trim();
    }
    _reverseGeocode(_selectedLoc);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng loc) async {
    if (_keepNextAddress) {
      _keepNextAddress = false;
      return;
    }
    setState(() => _isLoading = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          // Skip the empty parts; this used to read "null, null, Guntur".
          _addressText = [
            p.street,
            p.subLocality,
            p.locality,
            p.postalCode,
          ].where((x) => x != null && x.trim().isNotEmpty).toSet().join(', ');
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

  /// Search for an address by text and drop the pin there.
  ///
  /// Requested by testers: typing the address and having the map jump to it is
  /// far quicker than dragging the map across the city by hand.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (_placesDown) return;
    final q = text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final mine = ++_query;
      try {
        final list = await PlacesService.autocomplete(
          q,
          sessionToken: _session,
          nearLat: _selectedLoc.latitude,
          nearLng: _selectedLoc.longitude,
        );
        // Only the newest query's answer counts.
        if (mounted && mine == _query) setState(() => _suggestions = list);
      } catch (_) {
        // Places not available (not enabled for the key, offline): the
        // street-address search below still works on submit.
        if (mounted) setState(() => _placesDown = true);
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _isSearching = true;
    });
    try {
      final d = await PlacesService.details(s.placeId, sessionToken: _session);
      _session = PlacesService.newSessionToken(); // the session ends on a pick
      final loc = LatLng(d.lat, d.lng);
      _selectedLoc = loc;
      _keepNextAddress = true;
      setState(() {
        _searchController.text = s.title;
        _addressText = d.name.isNotEmpty && !d.address.startsWith(d.name)
            ? '${d.name}, ${d.address}'
            : d.address;
      });
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
    } catch (_) {
      _snack("Couldn't open that place. Try another result.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchAddress(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    // With suggestions showing, Search takes the top one.
    if (_suggestions.isNotEmpty) return _pickSuggestion(_suggestions.first);

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final results = await geo.locationFromAddress(q);
      if (results.isEmpty) {
        _snack("Couldn't find that address. Try adding the area or city.");
        return;
      }
      final loc = LatLng(results.first.latitude, results.first.longitude);
      _selectedLoc = loc;
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 16));
      await _reverseGeocode(loc);
    } catch (_) {
      _snack("Couldn't find that address. Try adding the area or city.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
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

    // The permission prompts above are awaited, so the picker may already be
    // gone by the time the customer answers them.
    if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = Responsive.isExpanded(context);
    final mapButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: "zoom_in",
          onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          mini: true,
          child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
        ),
        SizedBox(height: 8.h),
        FloatingActionButton(
          heroTag: "zoom_out",
          onPressed: () =>
              _mapController?.animateCamera(CameraUpdate.zoomOut()),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          mini: true,
          child: Icon(PhosphorIcons.minus(PhosphorIconsStyle.bold)),
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
              : Icon(PhosphorIcons.crosshair()),
        ),
      ],
    );
    final mapLayers = <Widget>[
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _selectedLoc, zoom: 16),
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
          child: Icon(
            PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            color: Colors.red,
            size: 45.sp,
          ),
        ),
      ),

      // Search bar — type an address, the map jumps to it.
      Positioned(
        top: 12.h,
        left: 16.w,
        right: 16.w,
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14.r),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchAddress,
            onChanged: _onSearchChanged,
            style: GoogleFonts.poppins(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: "Search area, street, landmark…",
              hintStyle: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: Colors.black38,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(
                PhosphorIcons.magnifyingGlass(),
                size: 18.sp,
                color: Colors.black54,
              ),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(12.r),
                      child: SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        PhosphorIcons.arrowRight(),
                        size: 18.sp,
                        color: Colors.black54,
                      ),
                      onPressed: () => _searchAddress(_searchController.text),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
            ),
          ),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Positioned(
          top: 64.h,
          left: 16.w,
          right: 16.w,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(14.r),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final sug in _suggestions.take(5))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      PhosphorIcons.mapPin(),
                      size: 18.sp,
                      color: Colors.black54,
                    ),
                    title: Text(
                      sug.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: sug.subtitle.isEmpty
                        ? null
                        : Text(
                            sug.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.black54,
                            ),
                          ),
                    onTap: () => _pickSuggestion(sug),
                  ),
              ],
            ),
          ),
        ),
    ];
    final addressPanel = Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
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
          // Naming the place (Home, Work...) and the flat and floor come on
          // the next screen; this one is only about where the pin goes.
          Text(
            "Move the map to put the pin on your door",
            style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.black54),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                PhosphorIcons.mapTrifold(),
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
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                elevation: 0,
              ),
              child: Text(
                "Confirm location",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Choose delivery location",
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
      // On landscape tablets the buttons sit in the map pane instead.
      floatingActionButton: expanded
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: 170.h), // Above the address card
              child: mapButtons,
            ),
      body: expanded
          // Landscape tablets: map on the left (the pin stays centred in what
          // you can see), the address form on the right.
          ? Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ...mapLayers,
                      Positioned(right: 16, bottom: 24, child: mapButtons),
                    ],
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(child: addressPanel),
                ),
              ],
            )
          : Stack(
              children: [
                ...mapLayers,
                // Address Card
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                    color: Colors.white,
                    child: SafeArea(top: false, child: addressPanel),
                  ),
                ),
              ],
            ),
    );
  }
}
