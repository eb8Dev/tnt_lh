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
  final bool push;
  final bool offers;

  NotificationPreferences({
    this.email = true,
    this.sms = true,
    this.push = true,
    this.offers = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      email: json['email'] ?? true,
      sms: json['sms'] ?? true,
      push: json['push'] ?? true,
      offers: json['offers'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'sms': sms,
      'push': push,
      'offers': offers,
    };
  }

  NotificationPreferences copyWith({
    bool? email,
    bool? sms,
    bool? push,
    bool? offers,
  }) {
    return NotificationPreferences(
      email: email ?? this.email,
      sms: sms ?? this.sms,
      push: push ?? this.push,
      offers: offers ?? this.offers,
    );
  }
}
