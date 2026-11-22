import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';
import '../../widgets/busy.dart';

/// The big action button of the sign-in screens, with a busy state.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = onTap != null && !busy;
    return TactileButton(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled || busy ? primary : primary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: busy
              ? BusyLabel(color: Colors.white)
              : Text(
                  label,
                  key: ValueKey(label),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Continue with Google" / "Sign in with Apple".
class AuthSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool dark;
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      onTap: onTap,
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: dark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: dark ? Colors.black : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            GapW(Space.sm),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// +91 and a 10-digit number, with a check when it's complete.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  const PhoneField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 54.h,
      padding: EdgeInsets.symmetric(horizontal: Space.md.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F2),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Text(
            '+91',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Container(
            width: 1,
            height: 22.h,
            margin: EdgeInsets.symmetric(horizontal: Space.sm.w),
            color: Colors.black12,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Mobile number',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  color: Colors.black38,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, _) => AnimatedScale(
              scale: v.text.length == 10 ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: primary,
                size: 22.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short error under a field, sliding in and out.
class AuthError extends StatelessWidget {
  final String? message;
  const AuthError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: Space.sm.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                    color: Colors.red.shade600,
                    size: 16.sp,
                  ),
                  GapW(Space.xs),
                  Expanded(
                    child: Text(
                      message!,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5.sp,
                        color: Colors.red.shade700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
