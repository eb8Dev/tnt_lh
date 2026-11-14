import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/providers/address_provider.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/services/address_service.dart';

/// Add an address (map pin, then details) or edit one (details, with the pin
/// one tap away). Returns the saved address, already in the address book.
Future<SavedAddress?> openAddressEditor(
  BuildContext context, {
  SavedAddress? existing,
}) async {
  ({String line, double lat, double lng})? pin;
  if (existing == null) {
    pin = await _pickPin(context, null);
    if (pin == null || !context.mounted) return null;
  }
  return Navigator.push<SavedAddress>(
    context,
    MaterialPageRoute(
      builder: (_) => AddressFormScreen(existing: existing, pin: pin),
    ),
  );
}

Future<({String line, double lat, double lng})?> _pickPin(
  BuildContext context,
  SavedAddress? around,
) async {
  final r = await Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      builder: (_) => AddressPickerScreen(
        initialLocation: around?.latitude != null && around?.longitude != null
            ? LatLng(around!.latitude!, around.longitude!)
            : null,
        initialAddress: around?.addressLine,
      ),
    ),
  );
  if (r == null) return null;
  return (
    line: (r['address'] as String?)?.trim() ?? '',
    lat: r['lat'] as double,
    lng: r['lng'] as double,
  );
}

class AddressFormScreen extends ConsumerStatefulWidget {
  final SavedAddress? existing;
  final ({String line, double lat, double lng})? pin;

  const AddressFormScreen({super.key, this.existing, this.pin});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _flat = TextEditingController(text: widget.existing?.flatNo);
  late final _floor = TextEditingController(text: widget.existing?.floor);
  late final _street = TextEditingController(
    text: widget.existing?.addressLine ?? widget.pin?.line,
  );
  late final _landmark = TextEditingController(text: widget.existing?.landmark);
  late final _otherName = TextEditingController(
    text: widget.existing?.kind == AddressKind.other
        ? widget.existing?.label
        : '',
  );
  late final _receiverName = TextEditingController(
    text: widget.existing?.receiverName,
  );
  late final _receiverPhone = TextEditingController(
    text: widget.existing?.receiverPhone,
  );

  late AddressKind _kind = widget.existing?.kind ?? AddressKind.home;
  late bool _forSomeoneElse = widget.existing?.hasReceiver ?? false;
  late bool _makeDefault = widget.existing?.isDefault ?? false;
  late double? _lat = widget.existing?.latitude ?? widget.pin?.lat;
  late double? _lng = widget.existing?.longitude ?? widget.pin?.lng;
  late String _pinLine = widget.existing?.addressLine ?? widget.pin?.line ?? '';

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _flat,
      _floor,
      _street,
      _landmark,
      _otherName,
      _receiverName,
      _receiverPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _movePin() async {
    final pin = await _pickPin(
      context,
      SavedAddress(
        id: '',
        label: '',
        addressLine: _pinLine,
        latitude: _lat,
        longitude: _lng,
      ),
    );
    if (pin == null || !mounted) return;
    setState(() {
      _lat = pin.lat;
      _lng = pin.lng;
      _pinLine = pin.line;
      _street.text = pin.line;
    });
  }

