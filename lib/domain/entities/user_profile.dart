import 'package:equatable/equatable.dart';

enum UserRole {
  coach,
  client;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.client,
    );
  }

  String get displayName => this == UserRole.coach ? 'Тренер' : 'Клиент (Атлет)';
}

class UserProfile extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  bool get isCoach => role == UserRole.coach;
  bool get isClient => role == UserRole.client;

  @override
  List<Object?> get props => [id, email, fullName, role, createdAt];
}
