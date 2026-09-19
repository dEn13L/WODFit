import 'package:equatable/equatable.dart';
import 'user_profile.dart';

enum ProgramKind {
  personal,
  group;

  String get displayName {
    switch (this) {
      case ProgramKind.personal:
        return 'Персональная';
      case ProgramKind.group:
        return 'Группа';
    }
  }

  static ProgramKind fromString(String? value) {
    if (value == null) return ProgramKind.group;
    switch (value.toLowerCase()) {
      case 'personal':
        return ProgramKind.personal;
      case 'group':
      default:
        return ProgramKind.group;
    }
  }
}

class TrainingProgram extends Equatable {
  final String id;
  final String coachId;
  final String name;
  final ProgramKind kind;
  final String description;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int memberCount;

  const TrainingProgram({
    required this.id,
    required this.coachId,
    required this.name,
    this.kind = ProgramKind.group,
    this.description = '',
    required this.inviteCode,
    required this.createdAt,
    this.updatedAt,
    this.memberCount = 0,
  });

  @override
  List<Object?> get props => [
        id,
        coachId,
        name,
        kind,
        description,
        inviteCode,
        createdAt,
        updatedAt,
        memberCount,
      ];

  TrainingProgram copyWith({
    String? id,
    String? coachId,
    String? name,
    ProgramKind? kind,
    String? description,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? memberCount,
  }) {
    return TrainingProgram(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class ProgramMember extends Equatable {
  final String programId;
  final String userId;
  final DateTime joinedAt;
  final UserProfile? userProfile;

  UserProfile? get profile => userProfile;

  const ProgramMember({
    required this.programId,
    required this.userId,
    required this.joinedAt,
    this.userProfile,
  });

  @override
  List<Object?> get props => [programId, userId, joinedAt, userProfile];
}
