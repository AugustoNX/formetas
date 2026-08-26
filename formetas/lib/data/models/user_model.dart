import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.createdAt,
    super.photoUrl,
    super.emailVerified,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['nome'] as String? ?? map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['foto'] as String? ?? map['photoUrl'] as String?,
      createdAt: _parseDate(map['dataCadastro'] ?? map['createdAt']),
      emailVerified: map['emailVerified'] as bool? ?? false,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      photoUrl: entity.photoUrl,
      createdAt: entity.createdAt,
      emailVerified: entity.emailVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': name,
      'email': email,
      'foto': photoUrl,
      'dataCadastro': createdAt.toIso8601String(),
      'emailVerified': emailVerified,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
