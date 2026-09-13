import '../entities/group.dart';

abstract class GroupRepository {
  Future<List<Group>> getCoachGroups();
  Future<List<Group>> getClientGroups();
  Future<Group> createGroup({required String name});
  Future<Group> updateGroupName({required String groupId, required String name});
  Future<void> deleteGroup(String groupId);
  Future<Group> joinGroupByCode({required String inviteCode});
  Future<void> leaveGroup(String groupId);
  Future<List<GroupMember>> getGroupMembers(String groupId);
  Future<void> removeGroupMember({required String groupId, required String userId});
}
