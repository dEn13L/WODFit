import '../../domain/entities/group.dart';
import 'user_profile_model.dart';

class GroupModel {
  final String id;
  final String coachId;
  final String name;
  final String inviteCode;
  final String createdAt;
  final int memberCount;

  const GroupModel({
    required this.id,
    required this.coachId,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['group_members'] != null && json['group_members'] is List) {
      count = (json['group_members'] as List).length;
    } else if (json['member_count'] != null) {
      count = (json['member_count'] as num).toInt();
    }

    return GroupModel(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      memberCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_id': coachId,
      'name': name,
      'invite_code': inviteCode,
      'created_at': createdAt,
    };
  }

  Group toDomain() {
    return Group(
      id: id,
      coachId: coachId,
      name: name,
      inviteCode: inviteCode,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      memberCount: memberCount,
    );
  }
}

class GroupMemberModel {
  final String groupId;
  final String userId;
  final String joinedAt;
  final UserProfileModel? profile;

  const GroupMemberModel({
    required this.groupId,
    required this.userId,
    required this.joinedAt,
    this.profile,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    UserProfileModel? profileModel;
    if (json['profiles'] != null && json['profiles'] is Map) {
      profileModel = UserProfileModel.fromJson(Map<String, dynamic>.from(json['profiles'] as Map));
    }

    return GroupMemberModel(
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: (json['joined_at'] as String?) ?? DateTime.now().toIso8601String(),
      profile: profileModel,
    );
  }

  GroupMember toDomain() {
    return GroupMember(
      groupId: groupId,
      userId: userId,
      joinedAt: DateTime.tryParse(joinedAt) ?? DateTime.now(),
      userProfile: profile?.toDomain(),
    );
  }
}
