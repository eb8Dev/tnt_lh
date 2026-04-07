import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tnt_lh/models/user_model.dart';
import 'package:tnt_lh/onboarding/onboarding_screen.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/services/contact_service.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';

class CafeProfileScreen extends ConsumerStatefulWidget {
  const CafeProfileScreen({super.key});

  @override
  ConsumerState<CafeProfileScreen> createState() => _CafeProfileScreenState();
}

class _CafeProfileScreenState extends ConsumerState<CafeProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();

    // Initialize controllers with current user data
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) {
        _nameController.text = user.name ?? '';
        _emailController.text = user.email ?? '';
        _addressController.text = user.address ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
          );

      final authState = ref.read(authProvider);
      if (authState.error == null) {
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(
            context: context,
            message: 'Profile updated successfully',
          );
          setState(() => _isEditing = false);
        }
      } else {
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(
            context: context,
            message: authState.error!,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: 'Error updating profile: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _updateNotificationPreference(String key, bool value) async {
    if (!mounted) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final currentPrefs = user.notificationPreferences?.toJson() ??
        NotificationPreferences().toJson();
    final updatedPrefs = Map<String, bool>.from(currentPrefs);
    updatedPrefs[key] = value;

    try {
      await ref.read(authProvider.notifier).updateProfile(
            notificationPreferences: updatedPrefs,
            isBackground: true,
          );
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: 'Notification preference updated',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: 'Failed to update preference',
          isError: true,
        );
      }
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(authProvider).user;
            final prefs =
                user?.notificationPreferences ?? NotificationPreferences();

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Notification Settings",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPreferenceTile(
                    title: "Push Notifications",
                    value: prefs.push,
                    onChanged: (val) =>
                        _updateNotificationPreference('push', val),
                  ),
                  _buildPreferenceTile(
                    title: "Email Notifications",
                    value: prefs.email,
                    onChanged: (val) =>
                        _updateNotificationPreference('email', val),
                  ),
                  _buildPreferenceTile(
                    title: "SMS Alerts",
                    value: prefs.sms,
                    onChanged: (val) =>
                        _updateNotificationPreference('sms', val),
                  ),
                  _buildPreferenceTile(
                    title: "Special Offers",
                    value: prefs.offers,
                    onChanged: (val) =>
                        _updateNotificationPreference('offers', val),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      value: value,
      activeThumbColor: const Color(0xFFA9BCA4),
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: contactFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Help & Support",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Have a question or feedback? Send us a message.",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: subjectController,
                  decoration: _inputDecoration("Subject"),
                  validator: (val) =>
                      val!.isEmpty ? 'Subject is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: _inputDecoration("Your Message"),
                  validator: (val) =>
                      val!.isEmpty ? 'Message cannot be empty' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!contactFormKey.currentState!.validate()) return;
                      final user = ref.read(authProvider).user;
                      try {
                        await ContactService.submitContactForm(
                          firstName: user?.name?.split(' ').first ?? 'Customer',
                          lastName: user?.name?.contains(' ') == true
                              ? user?.name?.split(' ').last
                              : '',
                          email: user?.email ?? 'anonymous@example.com',
                          subject: subjectController.text.trim(),
                          message: messageController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          SnackBarUtils.showThemedSnackBar(
                            context: context,
                            message: 'Message sent successfully!',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          SnackBarUtils.showThemedSnackBar(
                            context: context,
                            message: 'Failed to send message: $e',
                            isError: true,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      "Send Message",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(onGetStarted: () {}),
        ),
        (context) => false,
      );
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://teasntrees.in/privacy');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: 'Could not open privacy policy: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (authState.isLoading && user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: HouseOfFlavorsLoader(size: 80)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close_rounded : Icons.edit_outlined,
              color: _isEditing ? Colors.red : Colors.black54,
            ),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Cancel editing, reset controllers
                  _nameController.text = user?.name ?? '';
                  _emailController.text = user?.email ?? '';
                  _addressController.text = user?.address ?? '';
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFA9BCA4).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey.shade50,
                        backgroundImage: user?.profileImage != null
                            ? NetworkImage(user!.profileImage!)
                            : null,
                        child: user?.profileImage == null
                            ? const Icon(
                                Icons.person_outline_rounded,
                                size: 50,
                                color: Colors.black26,
                              )
                            : null,
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                user?.name ?? 'Complete your profile',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                user?.mobile ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              // Form Fields
              _buildInputField(
                label: "Full Name",
                controller: _nameController,
                icon: Icons.person_outline_rounded,
                enabled: _isEditing,
                validator: (val) => val!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 24),

              _buildInputField(
                label: "Email Address",
                controller: _emailController,
                icon: Icons.email_outlined,
                enabled: _isEditing,
                validator: (val) => val!.isEmpty || !val.contains('@')
                    ? 'Valid email required'
                    : null,
              ),
              const SizedBox(height: 24),

              _buildInputField(
                label: "Delivery Address",
                controller: _addressController,
                icon: Icons.location_on_outlined,
                enabled: _isEditing,
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'Address is required' : null,
              ),

              const SizedBox(height: 48),

              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Save Changes",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

              if (!_isEditing)
                Column(
                  children: [
                    _buildMenuTile(
                      title: "Notification Settings",
                      icon: Icons.notifications_none_rounded,
                      onTap: _showNotificationSettings,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      title: "Help & Support",
                      icon: Icons.help_outline_rounded,
                      onTap: _showHelpSupport,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      title: "Privacy Policy",
                      icon: Icons.privacy_tip_rounded,
                      onTap: _launchPrivacyPolicy,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: TextButton(
                        onPressed: _logout,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: Colors.red.shade100),
                          ),
                        ),
                        child: Text(
                          "Log Out",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(
            label,
            prefixIcon: Icon(
              icon,
              color: enabled ? const Color(0xFFA9BCA4) : Colors.black26,
            ),
            enabled: enabled,
          ),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    Widget? prefixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade50,
      prefixIcon: prefixIcon,
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black26),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFA9BCA4), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
