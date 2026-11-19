import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/auth/widgets/auth_widgets.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/services/address_service.dart';

/// First sign-in: name, email, and where to deliver (picked on the map, saved
/// to the address book as Home). Mobile is asked only when Google or Apple
/// didn't provide one.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  final String? initialMobile;
  final String? initialName;
  final String? initialEmail;
  const CompleteProfileScreen({
    super.key,
    this.initialMobile,
    this.initialName,
    this.initialEmail,
  });

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _email = TextEditingController(text: widget.initialEmail);
  late final _mobile = TextEditingController(text: widget.initialMobile);
  ({String line, double lat, double lng})? _place;
  String? _error;
  bool _saving = false;

  bool get _needsMobile => (widget.initialMobile ?? '').isEmpty;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialLabel: 'Home',
          initialAddress: _place?.line,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _place = (
        line: result['address'] as String,
        lat: (result['lat'] as num).toDouble(),
        lng: (result['lng'] as num).toDouble(),
      );
      _error = null;
    });
  }

  Future<void> _finish() async {
    if (!_form.currentState!.validate()) return;
    final place = _place;
    if (place == null) {
      setState(() => _error = 'Add the address we should deliver to.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // Saved to the address book first: once the profile is complete the app
    // moves on to the home screen.
    try {
      await AddressService.addAddress(
        label: 'Home',
        addressLine: place.line,
        latitude: place.lat,
        longitude: place.lng,
        isDefault: true,
      );
    } catch (_) {
      // Not fatal: the customer can add it at checkout.
    }
    await ref
        .read(authProvider.notifier)
        .completeProfile(
          name: _name.text.trim(),
          email: _email.text.trim(),
          address: place.line,
          mobile: _needsMobile ? _mobile.text.trim() : widget.initialMobile,
        );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final authError = ref.watch(authProvider.select((s) => s.error));
    final primary = Theme.of(context).colorScheme.primary;

    InputDecoration field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20.sp),
      filled: true,
      fillColor: const Color(0xFFF6F6F2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Sign out',
          icon: Icon(PhosphorIcons.x(), color: Colors.black87),
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: Space.lg.w),
            children: [
              Text(
                'Nice to meet you',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(Space.xs),
              Text(
                'A few details and you are ready to order.',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.black54,
                ),
              ),
              Gap(Space.xl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: field('Your name', PhosphorIcons.user()),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter your name.' : null,
              ),
              Gap(Space.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: field('Email', PhosphorIcons.envelopeSimple()),
                validator: (v) =>
                    RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter an email we can send receipts to.',
              ),
              if (_needsMobile) ...[
                Gap(Space.md),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: field('Mobile number', PhosphorIcons.phone()),
                  validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                      ? null
                      : 'Enter your 10-digit mobile number.',
                ),
              ],
              Gap(Space.lg),
              Text(
                'Deliver to',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Gap(Space.xs),
              InkWell(
                onTap: _saving ? null : _pickAddress,
                borderRadius: BorderRadius.circular(14.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(Space.md.r),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    color: _place == null
                        ? Colors.white
                        : primary.withValues(alpha: 0.06),
                    border: Border.all(
                      color: _place == null ? Colors.black12 : primary,
                      width: _place == null ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _place == null
                            ? PhosphorIcons.mapPinPlus()
                            : PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        color: primary,
                        size: 24.sp,
                      ),
                      GapW(Space.sm),
                      Expanded(
                        child: Text(
                          _place?.line ?? 'Pick your address on the map',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5.sp,
                            color: _place == null
                                ? Colors.black54
                                : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Text(
                        _place == null ? 'Add' : 'Change',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AuthError(_error ?? authError),
              Gap(Space.xl),
              AuthPrimaryButton(
                label: 'Start ordering',
                busy: _saving,
                onTap: _finish,
              ),
              Gap(Space.lg),
            ],
          ),
        ),
      ),
    );
  }
}
