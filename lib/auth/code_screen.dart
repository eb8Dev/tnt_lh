import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/widgets/auth_widgets.dart';
import 'package:tnt_lh/core/spacing.dart';

/// The 6-digit code: fills itself from the SMS where the phone allows,
/// checks itself at the sixth digit, and shakes when it's wrong.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen>
    with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _changed(String v) {
    final flow = ref.read(phoneSignInProvider.notifier);
    if (ref.read(phoneSignInProvider).error != null) flow.clearError();
    if (v.length == 6) flow.verify(v);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneSignInProvider);
    final flow = ref.read(phoneSignInProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    // A wrong code: shake, clear, ready for the next try.
    ref.listen(phoneSignInProvider.select((s) => s.error), (prev, next) {
      if (next != null && prev == null && _code.text.length == 6) {
        HapticFeedback.mediumImpact();
        _shake.forward(from: 0);
        _code.clear();
        _focus.requestFocus();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Change number',
          icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.black87),
          onPressed: flow.editNumber,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the code',
                style: GoogleFonts.poppins(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(Space.xs),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'Sent by SMS to '),
                    TextSpan(
                      text: '+91 ${state.phone}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const TextSpan(text: '. '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: flow.editNumber,
                        child: Text(
                          'Change',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(Space.xl),
              AnimatedBuilder(
                animation: _shake,
                builder: (_, child) {
                  final t = _shake.value;
                  final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: _CodeBoxes(
                  controller: _code,
                  focusNode: _focus,
                  enabled: !state.verifying,
                  hasError: state.error != null,
                  onChanged: _changed,
                ),
              ),
              AuthError(state.error),
              Gap(Space.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.verifying
                    ? Row(
                        key: const ValueKey('checking'),
                        children: [
                          SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(primary),
                            ),
                          ),
                          GapW(Space.sm),
                          Text(
                            'Checking the code',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      )
                    : state.resendIn > 0
                    ? Text(
                        'Send again in 0:${state.resendIn.toString().padLeft(2, '0')}',
                        key: const ValueKey('wait'),
                        style: GoogleFonts.poppins(
                          fontSize: 13.5.sp,
                          color: Colors.black45,
                        ),
                      )
                    : TextButton(
                        key: const ValueKey('resend'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: primary,
                        ),
                        onPressed: state.sending
                            ? null
                            : () => flow.sendCode(state.phone, resend: true),
                        child: Text(
                          state.sending
                              ? 'Sending'
                              : "Didn't get it? Send again",
                          style: GoogleFonts.poppins(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six boxes over one hidden field, so paste and SMS autofill both work.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        // The real input: invisible, but it gets the keyboard, paste and autofill.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enabled: enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: onChanged,
            showCursor: false,
            enableInteractiveSelection: false,
          ),
        ),
        GestureDetector(
          onTap: focusNode.requestFocus,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final digit = i < v.text.length ? v.text[i] : '';
                final active = i == v.text.length && enabled;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46.w,
                  height: 56.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: hasError
                          ? Colors.red.shade400
                          : (active ? primary : Colors.transparent),
                      width: 2,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: digit.isEmpty ? 0.6 : 1,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: Text(
                      digit,
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
