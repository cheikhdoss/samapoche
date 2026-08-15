import 'package:json_annotation/json_annotation.dart';

part 'dto.g.dart';

@JsonSerializable()
class TokenDto {
  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'token_type')
  final String tokenType;

  const TokenDto({required this.accessToken, this.tokenType = 'bearer'});

  factory TokenDto.fromJson(Map<String, dynamic> json) =>
      _$TokenDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TokenDtoToJson(this);
}

@JsonSerializable()
class UserDto {
  final int id;
  final String email;

  @JsonKey(name: 'full_name')
  final String fullName;

  const UserDto({
    required this.id,
    required this.email,
    required this.fullName,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  Map<String, dynamic> toJson() => _$UserDtoToJson(this);
}

@JsonSerializable()
class CategoryDto {
  final int id;
  final String name;
  final String? icon;
  final String? color;

  const CategoryDto({
    required this.id,
    required this.name,
    this.icon,
    this.color,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryDtoToJson(this);
}

enum TransactionType {
  @JsonValue('income')
  income,
  @JsonValue('expense')
  expense,
}

@JsonSerializable()
class TransactionDto {
  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  final double amount;
  final TransactionType type;
  final String? description;

  @JsonKey(name: 'category_id')
  final int categoryId;

  @JsonKey(name: 'transaction_date')
  final DateTime transactionDate;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const TransactionDto({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.categoryId,
    required this.transactionDate,
    required this.createdAt,
  });

  factory TransactionDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionDtoFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionDtoToJson(this);
}

@JsonSerializable()
class BudgetStatusDto {
  final int id;

  @JsonKey(name: 'category_id')
  final int categoryId;

  @JsonKey(name: 'category_name')
  final String categoryName;

  final double amount;
  final double spent;
  final double percentage;

  @JsonKey(name: 'alert_80')
  final bool alert80;

  @JsonKey(name: 'alert_100')
  final bool alert100;

  final double remaining;

  const BudgetStatusDto({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.spent,
    required this.percentage,
    required this.alert80,
    required this.alert100,
    required this.remaining,
  });

  factory BudgetStatusDto.fromJson(Map<String, dynamic> json) =>
      _$BudgetStatusDtoFromJson(json);

  Map<String, dynamic> toJson() => _$BudgetStatusDtoToJson(this);
}

@JsonSerializable()
class BudgetResponseDto {
  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'category_id')
  final int categoryId;

  final double amount;
  final int month;
  final int year;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const BudgetResponseDto({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
    required this.createdAt,
  });

  factory BudgetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$BudgetResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$BudgetResponseDtoToJson(this);
}

@JsonSerializable()
class NotificationDto {
  final int id;
  final String title;
  final String message;
  final String icon;
  final bool read;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const NotificationDto({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.read,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationDtoFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationDtoToJson(this);
}

@JsonSerializable()
class ChatReplyDto {
  final String reply;

  @JsonKey(name: 'conversation_id')
  final String? conversationId;

  const ChatReplyDto({required this.reply, this.conversationId});

  factory ChatReplyDto.fromJson(Map<String, dynamic> json) =>
      _$ChatReplyDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ChatReplyDtoToJson(this);
}

@JsonSerializable()
class ErrorDetailDto {
  final String detail;

  const ErrorDetailDto({required this.detail});

  factory ErrorDetailDto.fromJson(Map<String, dynamic> json) =>
      _$ErrorDetailDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorDetailDtoToJson(this);
}
