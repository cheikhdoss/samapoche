// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenDto _$TokenDtoFromJson(Map<String, dynamic> json) => TokenDto(
  accessToken: json['access_token'] as String,
  tokenType: json['token_type'] as String? ?? 'bearer',
);

Map<String, dynamic> _$TokenDtoToJson(TokenDto instance) => <String, dynamic>{
  'access_token': instance.accessToken,
  'token_type': instance.tokenType,
};

UserDto _$UserDtoFromJson(Map<String, dynamic> json) => UserDto(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  fullName: json['full_name'] as String,
);

Map<String, dynamic> _$UserDtoToJson(UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'full_name': instance.fullName,
};

CategoryDto _$CategoryDtoFromJson(Map<String, dynamic> json) => CategoryDto(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  icon: json['icon'] as String?,
  color: json['color'] as String?,
);

Map<String, dynamic> _$CategoryDtoToJson(CategoryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'color': instance.color,
    };

TransactionDto _$TransactionDtoFromJson(Map<String, dynamic> json) =>
    TransactionDto(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      description: json['description'] as String?,
      categoryId: (json['category_id'] as num).toInt(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TransactionDtoToJson(TransactionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'amount': instance.amount,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'description': instance.description,
      'category_id': instance.categoryId,
      'transaction_date': instance.transactionDate.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$TransactionTypeEnumMap = {
  TransactionType.income: 'income',
  TransactionType.expense: 'expense',
};

BudgetStatusDto _$BudgetStatusDtoFromJson(Map<String, dynamic> json) =>
    BudgetStatusDto(
      id: (json['id'] as num).toInt(),
      categoryId: (json['category_id'] as num).toInt(),
      categoryName: json['category_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      alert80: json['alert_80'] as bool,
      alert100: json['alert_100'] as bool,
      remaining: (json['remaining'] as num).toDouble(),
    );

Map<String, dynamic> _$BudgetStatusDtoToJson(BudgetStatusDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'amount': instance.amount,
      'spent': instance.spent,
      'percentage': instance.percentage,
      'alert_80': instance.alert80,
      'alert_100': instance.alert100,
      'remaining': instance.remaining,
    };

BudgetResponseDto _$BudgetResponseDtoFromJson(Map<String, dynamic> json) =>
    BudgetResponseDto(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      categoryId: (json['category_id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$BudgetResponseDtoToJson(BudgetResponseDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'category_id': instance.categoryId,
      'amount': instance.amount,
      'month': instance.month,
      'year': instance.year,
      'created_at': instance.createdAt.toIso8601String(),
    };

NotificationDto _$NotificationDtoFromJson(Map<String, dynamic> json) =>
    NotificationDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      message: json['message'] as String,
      icon: json['icon'] as String,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$NotificationDtoToJson(NotificationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'message': instance.message,
      'icon': instance.icon,
      'read': instance.read,
      'created_at': instance.createdAt.toIso8601String(),
    };

ChatReplyDto _$ChatReplyDtoFromJson(Map<String, dynamic> json) => ChatReplyDto(
  reply: json['reply'] as String,
  conversationId: json['conversation_id'] as String?,
);

Map<String, dynamic> _$ChatReplyDtoToJson(ChatReplyDto instance) =>
    <String, dynamic>{
      'reply': instance.reply,
      'conversation_id': instance.conversationId,
    };

ErrorDetailDto _$ErrorDetailDtoFromJson(Map<String, dynamic> json) =>
    ErrorDetailDto(detail: json['detail'] as String);

Map<String, dynamic> _$ErrorDetailDtoToJson(ErrorDetailDto instance) =>
    <String, dynamic>{'detail': instance.detail};
