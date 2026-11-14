import 'package:flutter/material.dart';

enum PromoKind { banner, strip, offer, popup }

enum PromoAction { none, category, product, coupon, url }

/// A banner, announcement, offer card or pop-up set up in the admin panel.
class Promotion {
  final String id;
  final PromoKind kind;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color? color;
  final PromoAction action;
  final String actionValue;
  final String ctaLabel;

  const Promotion({
    required this.id,
    required this.kind,
    this.title = '',
    this.subtitle = '',
    this.imageUrl = '',
    this.color,
    this.action = PromoAction.none,
    this.actionValue = '',
    this.ctaLabel = '',
  });

  static Color? _parseColor(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
    id: (j['_id'] ?? j['id']).toString(),
    kind: _enum(PromoKind.values, j['kind'], PromoKind.banner),
    title: (j['title'] ?? '').toString(),
    subtitle: (j['subtitle'] ?? '').toString(),
    imageUrl: (j['imageUrl'] ?? '').toString(),
    color: _parseColor(j['color']?.toString()),
    action: _enum(PromoAction.values, j['action']?['type'], PromoAction.none),
    actionValue: (j['action']?['value'] ?? '').toString(),
    ctaLabel: (j['ctaLabel'] ?? '').toString(),
  );
}
