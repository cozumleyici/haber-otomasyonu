import 'package:equatable/equatable.dart';

abstract class ReviewActionEvent extends Equatable {
  const ReviewActionEvent();

  @override
  List<Object?> get props => [];
}

class SubmitReviewDecision extends ReviewActionEvent {
  final String draftId;
  final String action; // 'approve' veya 'reject'
  final String originalTitle;
  final String originalContent;
  final String aiTitle;
  final String aiContent;
  final String finalTitle;
  final String finalContent;
  final String? imageUrl;
  final List<String> targetPlatforms;

  const SubmitReviewDecision({
    required this.draftId,
    required this.action,
    required this.originalTitle,
    required this.originalContent,
    required this.aiTitle,
    required this.aiContent,
    required this.finalTitle,
    required this.finalContent,
    this.imageUrl,
    required this.targetPlatforms,
  });

  @override
  List<Object?> get props => [
        draftId,
        action,
        originalTitle,
        originalContent,
        aiTitle,
        aiContent,
        finalTitle,
        finalContent,
        imageUrl,
        targetPlatforms,
      ];
}

class ResetReviewActionState extends ReviewActionEvent {}
