import 'package:equatable/equatable.dart';

enum ReviewActionStatus { initial, submitting, success, failure }

class ReviewActionState extends Equatable {
  final ReviewActionStatus status;
  final String? message;
  final String? draftId;
  final String? action; // 'approve' or 'reject'

  const ReviewActionState({
    this.status = ReviewActionStatus.initial,
    this.message,
    this.draftId,
    this.action,
  });

  ReviewActionState copyWith({
    ReviewActionStatus? status,
    String? message,
    String? draftId,
    String? action,
  }) {
    return ReviewActionState(
      status: status ?? this.status,
      message: message,
      draftId: draftId ?? this.draftId,
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => [status, message, draftId, action];
}
