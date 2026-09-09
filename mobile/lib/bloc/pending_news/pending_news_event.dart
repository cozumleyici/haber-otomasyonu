import 'package:equatable/equatable.dart';

abstract class PendingNewsEvent extends Equatable {
  const PendingNewsEvent();

  @override
  List<Object?> get props => [];
}

class FetchPendingNews extends PendingNewsEvent {
  final bool isRefresh;

  const FetchPendingNews({this.isRefresh = false});

  @override
  List<Object?> get props => [isRefresh];
}

class RemoveDraftFromList extends PendingNewsEvent {
  final String draftId;

  const RemoveDraftFromList(this.draftId);

  @override
  List<Object?> get props => [draftId];
}

class DeleteAllPendingDrafts extends PendingNewsEvent {}

class DeleteSelectedDrafts extends PendingNewsEvent {
  final List<String> draftIds;

  const DeleteSelectedDrafts(this.draftIds);

  @override
  List<Object?> get props => [draftIds];
}
