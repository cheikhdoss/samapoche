import 'package:flutter/material.dart';
import '../theme.dart';

enum TxnType { expense, income }

class Category {
  final String name;
  final String emoji;
  final Color bg;
  final Color fg;
  final IconData icon;

  const Category(this.name, this.emoji, this.bg, this.fg, this.icon);
}

class Categories {
  static const alimentation = Category(
    'Alimentation',
    '🛒',
    Color(0xFFFEF3C7),
    Color(0xFFD97706),
    Icons.restaurant,
  );
  static const transport = Category(
    'Transport',
    '🚗',
    Color(0xFFDBEAFE),
    Color(0xFF2563EB),
    Icons.directions_car,
  );
  static const logement = Category(
    'Logement',
    '🏠',
    Color(0xFFFEE2E2),
    Color(0xFFDC2626),
    Icons.home_rounded,
  );
  static const loisirs = Category(
    'Loisirs',
    '🎮',
    Color(0xFFEDE9FE),
    Color(0xFF7C3AED),
    Icons.sports_esports,
  );
  static const sante = Category(
    'Santé',
    '❤️',
    Color(0xFFDCFCE7),
    Color(0xFF16A34A),
    Icons.local_hospital_rounded,
  );
  static const education = Category(
    'Éducation',
    '🎓',
    Color(0xFFFCE7F3),
    Color(0xFFDB2777),
    Icons.school_rounded,
  );
  static const shopping = Category(
    'Shopping',
    '🛍️',
    Color(0xFFFEF3C7),
    Color(0xFFDB2777),
    Icons.shopping_cart,
  );
  static const salaire = Category(
    'Salaire',
    '💰',
    Color(0xFFDBEAFE),
    Color(0xFF16A34A),
    Icons.work_rounded,
  );
  static const autres = Category(
    'Autres',
    '📦',
    Color(0xFFF3F4F6),
    Color(0xFF6B7280),
    Icons.more_horiz_rounded,
  );

  static const all = [
    alimentation,
    transport,
    logement,
    loisirs,
    sante,
    education,
    shopping,
    salaire,
    autres,
  ];

  static Category byName(String name) =>
      all.firstWhere((c) => c.name == name, orElse: () => autres);

  static const expenses = [
    alimentation,
    transport,
    logement,
    loisirs,
    sante,
    education,
    shopping,
    autres,
  ];
}

class Txn {
  final String id;
  final String name;
  final String category;
  final TxnType type;
  final int amount; // F CFA, toujours positif
  final String description;
  final String payment;
  final DateTime date;

  const Txn({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.amount,
    required this.description,
    required this.payment,
    required this.date,
  });

  int get signed => type == TxnType.expense ? -amount : amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'type': type.name,
    'amount': amount,
    'description': description,
    'payment': payment,
    'date': date.toIso8601String(),
  };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    id: j['id'].toString(),
    name: j['name'] as String,
    category: j['category'] as String,
    type: TxnType.values.firstWhere((t) => t.name == j['type']),
    amount: (j['amount'] as num).toInt(),
    description: (j['description'] ?? '') as String,
    payment: (j['payment'] ?? '') as String,
    date: DateTime.parse(j['date'] as String).toLocal(),
  );

  factory Txn.fromServer(
    Map<String, dynamic> j, {
    required Map<int, String> categoryNames,
  }) {
    final desc = (j['description'] ?? '') as String;
    final catId = (j['category_id'] as num).toInt();
    final catName = categoryNames[catId] ?? 'Autres';
    return Txn(
      id: j['id'].toString(),
      name: desc.isNotEmpty ? desc : catName,
      category: catName,
      type: j['type'] == 'income' ? TxnType.income : TxnType.expense,
      amount: (j['amount'] as num).round(),
      description: desc,
      payment: '',
      date: DateTime.parse(j['transaction_date'] as String).toLocal(),
    );
  }
}

class UserProfile {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  const UserProfile({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials =>
      (firstName.isNotEmpty ? firstName.characters.first : '?') +
      (lastName.isNotEmpty ? lastName.characters.first : '').toUpperCase();

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as int?,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    email: j['email'] as String,
    phone: (j['phone'] ?? '') as String,
  );

  factory UserProfile.fromServer(Map<String, dynamic> j) {
    final full = (j['full_name'] ?? '') as String;
    final parts = full
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return UserProfile(
      id: j['id'] as int?,
      firstName: parts.isNotEmpty ? parts.first : 'Utilisateur',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      email: j['email'] as String,
    );
  }
}

class AppNotification {
  final int? id;
  final String title;
  final String desc;
  final String time;
  final String group;
  final Color bg;
  final Color fg;
  final IconData icon;
  bool read;

  AppNotification({
    this.id,
    required this.title,
    required this.desc,
    required this.time,
    required this.group,
    required this.bg,
    required this.fg,
    required this.icon,
    this.read = false,
  });

  factory AppNotification.fromServer(
    Map<String, dynamic> j, {
    required String time,
    required String group,
  }) {
    final iconName = (j['icon'] ?? 'notifications') as String;
    final (bg, fg, icon) = _iconStyle(iconName);
    return AppNotification(
      id: j['id'] as int?,
      title: j['title'] as String,
      desc: j['message'] as String,
      time: time,
      group: group,
      bg: bg,
      fg: fg,
      icon: icon,
      read: j['read'] as bool? ?? false,
    );
  }

  static (Color, Color, IconData) _iconStyle(String name) {
    switch (name) {
      case 'warning':
      case 'warning_amber':
        return (
          AppColors.warnSoft,
          const Color(0xFFD97706),
          Icons.warning_amber_rounded,
        );
      case 'trending_up':
      case 'insight':
        return (
          AppColors.accentSoft,
          AppColors.accent,
          Icons.trending_up_rounded,
        );
      case 'event':
      case 'reminder':
        return (
          AppColors.infoSoft,
          const Color(0xFF2563EB),
          Icons.event_rounded,
        );
      case 'error':
      case 'money_off':
        return (
          AppColors.dangerSoft,
          AppColors.danger,
          Icons.error_outline_rounded,
        );
      case 'auto_awesome':
      case 'ai':
        return (
          AppColors.accentSoft,
          AppColors.accent,
          Icons.auto_awesome_rounded,
        );
      default:
        return (
          AppColors.surface,
          AppColors.fg2,
          Icons.notifications_none_rounded,
        );
    }
  }
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({required this.text, required this.fromUser, required this.time});
}
