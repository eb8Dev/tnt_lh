"""Builds a patched copy of phosphor_flutter 2.1.0 that compiles on Flutter 3.47+,
where IconData is a final class and can no longer be subclassed."""
import os, re, shutil, sys
src = os.path.expanduser('~/.pub-cache/hosted/pub.dev/phosphor_flutter-2.1.0')
dst = sys.argv[1]
if os.path.exists(dst): shutil.rmtree(dst)
os.makedirs(dst)
shutil.copytree(f'{src}/lib', f'{dst}/lib')
for f in ('LICENSE',):
    if os.path.exists(f'{src}/{f}'): shutil.copy(f'{src}/{f}', dst)

pub = open(f'{src}/pubspec.yaml').read()
pub = re.sub(r'screenshots:\n(?:  .*\n)+\n', '\n', pub)
pub = pub.replace('version: 2.1.0', 'version: 2.1.0+flutter347')
# Non-function type aliases need Dart 2.13+; upstream still declared 2.12.
pub = pub.replace('sdk: ">=2.12.0 <4.0.0"', 'sdk: ">=3.0.0 <4.0.0"')
assert 'sdk: ">=3.0.0 <4.0.0"' in pub
open(f'{dst}/pubspec.yaml', 'w').write(pub)

open(f'{dst}/README.md', 'w').write('''# phosphor_flutter (vendored, patched)

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
''')

def icon(code, style):
    return (f"IconData({code}, fontFamily: 'Phosphor{style}', "
            f"fontPackage: 'phosphor_flutter', matchTextDirection: true)")

open(f'{dst}/lib/src/phosphor_icon_data.dart', 'w').write('''library phosphor_flutter;

import 'package:flutter/widgets.dart';

// Upstream subclassed IconData. Flutter 3.47 made IconData final, so these are
// now plain aliases and every icon is an ordinary const IconData. The names are
// kept so existing code that mentions them still compiles.
typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;
typedef PhosphorDuotoneIconData = IconData;

/// Font family of the duotone set; how [PhosphorIcon] recognises a duotone icon
/// now that it can't be a distinct type.
const String phosphorDuotoneFamily = 'PhosphorDuotone';
''')

for style in ('Regular', 'Thin', 'Light', 'Bold', 'Fill'):
    p = f'{dst}/lib/src/phosphor_icons_{style.lower()}.dart'
    s = open(p).read()
    s, n = re.subn(r"PhosphorFlatIconData\((0x[0-9a-f]+), '(\w+)'\)", lambda m: icon(m.group(1), m.group(2)), s)
    assert 'PhosphorFlatIconData(' not in s and n > 1000, (style, n)
    open(p, 'w').write(s)

p = f'{dst}/lib/src/phosphor_icons_duotone.dart'
s = open(p).read()
pairs = []
def duo(m):
    pairs.append((m.group(1), m.group(2)))
    return icon(m.group(1), 'Duotone')
s, n = re.subn(r"PhosphorDuotoneIconData\(\s*(0x[0-9a-f]+),\s*PhosphorIconData\((0x[0-9a-f]+), 'Duotone'\),?\s*\)", duo, s)
assert 'PhosphorDuotoneIconData(' not in s and n > 1000, n
# Two duotone icons (cell-signal-none, wifi-none) have no second layer and are
# declared flat in the duotone file.
s = re.sub(r"PhosphorFlatIconData\((0x[0-9a-f]+), '(\w+)'\)", lambda m: icon(m.group(1), m.group(2)), s)
assert 'IconData(' in s and 'PhosphorFlatIconData(' not in s and 'PhosphorIconData(' not in s
open(p, 'w').write(s)
assert len({a for a, _ in pairs}) == len(pairs), 'duplicate primary code points'

body = ''.join(f"  {a}: {icon(b, 'Duotone')},\n" for a, b in pairs)
open(f'{dst}/lib/src/phosphor_duotone_secondary.dart', 'w').write(
    "// Generated alongside the patched icon files. DON'T EDIT BY HAND\n\n"
    "import 'package:flutter/widgets.dart';\n\n"
    "/// The second (tinted) layer of each duotone icon, keyed by the code point of\n"
    "/// its primary glyph. Const so the icon-font tree shaker can still see them.\n"
    "const Map<int, IconData> phosphorDuotoneSecondary = {\n" + body + "};\n")

p = f'{dst}/lib/src/phosphor_icon.dart'
s = open(p).read()
a = '''    if (icon is PhosphorDuotoneIconData) {
      final duotoneIcon = icon as PhosphorDuotoneIconData;
      return Stack('''
b = '''    final secondary = icon?.fontFamily == phosphorDuotoneFamily
        ? phosphorDuotoneSecondary[icon!.codePoint]
        : null;
    if (secondary != null) {
      return Stack('''
assert a in s; s = s.replace(a, b)
assert 'duotoneIcon.secondary,' in s; s = s.replace('duotoneIcon.secondary,', 'secondary,')
s = s.replace("import 'package:phosphor_flutter/phosphor_flutter.dart';", "import 'package:phosphor_flutter/phosphor_flutter.dart';\nimport 'package:phosphor_flutter/src/phosphor_duotone_secondary.dart';")
open(p, 'w').write(s)
print('ok', dst, 'duotone pairs', len(pairs))
