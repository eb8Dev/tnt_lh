# phosphor_flutter (vendored, patched)

A copy of [phosphor_flutter 2.1.0](https://pub.dev/packages/phosphor_flutter),
the last published release (May 2024), patched to compile on Flutter 3.47+.

Upstream declares `class PhosphorIconData extends IconData`. Flutter 3.47 made
`IconData` a final class, so that no longer compiles and the app could not be
built at all.

What changed here:

- `PhosphorIconData`, `PhosphorFlatIconData` and `PhosphorDuotoneIconData` are
  now type aliases of `IconData`; every icon is a plain const `IconData`.
- A duotone icon used to carry its second layer as a field. That layer now
  comes from `phosphorDuotoneSecondary` (`lib/src/phosphor_duotone_secondary.dart`),
  keyed by the primary glyph's code point. `PhosphorIcon` looks it up.

The public API (`PhosphorIcons.x(style)`, `PhosphorIconsRegular.x`,
`PhosphorIcon`) is unchanged. Regenerate with `python3 tool/vendor_phosphor.py packages/phosphor_flutter`; delete this folder and go back to the pub.dev
package if upstream ever ships a fix.
