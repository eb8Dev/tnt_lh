import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/models/user_model.dart';
import 'package:tnt_lh/onboarding/onboarding_screen.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/unsaved_changes_provider.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/services/address_service.dart';
import 'package:tnt_lh/services/contact_service.dart';
import 'package:tnt_lh/services/upload_service.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class CafeProfileScreen extends ConsumerStatefulWidget {
  const CafeProfileScreen({super.key});

  @override
  ConsumerState<CafeProfileScreen> createState() => _CafeProfileScreenState();
}

class _CafeProfileScreenState extends ConsumerState<CafeProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  bool _isEditing = false;
  bool _uploadingAvatar = false;

  // Saved addresses replace the old free-text "Delivery Address" box: checkout
  // already lets people keep several, so the profile has to manage the same set.
  List<SavedAddress> _addresses = [];
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();

    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) {
        _nameController.text = user.name ?? '';
        _emailController.text = user.email ?? '';
      }
      _loadAddresses();
    });

    // Any keystroke while editing marks the profile dirty, so the shell can
    // warn before the user taps away to another tab.
    _nameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isEditing) return;
    final user = ref.read(authProvider).user;
    final dirty =
        _nameController.text.trim() != (user?.name ?? '') ||
        _emailController.text.trim() != (user?.email ?? '');
    ref.read(profileHasUnsavedChangesProvider.notifier).set(dirty);
  }

  void _setEditing(bool editing) {
    setState(() => _isEditing = editing);
    if (!editing) {
      ref.read(profileHasUnsavedChangesProvider.notifier).set(false);
    }
  }

  void _cancelEditing() {
    final user = ref.read(authProvider).user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _setEditing(false);
  }

  // ---------------------------------------------------------------- addresses

  Future<void> _loadAddresses() async {
    try {
      final brand = ref.read(brandProvider);
      final list = await AddressService.getAddresses(brand: brand);
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _loadingAddresses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _addAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (picked == null || !mounted) return;

    final label = (picked['name'] as String?)?.trim() ?? '';
    final line = (picked['address'] as String?)?.trim() ?? '';
    try {
      await AddressService.addAddress(
        label: label.isEmpty ? 'Home' : label,
        addressLine: line,
        latitude: picked['lat'] as double?,
        longitude: picked['lng'] as double?,
        isDefault: _addresses.isEmpty,
        brand: ref.read(brandProvider),
      );
      await _loadAddresses();
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Address saved.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  /// Edit an existing address. You could add and remove but not correct one, so
  /// a typo'd flat number meant deleting and starting over. Opens the picker
  /// seeded with the current pin, then PUTs the change.
  Future<void> _editAddress(SavedAddress a) async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialLat: a.latitude,
          initialLng: a.longitude,
          initialLabel: a.label,
          initialAddress: a.addressLine,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final label = (picked['name'] as String?)?.trim() ?? '';
    final line = (picked['address'] as String?)?.trim() ?? '';
    try {
      await AddressService.updateAddress(
        addressId: a.id,
        label: label.isEmpty ? a.label : label,
        addressLine: line,
        latitude: picked['lat'] as double?,
        longitude: picked['lng'] as double?,
        brand: ref.read(brandProvider),
      );
      await _loadAddresses();
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Address updated.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _makeDefault(SavedAddress a) async {
    await AddressService.setDefault(a.id, brand: ref.read(brandProvider));
    await _loadAddresses();
  }

  Future<void> _deleteAddress(SavedAddress a) async {
    await AddressService.deleteAddress(a.id, brand: ref.read(brandProvider));
    await _loadAddresses();
  }

  // ------------------------------------------------------------------ profile

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await UploadService.uploadImage(
        File(picked.path),
        folder: 'profiles',
      );
      await ref.read(authProvider.notifier).updateProfile(profileImage: url);
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Profile photo updated.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
          );

      final authState = ref.read(authProvider);
      if (!mounted) return;
      if (authState.error == null) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: 'Profile updated.',
        );
        _setEditing(false);
      } else {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: authState.error!,
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Could not update your profile. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _updateNotificationPreference(String key, bool value) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final prefs = Map<String, bool>.from(
      user.notificationPreferences?.toJson() ??
          NotificationPreferences().toJson(),
    );
    prefs[key] = value;

    try {
      await ref
          .read(authProvider.notifier)
          .updateProfile(notificationPreferences: prefs, isBackground: true);
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Couldn't save that preference.",
          isError: true,
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen(onGetStarted: () {})),
      (route) => false,
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse('https://teasntrees.in/privacy');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'could not launch';
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Couldn't open the privacy policy.",
          isError: true,
        );
      }
    }
  }

  // --------------------------------------------------------------------- ui

  @override
  Widget build(BuildContext context) {
    // The login response is partial — the full profile (email, address, prefs)
    // lands later via a background fetch. Reading it once in initState left the
    // email box blank. Re-sync whenever the user object changes, unless the
    // person is mid-edit (never clobber what they're typing).
    ref.listen<AuthState>(authProvider, (_, next) {
      final u = next.user;
      if (u == null || _isEditing) return;
      if (_nameController.text != (u.name ?? '')) {
        _nameController.text = u.name ?? '';
      }
      if (_emailController.text != (u.email ?? '')) {
        _emailController.text = u.email ?? '';
      }
    });

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isLittleH = ref.watch(brandProvider) == 'littleh';

    if (authState.isLoading && user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: HouseOfFlavorsLoader(size: 160.sp)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, Space.md.h, 20.w, 120.h),
            children: [
              _buildMembershipCard(user, isLittleH),
              Gap(Space.lg),
              _buildDetailsSection(authState),
              Gap(Space.lg),
              _buildAddressSection(),
              Gap(Space.lg),
              _buildPreferencesSection(user),
              Gap(Space.lg),
              _buildSupportSection(),
              Gap(Space.lg),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// The header reads like a café loyalty card rather than a settings page —
  /// warm brand gradient, the avatar sitting on it, and the handful of facts
  /// that matter (who you are, how we reach you).
  Widget _buildMembershipCard(User? user, bool isLittleH) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(Space.lg.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              PhosphorIcon(
                isLittleH
                    ? PhosphorIcons.bread(PhosphorIconsStyle.fill)
                    : PhosphorIcons.coffee(PhosphorIconsStyle.fill),
                color: Colors.white.withValues(alpha: 0.9),
                size: 18.sp,
              ),
              GapW(Space.xs),
              Text(
                isLittleH ? 'LITTLE H' : 'TEAS N TREES',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TactileButton(
                onTap: () =>
                    _isEditing ? _cancelEditing() : _setEditing(true),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Space.sm.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        _isEditing
                            ? PhosphorIcons.x()
                            : PhosphorIcons.pencilSimple(),
                        color: Colors.white,
                        size: 13.sp,
                      ),
                      GapW(Space.xxs),
                      Text(
                        _isEditing ? 'Cancel' : 'Edit',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Gap(Space.ml),
          Row(
            children: [
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      child: CircleAvatar(
                        radius: 34.r,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.profileImage != null
                            ? NetworkImage(user!.profileImage!)
                            : null,
                        child: user?.profileImage == null
                            ? PhosphorIcon(
                                PhosphorIcons.user(PhosphorIconsStyle.duotone),
                                size: 30.sp,
                                color: primary.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(5.r),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5.w),
                        ),
                        child: _uploadingAvatar
                            ? SizedBox(
                                height: 11.sp,
                                width: 11.sp,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: Colors.white,
                                ),
                              )
                            : PhosphorIcon(
                                PhosphorIcons.camera(PhosphorIconsStyle.fill),
                                color: Colors.white,
                                size: 11.sp,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              GapW(Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name?.isNotEmpty == true
                          ? user!.name!
                          : 'Complete your profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(Space.xxs),
                    Text(
                      user?.mobile ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required PhosphorIconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsets.all(Space.md.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                icon,
                size: 18.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
              GapW(Space.xs),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          Gap(Space.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailsSection(AuthState authState) {
    return _sectionCard(
      title: 'Your details',
      icon: PhosphorIcons.identificationCard(),
      children: [
        _field(
          label: 'Full name',
          controller: _nameController,
          icon: PhosphorIcons.user(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        Gap(Space.sm),
        _field(
          label: 'Email',
          controller: _emailController,
          icon: PhosphorIcons.envelopeSimple(),
          validator: (v) => (v == null || !v.contains('@'))
              ? 'Enter a valid email'
              : null,
        ),
        if (_isEditing) ...[
          Gap(Space.md),
          SizedBox(
            width: double.infinity,
            height: Sizes.buttonPrimary.h,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: authState.isLoading
                  ? SizedBox(
                      height: 18.h,
                      width: 18.h,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Save changes',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required PhosphorIconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      style: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black45),
        prefixIcon: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
          child: PhosphorIcon(
            icon,
            size: 17.sp,
            color: _isEditing
                ? Theme.of(context).colorScheme.primary
                : Colors.black26,
          ),
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 40.w),
        filled: true,
        fillColor: _isEditing ? Colors.white : const Color(0xFFF7F5F0),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Space.sm.w,
          vertical: Space.sm.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4.w,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return _sectionCard(
      title: 'Delivery addresses',
      icon: PhosphorIcons.mapPin(),
      trailing: TactileButton(
        onTap: _addAddress,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.plus(PhosphorIconsStyle.bold),
              size: 13.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
            GapW(Space.xxs),
            Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      children: [
        if (_loadingAddresses)
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.md.h),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_addresses.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xs.h),
            child: Text(
              'No addresses saved yet. Add one and it\'ll be ready at checkout.',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: Colors.black45,
              ),
            ),
          )
        else
          ..._addresses.map(_addressTile),
      ],
    );
  }

  Widget _addressTile(SavedAddress a) {
    return Padding(
      padding: EdgeInsets.only(bottom: Space.xs.h),
      child: Container(
        padding: EdgeInsets.all(Space.sm.r),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F7F2),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: a.isDefault
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            PhosphorIcon(
              a.isDefault
                  ? PhosphorIcons.house(PhosphorIconsStyle.fill)
                  : PhosphorIcons.house(),
              size: 17.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
            GapW(Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        a.label.isEmpty ? 'Address' : a.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (a.isDefault) ...[
                        GapW(Space.xs),
                        Text(
                          'Default',
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    a.addressLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: PhosphorIcon(
                PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
                size: 17.sp,
                color: Colors.black38,
              ),
              onSelected: (v) {
                if (v == 'edit') _editAddress(a);
                if (v == 'default') _makeDefault(a);
                if (v == 'delete') _deleteAddress(a);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!a.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Set as default'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(User? user) {
    final prefs = user?.notificationPreferences ?? NotificationPreferences();
    return _sectionCard(
      title: 'Notifications',
      icon: PhosphorIcons.bell(),
      children: [
        _switchRow('Push', prefs.push, (v) => _updateNotificationPreference('push', v)),
        _switchRow('Email', prefs.email, (v) => _updateNotificationPreference('email', v)),
        _switchRow('SMS', prefs.sms, (v) => _updateNotificationPreference('sms', v)),
        _switchRow('Offers & treats', prefs.offers,
            (v) => _updateNotificationPreference('offers', v)),
      ],
    );
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black87),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSupportSection() {
    return _sectionCard(
      title: 'Support',
      icon: PhosphorIcons.lifebuoy(),
      children: [
        _menuRow('Help & feedback', PhosphorIcons.chatCircleDots(), _showHelpSupport),
        Gap(Space.xs),
        _menuRow('Privacy policy', PhosphorIcons.shieldCheck(), _launchPrivacyPolicy),
      ],
    );
  }

  Widget _menuRow(String title, PhosphorIconData icon, VoidCallback onTap) {
    return TactileButton(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Space.xs.h),
        child: Row(
          children: [
            PhosphorIcon(icon, size: 17.sp, color: Colors.black54),
            GapW(Space.sm),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.black87,
                ),
              ),
            ),
            PhosphorIcon(
              PhosphorIcons.caretRight(),
              size: 14.sp,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: Sizes.buttonPrimary.h,
      child: TextButton.icon(
        onPressed: _logout,
        icon: PhosphorIcon(
          PhosphorIcons.signOut(),
          size: 17.sp,
          color: Colors.red.shade400,
        ),
        label: Text(
          'Log out',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.red.shade400,
          backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(color: Colors.red.shade100),
          ),
        ),
      ),
    );
  }

  void _showHelpSupport() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final contactFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + Space.lg.h,
            left: Space.lg.w,
            right: Space.lg.w,
            top: Space.lg.h,
          ),
          child: Form(
            key: contactFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & feedback',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gap(Space.xxs),
                Text(
                  'Tell us what happened — we read every message.',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: Colors.black54,
                  ),
                ),
                Gap(Space.md),
                TextFormField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    hintText: 'Subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Subject is required' : null,
                ),
                Gap(Space.sm),
                TextFormField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Your message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Message can't be empty" : null,
                ),
                Gap(Space.md),
                SizedBox(
                  width: double.infinity,
                  height: Sizes.buttonPrimary.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!contactFormKey.currentState!.validate()) return;
                      final user = ref.read(authProvider).user;
                      final navigator = Navigator.of(sheetContext);
                      try {
                        // The backend Contact model restricts `subject` to an
                        // enum and requires a lastName, so send the enum value
                        // and fold the typed subject into the message.
                        final typed = subjectController.text.trim();
                        final message = typed.isEmpty
                            ? messageController.text.trim()
                            : '$typed\n\n${messageController.text.trim()}';
                        final parts = (user?.name ?? 'Customer').trim().split(' ');
                        await ContactService.submitContactForm(
                          firstName: parts.first.isEmpty ? 'Customer' : parts.first,
                          lastName:
                              parts.length > 1 ? parts.sublist(1).join(' ') : '-',
                          email: user?.email ?? 'anonymous@example.com',
                          subject: 'Support',
                          message: message,
                        );
                        navigator.pop();
                        if (!mounted) return;
                        SnackBarUtils.showThemedSnackBar(
                          context: context,
                          message: 'Message sent — we\'ll get back to you.',
                        );
                      } catch (e) {
                        if (!mounted) return;
                        SnackBarUtils.showThemedSnackBar(
                          context: context,
                          message: e.toString().replaceFirst('Exception: ', ''),
                          isError: true,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'Send message',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // These are created fresh on every open of the sheet and were never
      // disposed, so each visit to Help & Support leaked two
      // TextEditingControllers (and their focus nodes) for the life of the app.
      subjectController.dispose();
      messageController.dispose();
    });
  }
}
