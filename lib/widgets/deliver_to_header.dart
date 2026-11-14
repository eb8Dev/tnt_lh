import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/providers/address_provider.dart';
import 'package:tnt_lh/screens/address_book_screen.dart';
import 'package:tnt_lh/screens/address_form_screen.dart';

/// "Home ▾ / Flat 302, Lakshmipuram...": where the next order goes, at the top
/// of the menu, as in every delivery app. Tapping it switches address; the bag
/// delivers to whatever is chosen here.
class DeliverToHeader extends ConsumerWidget {
  const DeliverToHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressBookProvider).value;
    final a = book?.selected;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () {
        HapticFeedback.selectionClick();
        if (book == null || book.addresses.isEmpty) {
          openAddressEditor(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddressBookScreen(choosing: true),
            ),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Space.xxs.h),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
              color: primary,
              size: 22.sp,
            ),
            GapW(Space.xs),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(a?.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a == null
                                ? 'Add a delivery address'
                                : (a.label.isEmpty ? 'Deliver here' : a.label),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                          size: 14.sp,
                        ),
                      ],
                    ),
                    if (a != null)
                      Text(
                        a.fullText,
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
            ),
          ],
        ),
      ),
    );
  }
}
