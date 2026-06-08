import 'package:flutter/foundation.dart';

/// Priority level model for site-specific priority configuration
///
/// Each site has its own set of priorities (defined by owner).
/// Snags store the priority code (e.g., "CAT1") as a reference.
/// Collaborators see the owner's priority descriptions.
///
/// Constraints:
/// - Code: max 4 characters (e.g., "OK", "CAT1")
/// - Description: max 300 characters
/// - Order is fixed (index in list determines display order)
/// SYNC: These constraints must match Firebase rules in firestore.rules
@immutable
class PriorityLevel {
  /// Short code for the priority (max 4 chars)
  /// Examples: "OK", "OBS", "CAT3", "CAT2", "CAT1"
  final String code;

  /// Full description of the priority (max 300 chars)
  final String description;

  const PriorityLevel({
    required this.code,
    required this.description,
  });

  /// Default priorities for new sites
  /// Order: OK → OBS → CAT3 → CAT2 → CAT1 (increasing severity)
  static const List<PriorityLevel> defaults = [
    PriorityLevel(
      code: 'OK',
      description: 'There is no defect and no action is required',
    ),
    PriorityLevel(
      code: 'OBS',
      description: 'Observation and no immediate action is required',
    ),
    PriorityLevel(
      code: 'CAT3',
      description: 'Improvement is required',
    ),
    PriorityLevel(
      code: 'CAT2',
      description: 'Potentially dangerous and remedial action should be taken soon',
    ),
    PriorityLevel(
      code: 'CAT1',
      description: 'There is a significant risk to persons or property and immediate action is required!',
    ),
  ];

  /// Create a copy with updated fields
  PriorityLevel copyWith({
    String? code,
    String? description,
  }) {
    return PriorityLevel(
      code: code ?? this.code,
      description: description ?? this.description,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
    };
  }

  /// Create from JSON (database)
  factory PriorityLevel.fromJson(Map<String, dynamic> json) {
    return PriorityLevel(
      code: json['code'] as String,
      description: json['description'] as String,
    );
  }

  /// Convert list to JSON
  static List<Map<String, dynamic>> listToJson(List<PriorityLevel> priorities) {
    return priorities.map((p) => p.toJson()).toList();
  }

  /// Create list from JSON
  static List<PriorityLevel> listFromJson(List<dynamic>? jsonList) {
    if (jsonList == null || jsonList.isEmpty) {
      return List.from(defaults); // Return defaults if no priorities stored
    }
    return jsonList
        .map((item) => PriorityLevel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriorityLevel &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          description == other.description;

  @override
  int get hashCode => code.hashCode ^ description.hashCode;

  @override
  String toString() => 'PriorityLevel(code: $code, description: $description)';
}