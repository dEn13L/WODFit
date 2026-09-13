import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final GroupRepository groupRepository;

  GroupCubit({required this.groupRepository}) : super(const GroupInitial());

  Future<void> loadCoachGroups() async {
    emit(const GroupLoading());
    try {
      final groups = await groupRepository.getCoachGroups();
      emit(GroupLoaded(groups: groups));
    } catch (e) {
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> loadClientGroups() async {
    emit(const GroupLoading());
    try {
      final groups = await groupRepository.getClientGroups();
      emit(GroupLoaded(groups: groups));
    } catch (e) {
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createGroup(String name) async {
    try {
      final newGroup = await groupRepository.createGroup(name: name);
      if (state is GroupLoaded) {
        final currentGroups = (state as GroupLoaded).groups;
        emit(GroupLoaded(
          groups: [newGroup, ...currentGroups],
          successMessage: 'Группа "${newGroup.name}" успешно создана. Код: ${newGroup.inviteCode}',
        ));
      } else {
        emit(GroupLoaded(
          groups: [newGroup],
          successMessage: 'Группа "${newGroup.name}" успешно создана. Код: ${newGroup.inviteCode}',
        ));
      }
      return true;
    } catch (e) {
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
    } catch (e) {
      emit(GroupError(e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }
}
