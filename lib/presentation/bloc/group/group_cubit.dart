import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/repositories/group_repository.dart';

abstract class GroupState extends Equatable {
  const GroupState();

  @override
  List<Object?> get props => [];
}

class GroupInitial extends GroupState {
  const GroupInitial();
}

class GroupLoading extends GroupState {
  const GroupLoading();
}

class GroupLoaded extends GroupState {
  final List<Group> groups;
  final String? successMessage;

  const GroupLoaded({
    required this.groups,
    this.successMessage,
  });

  @override
  List<Object?> get props => [groups, successMessage];
}

class GroupError extends GroupState {
  final String message;

  const GroupError(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupCubit extends Cubit<GroupState> {
  static const String _tag = 'GroupCubit';
  final GroupRepository groupRepository;

  GroupCubit({required this.groupRepository}) : super(const GroupInitial());

  Future<void> loadCoachGroups() async {
    emit(const GroupLoading());
    try {
      final groups = await groupRepository.getCoachGroups();
      emit(GroupLoaded(groups: groups));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadCoachGroups failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadClientGroups() async {
    emit(const GroupLoading());
    try {
      final groups = await groupRepository.getClientGroups();
      emit(GroupLoaded(groups: groups));
    } catch (e, st) {
      AppLogger.e(_tag, 'loadClientGroups failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createGroup(String name) async {
    try {
      final newGroup = await groupRepository.createGroup(name: name);
      final currentGroups = state is GroupLoaded ? (state as GroupLoaded).groups : <Group>[];
      emit(GroupLoaded(
        groups: [newGroup, ...currentGroups],
        successMessage: 'Группа "${newGroup.name}" создана. Код: ${newGroup.inviteCode}',
      ));
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'createGroup failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> updateGroupName(String groupId, String name) async {
    try {
      final updatedGroup = await groupRepository.updateGroupName(groupId: groupId, name: name);
      if (state is GroupLoaded) {
        final currentGroups = (state as GroupLoaded).groups;
        final updatedList = currentGroups.map((g) => g.id == groupId ? updatedGroup : g).toList();
        emit(GroupLoaded(
          groups: updatedList,
          successMessage: 'Название группы обновлено на "${updatedGroup.name}"',
        ));
      } else {
        await loadCoachGroups();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'updateGroupName failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await groupRepository.deleteGroup(groupId);
      if (state is GroupLoaded) {
        final currentGroups = (state as GroupLoaded).groups;
        emit(GroupLoaded(
          groups: currentGroups.where((g) => g.id != groupId).toList(),
          successMessage: 'Группа успешно удалена',
        ));
      } else {
        await loadCoachGroups();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'deleteGroup failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> joinGroup(String inviteCode) async {
    try {
      final group = await groupRepository.joinGroupByCode(inviteCode: inviteCode);
      if (state is GroupLoaded) {
        final currentGroups = (state as GroupLoaded).groups;
        final updated = [group, ...currentGroups.where((g) => g.id != group.id)];
        emit(GroupLoaded(
          groups: updated,
          successMessage: 'Вы успешно вступили в группу "${group.name}"',
        ));
      } else {
        emit(GroupLoaded(
          groups: [group],
          successMessage: 'Вы успешно вступили в группу "${group.name}"',
        ));
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'joinGroup failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      await groupRepository.leaveGroup(groupId);
      if (state is GroupLoaded) {
        final currentGroups = (state as GroupLoaded).groups;
        emit(GroupLoaded(
          groups: currentGroups.where((g) => g.id != groupId).toList(),
          successMessage: 'Вы вышли из группы',
        ));
      } else {
        await loadClientGroups();
      }
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'leaveGroup failed', e, st);
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      return await groupRepository.getGroupMembers(groupId);
    } catch (e, st) {
      AppLogger.e(_tag, 'getGroupMembers failed', e, st);
      rethrow;
    }
  }

  Future<bool> removeGroupMember(String groupId, String userId) async {
    try {
      await groupRepository.removeGroupMember(groupId: groupId, userId: userId);
      return true;
    } catch (e, st) {
      AppLogger.e(_tag, 'removeGroupMember failed', e, st);
      rethrow;
    }
  }
}
