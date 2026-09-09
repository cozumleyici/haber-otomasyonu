import 'dart:convert';
import 'package:equatable/equatable.dart';

class NewsDraft extends Equatable {
  final String id;
  final String sourceType;
  final String? sourceUrl;
  final String? originalTitle;
  final String? originalContent;
  final String? aiTitle;
  final String? aiContent;
  final String? imageUrl;
  final String status;
  final List<String> targetPlatforms;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NewsDraft({
    required this.id,
    required this.sourceType,
    this.sourceUrl,
    this.originalTitle,
    this.originalContent,
    this.aiTitle,
    this.aiContent,
    this.imageUrl,
    this.status = 'PENDING',
    this.targetPlatforms = const ['telegram', 'wordpress'],
    this.createdAt,
    this.updatedAt,
  });

  NewsDraft copyWith({
    String? id,
    String? sourceType,
    String? sourceUrl,
    String? originalTitle,
    String? originalContent,
    String? aiTitle,
    String? aiContent,
    String? imageUrl,
    String? status,
    List<String>? targetPlatforms,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NewsDraft(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      originalTitle: originalTitle ?? this.originalTitle,
      originalContent: originalContent ?? this.originalContent,
      aiTitle: aiTitle ?? this.aiTitle,
      aiContent: aiContent ?? this.aiContent,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      targetPlatforms: targetPlatforms ?? this.targetPlatforms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NewsDraft.fromJson(Map<String, dynamic> json) {
    List<String> platforms = [];
    if (json['target_platforms'] != null) {
      if (json['target_platforms'] is List) {
        platforms = (json['target_platforms'] as List)
            .map((e) => e.toString())
            .toList();
      } else if (json['target_platforms'] is String) {
        try {
          final decoded = jsonDecode(json['target_platforms']);
          if (decoded is List) {
            platforms = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          platforms = ['telegram', 'wordpress'];
        }
      }
    } else {
      platforms = ['telegram', 'wordpress'];
    }

    return NewsDraft(
      id: json['id'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? 'rss',
      sourceUrl: json['source_url'] as String?,
      originalTitle: json['original_title'] as String?,
      originalContent: json['original_content'] as String?,
      aiTitle: json['ai_title'] as String?,
      aiContent: json['ai_content'] as String?,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      targetPlatforms: platforms,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'source_url': sourceUrl,
      'original_title': originalTitle,
      'original_content': originalContent,
      'ai_title': aiTitle,
      'ai_content': aiContent,
      'image_url': imageUrl,
      'status': status,
      'target_platforms': targetPlatforms,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        sourceType,
        sourceUrl,
        originalTitle,
        originalContent,
        aiTitle,
        aiContent,
        imageUrl,
        status,
        targetPlatforms,
        createdAt,
        updatedAt,
      ];
}
