import 'package:tnt_lh/utils/formatters.dart';

class User {
  final String id;
  final String? name;
  final String mobile;
  final String? email;
  final String? address;
  final String? profileImage;
  final bool isProfileComplete;
  final String? role;
  final String? activeBrand;
  final NotificationPreferences? notificationPreferences;

  User({
    required this.id,
    this.name,
    required this.mobile,
    this.email,
    this.address,
    this.profileImage,
    this.isProfileComplete = false,
    this.role,
    this.activeBrand,
    this.notificationPreferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final id = AppFormatters.parseId(json['_id'] ?? json['id']);

    // Handle nested preferences for activeBrand
    String? activeBrand = json['activeBrand'];
    if (activeBrand == null && json['preferences'] != null) {
      activeBrand = json['preferences']['activeBrand'];
    }

    return User(
      id: id,
      name: json['name'],
      mobile: json['mobile'] ?? '',
      email: json['email'],
      address: json['address'],
      profileImage: json['profileImage'],
      isProfileComplete: json['isProfileComplete'] ?? false,
      role: json['role'],
      activeBrand: activeBrand,
      notificationPreferences: json['notificationPreferences'] != null
          ? NotificationPreferences.fromJson(json['notificationPreferences'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'email': email,
      'address': address,
      'profileImage': profileImage,
      'isProfileComplete': isProfileComplete,
      'role': role,
      'activeBrand': activeBrand,
      'notificationPreferences': notificationPreferences?.toJson(),
    };
  }
}

class NotificationPreferences {
  final bool email;
  final bool sms;

  /// Every reminder and offer (order updates always come through).
  final bool push;
  final bool offers;
  final bool cartReminders;
  final bool recommendations;
  final bool comeback;

  NotificationPreferences({
    this.email = true,
    this.sms = true,
    this.push = true,
    this.offers = true,
    this.cartReminders = true,
    this.recommendations = true,
    this.comeback = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      email: json['email'] ?? true,
      sms: json['sms'] ?? true,
      push: json['push'] ?? true,
      offers: json['offers'] ?? true,
      cartReminders: json['cartReminders'] ?? true,
      recommendations: json['recommendations'] ?? true,
      comeback: json['comeback'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'sms': sms,
    'push': push,
    'offers': offers,
    'cartReminders': cartReminders,
    'recommendations': recommendations,
    'comeback': comeback,
  };
}
