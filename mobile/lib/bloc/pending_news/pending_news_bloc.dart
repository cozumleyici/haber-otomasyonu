import 'package:flutter_bloc/flutter_bloc.dart';
import 'pending_news_event.dart';
import 'pending_news_state.dart';
import '../../repositories/news_repository.dart';

class PendingNewsBloc extends Bloc<PendingNewsEvent, PendingNewsState> {
  final NewsRepository repository;

  PendingNewsBloc({required this.repository}) : super(const PendingNewsState()) {
    on<FetchPendingNews>(_onFetchPendingNews);
    on<RemoveDraftFromList>(_onRemoveDraftFromList);
    on<DeleteAllPendingDrafts>(_onDeleteAllPendingDrafts);
    on<DeleteSelectedDrafts>(_onDeleteSelectedDrafts);
  }

  Future<void> _onFetchPendingNews(
    FetchPendingNews event,
    Emitter<PendingNewsState> emit,
  ) async {
    if (event.isRefresh) {
      emit(state.copyWith(isRefreshing: true));
    } else {
      emit(state.copyWith(status: PendingNewsStatus.loading));
    }

    try {
      final drafts = await repository.fetchPendingNews();
      emit(state.copyWith(
        status: PendingNewsStatus.loaded,
        drafts: drafts,
        isRefreshing: false,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PendingNewsStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        isRefreshing: false,
      ));
    }
  }

  void _onRemoveDraftFromList(
    RemoveDraftFromList event,
    Emitter<PendingNewsState> emit,
  ) {
    final updatedList = state.drafts.where((d) => d.id != event.draftId).toList();
    emit(state.copyWith(drafts: updatedList));
  }

  Future<void> _onDeleteAllPendingDrafts(
    DeleteAllPendingDrafts event,
    Emitter<PendingNewsState> emit,
  ) async {
    await repository.deleteAllPendingDrafts();
    emit(state.copyWith(drafts: []));
  }

  Future<void> _onDeleteSelectedDrafts(
    DeleteSelectedDrafts event,
    Emitter<PendingNewsState> emit,
  ) async {
    await repository.deleteSelectedDrafts(event.draftIds);
    final remaining = state.drafts.where((d) => !event.draftIds.contains(d.id)).toList();
    emit(state.copyWith(drafts: remaining));
  }
}
