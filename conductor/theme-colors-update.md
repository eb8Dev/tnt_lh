# Theme Colors Update Plan

## Objective
Apply the new themes (`teasNTreesTheme` and `littleHTheme`) defined in `main.dart` across the entire application to replace hardcoded hex colors. This will ensure the app looks consistently "themic" and dynamically adapts its colors based on whether the user is interacting with the Cafe or Bakery section.

## Key Files & Context
- **Theme Source:** `lib/main.dart`
- **Global Utilities:** `lib/utils/snack_bar_utils.dart`, `lib/utils/loading_indicator.dart`
- **Screens:** `lib/screens/` (including Cart, Checkout, Orders, Wishlist, Store Selection, Cafe pages)
- **Onboarding:** `lib/onboarding/` (Login, Register, OTP Verify, Onboarding)

## Implementation Steps
1. **Global Default Theme:** Update the default `MaterialApp` theme in `main.dart` to use `teasNTreesTheme` (or a cohesive neutral theme) rather than the generic `Colors.green`.
2. **Search & Replace Hardcoded Colors:** 
   - Find all occurrences of the old pastel green `Color(0xFFA9BCA4)` and other static hex colors.
   - Replace them with `Theme.of(context).colorScheme.primary` or `.secondary` (or other appropriate `colorScheme` properties).
   - Use `Theme.of(context).colorScheme.surface` for backgrounds previously hardcoded as `Color(0xFFF7E9DE)`.
3. **Remove Invalid `const` Modifiers:** Since `Theme.of(context)` evaluates at runtime, strip any `const` keywords from widgets (like `Text`, `Icon`, `BoxDecoration`, `BorderSide`) that wrap the newly themed color variables.
4. **Handle Alpha & Opacity:** Where colors used `.withValues(alpha: ...)`, apply the same alpha modifier to the theme color variable.
5. **Static Analysis & Cleanup:** Run `dart analyze` to identify and fix any residual `invalid_assignment` or `non_constant_default_value` errors caused by removing `const`.

## Verification & Testing
1. **Dynamic Swapping:** Navigate between the Cafe section (Teas n Trees) and Bakery section (Little H) and verify that buttons, text, icons, and containers seamlessly swap to the correct primary/secondary brand colors.
2. **Global Screens:** Verify that shared screens like Cart, Checkout, and Orders pull the correct contextual theme.
3. **Compilation Check:** Run `dart format` and `dart analyze` to ensure the codebase remains clean and valid.
