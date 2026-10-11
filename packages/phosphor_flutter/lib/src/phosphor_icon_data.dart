library phosphor_flutter;

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
