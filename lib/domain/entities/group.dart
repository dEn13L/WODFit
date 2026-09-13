import 'package:equatable/equatable.dart';
import 'user_profile.dart';

class Group extends Equatable {
  final String id;
  final String coachId;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
  final int memberCount;

  const Group({
    required this.id,
    required this.coachId,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.memberCount = 0,
  });

  @override
  List<Object?> get props => [id, coachId, name, inviteCode, createdAt, memberCount];

  Group copyWith({
    String? id,
    String? coachId,
    String? name,
    String? inviteCode,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return Group(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class GroupMember extends Equatable {
  final String groupId;
  final String userId;
  final DateTime joinedAt;
  final UserProfile? userProfile;

  UserProfile? get profile => userProfile;

  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.joinedAt,
    this.userProfile,
  });

  @override
  List<Object?> get props => [groupId, userId, joinedAt, userProfile];
}
