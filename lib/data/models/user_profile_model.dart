import '../../domain/entities/user_profile.dart';

class UserProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String createdAt;

  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? 'Спортсмен',
      role: (json['role'] as String?) ?? 'client',
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt,
    };
  }

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName,
      role: UserRole.fromString(role),
      createdAt: (DateTime.tryParse(createdAt) ?? DateTime.now()).toLocal(),
    );
  }

  factory UserProfileModel.fromDomain(UserProfile entity) {
    return UserProfileModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      role: entity.role.name,
      createdAt: entity.createdAt.toUtc().toIso8601String(),
    );
  }
}
