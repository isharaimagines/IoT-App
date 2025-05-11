import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

@immutable
class ChatMessage extends Equatable {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  // For immutable updates
  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isError,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isError': isError,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isError: json['isError'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [role, content, timestamp, isError];

  // Helper for error messages
  factory ChatMessage.error(String message) => ChatMessage(
        role: 'system',
        content: message,
        isError: true,
      );
}
