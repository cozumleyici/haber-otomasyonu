import 'package:flutter_bloc/flutter_bloc.dart';
import 'review_action_event.dart';
import 'review_action_state.dart';
import '../../repositories/news_repository.dart';

class ReviewActionBloc extends Bloc<ReviewActionEvent, ReviewActionState> {
  final NewsRepository repository;

  ReviewActionBloc({required this.repository}) : super(const ReviewActionState()) {
    on<SubmitReviewDecision>(_onSubmitReviewDecision);
    on<ResetReviewActionState>(_onResetReviewActionState);
  }

  Future<void> _onSubmitReviewDecision(
    SubmitReviewDecision event,
    Emitter<ReviewActionState> emit,
  ) async {
    emit(state.copyWith(
      status: ReviewActionStatus.submitting,
      draftId: event.draftId,
      action: event.action,
      message: null,
    ));

    try {
      final response = await repository.submitDecision(
        draftId: event.draftId,
        action: event.action,
        originalTitle: event.originalTitle,
        originalContent: event.originalContent,
        aiTitle: event.aiTitle,
        aiContent: event.aiContent,
        finalTitle: event.finalTitle,
        finalContent: event.finalContent,
        imageUrl: event.imageUrl,
        targetPlatforms: event.targetPlatforms,
      );

      final msg = response['message']?.toString() ??
          (event.action == 'approve' ? 'Yayınlandı!' : 'Taslak reddedildi.');

      emit(state.copyWith(
        status: ReviewActionStatus.success,
        message: msg,
        draftId: event.draftId,
        action: event.action,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ReviewActionStatus.failure,
        message: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onResetReviewActionState(
    ResetReviewActionState event,
    Emitter<ReviewActionState> emit,
  ) {
    emit(const ReviewActionState());
  }
}