  /// The phone's own contact picker: no permission to read the address
  /// book is needed, the customer just chooses one number.
  Future<void> _pickContact() async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      if (c == null || !mounted) return;
      final digits =
          (c.selectedPhoneNumber ?? c.phoneNumbers?.firstOrNull ?? '')
              .replaceAll(RegExp(r'\D'), '');
      // +91 98480 22338, 098480 22338 and 9848022338 are the same number.
      final phone = digits.length > 10
          ? digits.substring(digits.length - 10)
          : digits;
      setState(() {
        if ((c.fullName ?? '').trim().isNotEmpty) {
          _receiverName.text = c.fullName!.trim();
        }
        _receiverPhone.text = phone;
      });
      HapticFeedback.selectionClick();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open your contacts")),
      );
    }
  }

  String get _label => switch (_kind) {
    AddressKind.home => 'Home',
    AddressKind.work => 'Work',
    AddressKind.other =>
      _otherName.text.trim().isEmpty ? 'Other' : _otherName.text.trim(),
  };

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    final receiverName = _forSomeoneElse ? _receiverName.text.trim() : '';
    final receiverPhone = _forSomeoneElse ? _receiverPhone.text.trim() : '';
    try {
      final existing = widget.existing;
      final saved = existing == null
          ? await AddressService.addAddress(
              label: _label,
              addressLine: _street.text.trim(),
              latitude: _lat,
              longitude: _lng,
              isDefault: _makeDefault,
              flatNo: _flat.text.trim(),
              floor: _floor.text.trim(),
              landmark: _landmark.text.trim(),
              receiverName: receiverName,
              receiverPhone: receiverPhone,
            )
          : await AddressService.updateAddress(
              addressId: existing.id,
              label: _label,
              addressLine: _street.text.trim(),
              latitude: _lat,
              longitude: _lng,
              isDefault: _makeDefault ? true : null,
              flatNo: _flat.text.trim(),
              floor: _floor.text.trim(),
              landmark: _landmark.text.trim(),
              receiverName: receiverName,
              receiverPhone: receiverPhone,
            );
      await ref
          .read(addressBookProvider.notifier)
          .refresh(select: saved?.id ?? existing?.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return CenteredPage(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Text(
            widget.existing == null ? 'Address details' : 'Edit address',
            style: GoogleFonts.poppins(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                Space.md.w,
                Space.xs.h,
                Space.md.w,
                Space.lg.h,
              ),
              children: [
                // Where the pin is, with a way to move it.
                _Card(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(Space.xs.r),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          color: primary,
                          size: 20.sp,
                        ),
                      ),
                      GapW(Space.sm),
                      Expanded(
                        child: Text(
                          _pinLine.isEmpty ? 'Pin on the map' : _pinLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _movePin,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                Gap(Space.sm),
                _Card(
                  child: Column(
                    children: [
                      _Field(
                        controller: _flat,
                        label: 'House / flat / block no.',
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'The rider needs this to find your door'
                            : null,
                      ),
                      Gap(Space.sm),
                      _Field(controller: _floor, label: 'Floor (optional)'),
                      Gap(Space.sm),
                      _Field(
                        controller: _street,
                        label: 'Building, street and area',
                        maxLines: 2,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Add the street or area'
                            : null,
                      ),
                      Gap(Space.sm),
                      _Field(
                        controller: _landmark,
                        label: 'Landmark (optional)',
                        hint: 'e.g. opposite the temple',
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
                Gap(Space.sm),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save as',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Gap(Space.xs),
                      Wrap(
                        spacing: Space.xs.w,
                        children: [
                          for (final k in AddressKind.values)
                            ChoiceChip(
                              avatar: Icon(
                                kindIcon(k),
                                size: 16.sp,
                                color: _kind == k ? primary : Colors.black54,
                              ),
                              label: Text(switch (k) {
                                AddressKind.home => 'Home',
                                AddressKind.work => 'Work',
                                AddressKind.other => 'Other',
                              }),
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: _kind == k
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _kind == k ? primary : Colors.black87,
                              ),
                              showCheckmark: false,
                              selected: _kind == k,
                              selectedColor: primary.withValues(alpha: 0.10),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: _kind == k
                                    ? primary
                                    : Colors.black.withValues(alpha: 0.12),
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _kind = k);
                              },
                            ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _kind == AddressKind.other
                            ? Padding(
                                padding: EdgeInsets.only(top: Space.sm.h),
                                child: _Field(
                                  controller: _otherName,
                                  label: 'Name this place',
                                  hint: "e.g. Mom's house, Gym",
                                  textCapitalization: TextCapitalization.words,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
                Gap(Space.sm),
                _Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _forSomeoneElse,
                        onChanged: (v) => setState(() => _forSomeoneElse = v),
                        title: Text(
                          'Ordering for someone else?',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'The rider will call them, not you',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _forSomeoneElse
                            ? Padding(
                                padding: EdgeInsets.fromLTRB(
                                  Space.md.w,
                                  0,
                                  Space.md.w,
                                  Space.md.h,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _pickContact,
                                        icon: Icon(
                                          PhosphorIcons.addressBook(),
                                          size: 18.sp,
                                        ),
                                        label: const Text(
                                          'Choose from contacts',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            vertical: Space.sm.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Gap(Space.sm),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Space.xs.w,
                                          ),
                                          child: Text(
                                            'or type it in',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.sp,
                                              color: Colors.black45,
                                            ),
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    Gap(Space.sm),
                                    _Field(
                                      controller: _receiverName,
                                      label: "Their name",
                                      textCapitalization:
                                          TextCapitalization.words,
                                      validator: (v) =>
                                          _forSomeoneElse &&
                                              (v ?? '').trim().isEmpty
                                          ? 'Who should the rider ask for?'
                                          : null,
                                    ),
                                    Gap(Space.sm),
                                    _Field(
                                      controller: _receiverPhone,
                                      label: 'Their phone number',
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      validator: (v) {
                                        if (!_forSomeoneElse) return null;
                                        return RegExp(
                                              r'^[0-9]{10}$',
                                            ).hasMatch((v ?? '').trim())
                                            ? null
                                            : 'Enter a 10-digit number';
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
                if (widget.existing?.isDefault != true) ...[
                  Gap(Space.xs),
                  CheckboxListTile(
                    value: _makeDefault,
                    onChanged: (v) => setState(() => _makeDefault = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Make this my default address',
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md.w,
              Space.xs.h,
              Space.md.w,
              Space.sm.h,
            ),
            child: SizedBox(
              height: Sizes.buttonPrimary.h,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator.adaptive(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Save address',
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData kindIcon(AddressKind k) => switch (k) {
  AddressKind.home => PhosphorIcons.house(),
  AddressKind.work => PhosphorIcons.briefcase(),
  AddressKind.other => PhosphorIcons.mapPin(),
};

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? EdgeInsets.all(Space.md.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
    ),
    child: child,
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
    );
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        counterText: '',
        labelStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black54),
        hintStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black38),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Space.sm.w,
          vertical: Space.sm.h,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
