import 'package:flutter/material.dart';
import 'package:samapoche/models/dto.dart';
import 'package:samapoche/theme.dart';

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

  static const List<Category> all = [
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

  static const List<Category> expenses = [
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

  factory Txn.fromDto(TransactionDto dto, Map<int, String> categoryNames) {
    final desc = dto.description ?? '';
    final catName = categoryNames[dto.categoryId] ?? 'Autres';
    return Txn(
      id: dto.id.toString(),
      name: desc.isNotEmpty ? desc : catName,
      category: catName,
      type: dto.type == TransactionType.income
          ? TxnType.income
          : TxnType.expense,
      amount: dto.amount.round(),
      description: desc,
      payment: '',
      date: dto.transactionDate.toLocal(),
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

  factory UserProfile.fromDto(UserDto dto) {
    final parts = dto.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return UserProfile(
      id: dto.id,
      firstName: parts.isNotEmpty ? parts.first : 'Utilisateur',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      email: dto.email,
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
  final bool read;

  const AppNotification({
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

  factory AppNotification.fromDto(
    NotificationDto dto, {
    required String time,
    required String group,
  }) {
    final (bg, fg, icon) = _iconStyle(dto.icon);
    return AppNotification(
      id: dto.id,
      title: dto.title,
      desc: dto.message,
      time: time,
      group: group,
      bg: bg,
      fg: fg,
      icon: icon,
      read: dto.read,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    desc: desc,
    time: time,
    group: group,
    bg: bg,
    fg: fg,
    icon: icon,
    read: read ?? this.read,
  );

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
