import '../../domain/entities/training_program.dart';
import 'user_profile_model.dart';

class TrainingProgramModel {
  final String id;
  final String coachId;
  final String name;
  final String kind;
  final String description;
  final String inviteCode;
  final String createdAt;
  final String? updatedAt;
  final int memberCount;

  const TrainingProgramModel({
    required this.id,
    required this.coachId,
    required this.name,
    this.kind = 'group',
    this.description = '',
    required this.inviteCode,
    required this.createdAt,
    this.updatedAt,
    this.memberCount = 0,
  });

  factory TrainingProgramModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['program_members'] != null && json['program_members'] is List) {
      count = (json['program_members'] as List).length;
    } else if (json['group_members'] != null && json['group_members'] is List) {
      count = (json['group_members'] as List).length;
    } else if (json['member_count'] != null) {
      count = (json['member_count'] as num).toInt();
    }

    return TrainingProgramModel(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      name: json['name'] as String,
      kind: (json['kind'] as String?) ?? 'group',
      description: (json['description'] as String?) ?? '',
      inviteCode: json['invite_code'] as String,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String?,
      memberCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_id': coachId,
      'name': name,
      'kind': kind,
      'description': description,
      'invite_code': inviteCode,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  TrainingProgram toDomain() {
    return TrainingProgram(
      id: id,
      coachId: coachId,
      name: name,
      kind: ProgramKind.fromString(kind),
      description: description,
      inviteCode: inviteCode,
      createdAt: (DateTime.tryParse(createdAt) ?? DateTime.now()).toLocal(),
      updatedAt: updatedAt != null ? (DateTime.tryParse(updatedAt!) ?? DateTime.now()).toLocal() : null,
      memberCount: memberCount,
    );
  }
}

class ProgramMemberModel {
  final String programId;
  final String userId;
  final String joinedAt;
  final UserProfileModel? profile;

  const ProgramMemberModel({
    required this.programId,
    required this.userId,
    required this.joinedAt,
    this.profile,
  });

  factory ProgramMemberModel.fromJson(Map<String, dynamic> json) {
    UserProfileModel? profileModel;
    if (json['profiles'] != null && json['profiles'] is Map) {
      profileModel = UserProfileModel.fromJson(Map<String, dynamic>.from(json['profiles'] as Map));
    }

    final progId = (json['program_id'] ?? json['group_id']) as String;

    return ProgramMemberModel(
      programId: progId,
      userId: json['user_id'] as String,
      joinedAt: (json['joined_at'] as String?) ?? DateTime.now().toIso8601String(),
      profile: profileModel,
    );
  }

  ProgramMember toDomain() {
    return ProgramMember(
      programId: programId,
      userId: userId,
      joinedAt: (DateTime.tryParse(joinedAt) ?? DateTime.now()).toLocal(),
      userProfile: profile?.toDomain(),
    );
  }
}
