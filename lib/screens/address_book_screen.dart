import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/providers/address_provider.dart';
import 'package:tnt_lh/screens/address_form_screen.dart';

/// Saved addresses. Opened from the profile to manage them, or from "Deliver
/// to" (home header, bag) to choose one, in which case a tap picks it.
class AddressBookScreen extends ConsumerWidget {
  final bool choosing;
  const AddressBookScreen({super.key, this.choosing = false});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final saved = await openAddressEditor(context);
    if (saved != null && choosing && context.mounted) {
      ref.read(addressBookProvider.notifier).select(saved.id);
      Navigator.pop(context, saved);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedAddress a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(a.fullText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(addressBookProvider.notifier).delete(a.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final book = ref.watch(addressBookProvider);

    return CenteredPage(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Text(
            choosing ? 'Deliver to' : 'Saved addresses',
            style: GoogleFonts.poppins(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: RefreshIndicator.adaptive(
          onRefresh: () => ref.read(addressBookProvider.notifier).refresh(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Space.md.w,
              Space.xs.h,
              Space.md.w,
              Space.lg.h,
            ),
            children: [
              _AddRow(onTap: () => _add(context, ref)),
              Gap(Space.md),
              ...book.when(
                loading: () => [
                  Padding(
                    padding: EdgeInsets.only(top: Space.xl.h),
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ],
                error: (e, _) => [
                  Padding(
                    padding: EdgeInsets.only(top: Space.xl.h),
                    child: Column(
                      children: [
                        Text(
                          "Couldn't load your addresses.",
                          style: GoogleFonts.poppins(fontSize: 13.sp),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(addressBookProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ],
                data: (b) => b.addresses.isEmpty
                    ? [_Empty()]
                    : [
                        Text(
                          'SAVED ADDRESSES',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                          ),
                        ),
                        Gap(Space.xs),
                        for (final a in b.addresses) ...[
                          _AddressCard(
                            address: a,
                            selected: choosing && b.selected?.id == a.id,
                            onTap: () {
                              if (choosing) {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(addressBookProvider.notifier)
                                    .select(a.id);
                                Navigator.pop(context, a);
                              } else {
                                openAddressEditor(context, existing: a);
                              }
                            },
                            onEdit: () =>
                                openAddressEditor(context, existing: a),
                            onDefault: a.isDefault
                                ? null
                                : () => ref
                                      .read(addressBookProvider.notifier)
                                      .setDefault(a.id),
                            onDelete: () => _delete(context, ref, a),
                          ),
                          Gap(Space.sm),
                        ],
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(Space.md.r),
          child: Row(
            children: [
              Icon(PhosphorIcons.plus(), color: primary, size: 20.sp),
              GapW(Space.sm),
              Expanded(
                child: Text(
                  'Add a new address',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                color: Colors.black38,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final a = address;
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: selected ? primary : Colors.black.withValues(alpha: 0.05),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md.w,
              Space.sm.h,
              Space.md.w,
              Space.xs.h,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Icon(
                    kindIcon(a.kind),
                    size: 20.sp,
                    color: selected ? primary : Colors.black54,
                  ),
                ),
                GapW(Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.label.isEmpty ? 'Address' : a.label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (a.isDefault) ...[
                            GapW(Space.xs),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Gap(2),
                      Text(
                        a.fullText,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      if (a.hasReceiver) ...[
                        Gap(Space.xxs),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.user(),
                              size: 13.sp,
                              color: Colors.black45,
                            ),
                            GapW(Space.xxs),
                            Flexible(
                              child: Text(
                                [
                                  a.receiverName,
                                  a.receiverPhone,
                                ].where((x) => x.isNotEmpty).join(' · '),
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      Gap(Space.xs),
                      // Inline, like Swiggy's address cards; a stock
                      // three-dot menu read as unfinished.
                      Row(
                        children: [
                          _Action('Edit', onEdit),
                          if (onDefault != null) ...[
                            _Dot(),
                            _Action('Make default', onDefault!),
                          ],
                          _Dot(),
                          _Action('Delete', onDelete, danger: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(top: Space.xl.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(Space.lg.r),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.mapPinArea(),
              size: 40.sp,
              color: primary,
            ),
          ),
          Gap(Space.md),
          Text(
            'No saved addresses yet',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap(Space.xxs),
          Text(
            'Save home, work and anywhere else you order to.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Action(this.label, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 2.w),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11.sp,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: Space.xs.w),
    child: Text(
      '·',
      style: TextStyle(color: Colors.black26, fontSize: 14.sp),
    ),
  );
}
