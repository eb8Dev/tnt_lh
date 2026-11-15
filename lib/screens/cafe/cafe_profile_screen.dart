import 'package:tnt_lh/core/responsive.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/screens/wishlist_screen.dart';
import 'package:tnt_lh/providers/address_provider.dart';
import 'package:tnt_lh/screens/address_book_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/user_model.dart';
import 'package:tnt_lh/onboarding/onboarding_screen.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/unsaved_changes_provider.dart';
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
      return CenteredPage(
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(child: HouseOfFlavorsLoader(size: 160.sp)),
        ),
      );
    }

    final you = <Widget>[
      _buildMembershipCard(user, isLittleH),
      // The fields only while editing: shown all the time, they looked
      // editable when they weren't. The header already shows name and email.
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _isEditing
            ? Padding(
                padding: EdgeInsets.only(top: Space.sm.h),
                child: _buildDetailsSection(authState),
              )
            : const SizedBox(width: double.infinity),
      ),
      Gap(Space.sm),
      _buildQuickTiles(),
    ];
    final settings = <Widget>[
      _buildAddressSection(),
      Gap(Space.sm),
      _buildPreferencesSection(user),
      Gap(Space.sm),
      _buildSupportSection(),
      Gap(Space.sm),
      _buildLogoutButton(),
      Gap(Space.sm),
      _buildDeleteAccountButton(),
    ];

    // Landscape tablets: you on the left, addresses and settings on the right.
    if (Responsive.isExpanded(context)) {
      Widget column(List<Widget> children) => ListView(
        padding: EdgeInsets.fromLTRB(20.w, Space.md.h, 20.w, Space.xl.h),
        children: children,
      );
      return CenteredPage(
        maxWidth: 1100,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(you)),
                  Expanded(child: column(settings)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CenteredPage(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, Space.md.h, 16.w, Space.lg.h),
              children: [...you, Gap(Space.sm), ...settings],
            ),
          ),
        ),
      ),
    );
  }

  /// Who you are, at a glance: photo (tap to change), name, phone and email,
  /// and "Edit profile". Replaces a large brand-coloured card that cut long
  /// names off and took a third of the screen.
  Widget _buildMembershipCard(User? user, bool isLittleH) {
    final primary = Theme.of(context).colorScheme.primary;
    final name = user?.name?.isNotEmpty == true
        ? user!.name!
        : 'Complete your profile';
    return Container(
      padding: EdgeInsets.all(Space.md.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 30.r,
                  backgroundColor: primary.withValues(alpha: 0.10),
                  backgroundImage: user?.profileImage != null
                      ? NetworkImage(user!.profileImage!)
                      : null,
                  child: user?.profileImage == null
                      ? Text(
                          name.trim().isEmpty
                              ? '?'
                              : name.trim()[0].toUpperCase(),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: _uploadingAvatar
                        ? SizedBox(
                            height: 10.sp,
                            width: 10.sp,
                            child: const CircularProgressIndicator.adaptive(
                              strokeWidth: 1.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : PhosphorIcon(
                            PhosphorIcons.camera(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 10.sp,
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
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if ((user?.mobile ?? '').isNotEmpty)
                  Text(
                    '+91 ${user!.mobile}',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.black54,
                    ),
                  ),
                if ((user?.email ?? '').isNotEmpty)
                  Text(
                    user!.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.black45,
                    ),
                  ),
                SizedBox(height: 4.h),
                GestureDetector(
                  onTap: () =>
                      _isEditing ? _cancelEditing() : _setEditing(true),
                  child: Text(
                    _isEditing ? 'Cancel editing' : 'Edit profile',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Wishlist, addresses and help, one tap each.
  Widget _buildQuickTiles() {
    final primary = Theme.of(context).colorScheme.primary;
    final wishCount = ref.watch(wishlistProvider).value?.length ?? 0;
    final addrCount =
        ref.watch(addressBookProvider).value?.addresses.length ?? 0;
    Widget tile(IconData icon, String label, String? sub, VoidCallback onTap) =>
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 22.sp, color: primary),
                    SizedBox(height: 4.h),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        tile(
          PhosphorIcons.heart(PhosphorIconsStyle.duotone),
          'Wishlist',
          wishCount == 0 ? null : '$wishCount saved',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WishlistScreen()),
          ),
        ),
        GapW(Space.sm),
        tile(
          PhosphorIcons.mapPin(PhosphorIconsStyle.duotone),
          'Addresses',
          addrCount == 0 ? null : '$addrCount saved',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddressBookScreen()),
          ),
        ),
        GapW(Space.sm),
        tile(
          PhosphorIcons.chatCircleDots(PhosphorIconsStyle.duotone),
          'Help',
          null,
          _showHelpSupport,
        ),
      ],
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
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
              ?trailing,
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
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
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
                      child: const CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  /// The address book lives on its own screen now (add, edit, default,
  /// delete, receiver details), shared with the bag and the home header.
  Widget _buildAddressSection() {
    final book = ref.watch(addressBookProvider).value;
    final count = book?.addresses.length ?? 0;
    final main = book?.addresses.where((a) => a.isDefault).firstOrNull;
    return _sectionCard(
      title: 'Saved addresses',
      icon: PhosphorIcons.mapPin(),
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddressBookScreen()),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 0
                          ? 'Add home, work and other places'
                          : '$count saved ${count == 1 ? 'address' : 'addresses'}',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (main != null)
                      Text(
                        '${main.label}: ${main.fullText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                size: 16.sp,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(User? user) {
    final prefs = user?.notificationPreferences ?? NotificationPreferences();
    return _sectionCard(
      title: 'Notifications',
      icon: PhosphorIcons.bell(),
      children: [
        _switchRow(
          'Push',
          prefs.push,
          (v) => _updateNotificationPreference('push', v),
        ),
        _switchRow(
          'Email',
          prefs.email,
          (v) => _updateNotificationPreference('email', v),
        ),
        _switchRow(
          'SMS',
          prefs.sms,
          (v) => _updateNotificationPreference('sms', v),
        ),
        _switchRow(
          'Offers & treats',
          prefs.offers,
          (v) => _updateNotificationPreference('offers', v),
        ),
      ],
    );
  }

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged) {
    // The card behind it paints a background, which hides a ListTile's tap
    // highlight; its own transparent Material puts the ink back on top.
    return Material(
      type: MaterialType.transparency,
      child: _switchTile(title, value, onChanged),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
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
        _menuRow(
          'Help & feedback',
          PhosphorIcons.chatCircleDots(),
          _showHelpSupport,
        ),
        Gap(Space.xs),
        _menuRow(
          'Privacy policy',
          PhosphorIcons.shieldCheck(),
          _launchPrivacyPolicy,
        ),
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

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete your account?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Your name, phone number, email, saved addresses and photo will be '
          'removed, and you will be signed out. This cannot be undone.\n\n'
          'Records of past orders are kept, without your profile details.',
          style: GoogleFonts.poppins(fontSize: 13.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final refused = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    if (refused != null) {
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: refused,
        isError: true,
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen(onGetStarted: () {})),
      (route) => false,
    );
  }

  Widget _buildDeleteAccountButton() {
    return Center(
      child: TextButton(
        onPressed: _confirmDeleteAccount,
        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
        child: Text(
          'Delete account',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 13.sp,
          ),
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? "Message can't be empty"
                      : null,
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
                        final parts = (user?.name ?? 'Customer').trim().split(
                          ' ',
                        );
                        await ContactService.submitContactForm(
                          firstName: parts.first.isEmpty
                              ? 'Customer'
                              : parts.first,
                          lastName: parts.length > 1
                              ? parts.sublist(1).join(' ')
                              : '-',
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
