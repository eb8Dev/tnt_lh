import 'package:tnt_lh/widgets/auth_split.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialMobile;
  final String? initialName;
  final String? initialEmail;

  const RegisterScreen({
    super.key,
    this.initialMobile,
    this.initialName,
    this.initialEmail,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mobileController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.initialMobile);
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authProvider.notifier)
        .completeProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          mobile: _mobileController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Listen for errors and show snackbar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: next.error!,
          isError: true,
        );
      }
    });

    return CenteredPage(
      // Full width on tablets, where AuthSplit lays the page out.
      maxWidth: Responsive.isTablet(context) ? double.infinity : 640,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            "Setup Profile",
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
        ),
        body: AuthSplit(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(30.0.r),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome to the Family",
                    style: GoogleFonts.poppins(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Complete your profile to get the most of your premium experience.",
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 40.h),

                  _buildInputField(
                    label: "Mobile Number",
                    controller: _mobileController,
                    hint: "9876543210",
                    readOnly:
                        widget.initialMobile != null &&
                        widget.initialMobile!.isNotEmpty,
                    keyboardType: TextInputType.phone,
                    icon: PhosphorIcons.deviceMobile(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Mobile is required';
                      }
                      if (val.trim().length != 10) {
                        return 'Enter 10 digits';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24.h),

                  _buildInputField(
                    label: "Full Name",
                    controller: _nameController,
                    hint: "John Doe",
                    icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  SizedBox(height: 24.h),

                  _buildInputField(
                    label: "Email Address",
                    controller: _emailController,
                    hint: "john@example.com",
                    keyboardType: TextInputType.emailAddress,
                    icon: PhosphorIcons.envelopeSimple(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!val.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24.h),

                  _buildInputField(
                    label: "Delivery Address",
                    controller: _addressController,
                    hint: "Flat, House no, Building, Street",
                    maxLines: 3,
                    icon: PhosphorIcons.mapPin(),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  SizedBox(height: 48.h),

                  SizedBox(
                    width: double.infinity,
                    height: 58.h,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _completeProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                          : Text(
                              "Continue to Experience",
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.poppins(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.black26,
              fontSize: 14.sp,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20.sp,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(18.r),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
