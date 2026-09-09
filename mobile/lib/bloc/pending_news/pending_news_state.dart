import 'package:equatable/equatable.dart';
import '../../models/news_draft.dart';

enum PendingNewsStatus { initial, loading, loaded, error }

class PendingNewsState extends Equatable {
  final PendingNewsStatus status;
  final List<NewsDraft> drafts;
  final String? errorMessage;
  final bool isRefreshing;

  const PendingNewsState({
    this.status = PendingNewsStatus.initial,
    this.drafts = const [],
    this.errorMessage,
    this.isRefreshing = false,
  });

  PendingNewsState copyWith({
    PendingNewsStatus? status,
    List<NewsDraft>? drafts,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return PendingNewsState(
      status: status ?? this.status,
      drafts: drafts ?? this.drafts,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [status, drafts, errorMessage, isRefreshing];
}
