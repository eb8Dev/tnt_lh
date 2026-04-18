# Smooth Store Transition Implementation Plan

## Objective
Implement a high-quality, game-like transition animation when switching between the two stores (Cafe and Bakery). The transition should replace the separate `StoreSelectionScreen` flow by allowing users to toggle directly within a unified home screen. 

## Key Files & Context
- **Global Theme Management:** `lib/main.dart`
- **State Management:** `lib/providers/brand_provider.dart`
- **New Unified Home:** `lib/screens/store_home.dart` (will replace `CafeHome` and `BakeryHome`)
- **Animation Overlay:** `lib/widgets/store_transition_overlay.dart` (new component)
- **Entry Logic:** `lib/main.dart` -> `AuthWrapper`

## Implementation Steps

### 1. Global Theme Management
- Update `MyApp` in `lib/main.dart` to be a `ConsumerWidget`.
- Listen to `brandProvider`.
- If the brand is `'teasntrees'`, use `teasNTreesTheme`. If `'littleh'`, use `littleHTheme`.

### 2. Create the Transition Overlay (`StoreTransitionOverlay`)
- Create a new file `lib/widgets/store_transition_overlay.dart`.
- Implement a `StatefulWidget` with an `AnimationController`.
- The animation sequence:
  1. A circular clipper (positioned over the center FAB) expands to fill the entire screen with the *target* store's primary color.
  2. The *target* store's logo scales and fades into the center of the screen.
  3. A callback triggers the `brandProvider` update, instantly switching the underlying app content and global theme.
  4. The overlay gracefully fades out, revealing the new store's content in the new theme.

### 3. Unified Home Screen (`StoreHomeScreen`)
- Create `lib/screens/store_home.dart`.
- Merge the common logic from `CafeHome` and `BakeryHome`.
- Use a `ConsumerStatefulWidget` to read the current brand.
- The `body` will use `BrandHomeContent(brand: currentBrand)`.
- The `BottomNavigationBar` and `FloatingActionButton` layout will remain static.
- When the FAB is pressed, instantiate and run the `StoreTransitionOverlay` to handle the switch.

### 4. Update Entry Logic & Cleanup
- In `lib/main.dart`'s `AuthWrapper`, remove the logic that directs to `StoreSelectionScreen` based on `_lastStore`.
- If `authState.isAuthenticated` is true, immediately return `StoreHomeScreen()`.
- (Optional) Ensure `brandProvider` initializes with a default brand if none is stored in `FlutterSecureStorage`.
- Remove references to `CafeHome`, `BakeryHome`, and `StoreSelectionScreen` where applicable (or mark them as deprecated/unused).

## Verification & Testing
1. **Initial Load:** The app should open directly into the `StoreHomeScreen` (defaulting to Cafe or the last visited store).
2. **Transition Animation:** Tapping the center FAB should trigger the smooth expansion, logo display, and underlying theme switch without any visual flashing or broken state.
3. **Data Integrity:** The Cart, Orders, and Profile tabs should maintain their state across the transition but reflect the updated theme and brand-specific data where applicable.