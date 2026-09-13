import '../entities/group.dart';

abstract class GroupRepository {
  Future<List<Group>> getCoachGroups();
  Future<List<Group>> getClientGroups();
  Future<Group> createGroup({required String name});
  Future<Group> joinGroupByCode({required String inviteCode});
  Future<List<GroupMember>> getGroupMembers(String groupId);
}
