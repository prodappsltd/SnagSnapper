import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snagsnapper/Data/models/app_user.dart';

enum ConflictStrategy {
  localWins,
  remoteWins,
  merge,
  manual,
}

class ConflictResult {
  final ConflictStrategy strategy;
  final AppUser resolvedUser;
  final bool shouldUpload;
  final bool hasError;
  final bool hasValidationIssues;
  final bool hasCorruption;
  final bool requiresUserIntervention;
  final String? errorMessage;

  ConflictResult({
    required this.strategy,
    required this.resolvedUser,
    required this.shouldUpload,
    this.hasError = false,
    this.hasValidationIssues = false,
    this.hasCorruption = false,
    this.requiresUserIntervention = false,
    this.errorMessage,
  });
}

class ConflictResolver {
  ConflictStrategy? _manualStrategy;

  void setManualStrategy(ConflictStrategy strategy) {
    _manualStrategy = strategy;
  }

  Future<ConflictResult> resolveConflict(
    AppUser localUser,
    Map<String, dynamic> remoteData,
  ) async {
    // Check for manual override
    if (_manualStrategy == ConflictStrategy.manual) {
      return ConflictResult(
        strategy: ConflictStrategy.manual,
        resolvedUser: localUser,
        shouldUpload: false,
        requiresUserIntervention: true,
      );
    }

    // Check for data corruption
    if (_isCorrupted(remoteData)) {
      return ConflictResult(
        strategy: ConflictStrategy.localWins,
        resolvedUser: localUser,
        shouldUpload: true,
        hasCorruption: true,
        errorMessage: 'Remote data contains corruption',
      );
    }

    // Validate data
    final validationIssues = _validateData(remoteData);
    if (validationIssues.isNotEmpty) {
      // Try to use valid fields only
      final mergedUser = _mergeValidFields(localUser, remoteData, validationIssues);
      return ConflictResult(
        strategy: ConflictStrategy.merge,
        resolvedUser: mergedUser,
        shouldUpload: true,
        hasValidationIssues: true,
        errorMessage: 'Data validation issues detected',
      );
    }

    // Determine strategy based on versions
    final strategy = determineStrategy(localUser, remoteData);

    switch (strategy) {
      case ConflictStrategy.localWins:
        return ConflictResult(
          strategy: strategy,
          resolvedUser: localUser,
          shouldUpload: true,
        );

      case ConflictStrategy.remoteWins:
        final remoteUser = _mapRemoteToUser(localUser, remoteData);
        return ConflictResult(
          strategy: strategy,
          resolvedUser: remoteUser,
          shouldUpload: false,
        );

      case ConflictStrategy.merge:
        final mergedUser = _mergeUsers(localUser, remoteData);
        return ConflictResult(
          strategy: strategy,
          resolvedUser: mergedUser,
          shouldUpload: true,
        );

      default:
        return ConflictResult(
          strategy: ConflictStrategy.merge,
          resolvedUser: localUser,
          shouldUpload: false,
        );
    }
  }

  ConflictStrategy determineStrategy(AppUser localUser, Map<String, dynamic> remoteData) {
    if (_manualStrategy != null) {
      return _manualStrategy!;
    }

    final remoteVersion = _getRemoteVersion(remoteData);
    
    // No remote version means first sync
    if (remoteVersion == null || remoteVersion == 0) {
      return ConflictStrategy.localWins;
    }

    // Invalid remote version
    if (remoteVersion < 0) {
      return ConflictStrategy.localWins;
    }

    final localVersion = localUser.localVersion ?? 0;

    if (localVersion > remoteVersion) {
      return ConflictStrategy.localWins;
    } else if (remoteVersion > localVersion) {
      return ConflictStrategy.remoteWins;
    } else {
      // Same version - check timestamps
      final localTime = localUser.updatedAt;
      final remoteTime = _getRemoteUpdatedAt(remoteData);

      if (remoteTime == null) {
        return ConflictStrategy.localWins;
      }

      if (localTime.isAfter(remoteTime)) {
        return ConflictStrategy.localWins;
      } else if (remoteTime.isAfter(localTime)) {
        return ConflictStrategy.remoteWins;
      } else {
        return ConflictStrategy.merge;
      }
    }
  }

  int? _getRemoteVersion(Map<String, dynamic> remoteData) {
    final version = remoteData['version'];
    if (version == null) return null;
    if (version is int) return version;
    if (version is String) {
      try {
        return int.parse(version);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  DateTime? _getRemoteUpdatedAt(Map<String, dynamic> remoteData) {
    final updatedAt = remoteData['updatedAt'];
    if (updatedAt == null) return null;
    if (updatedAt is Timestamp) {
      return updatedAt.toDate();
    }
    if (updatedAt is String) {
      try {
        return DateTime.parse(updatedAt);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  bool _isCorrupted(Map<String, dynamic> remoteData) {
    // Check for null bytes or control characters
    for (final value in remoteData.values) {
      if (value is String) {
        if (value.contains('\u0000') || value.contains('\u0001') || value.contains('\u0002')) {
          return true;
        }
      }
    }

    // Check for invalid version
    final version = remoteData['version'];
    if (version != null) {
      if (version is double && (version.isInfinite || version.isNaN)) {
        return true;
      }
    }

    return false;
  }

  List<String> _validateData(Map<String, dynamic> remoteData) {
    final issues = <String>[];

    // Check required fields
    if (remoteData['name'] == null || remoteData['name'].toString().isEmpty) {
      issues.add('name');
    }
    if (remoteData['email'] == null || remoteData['email'].toString().isEmpty) {
      issues.add('email');
    }
    if (remoteData['companyName'] == null || remoteData['companyName'].toString().isEmpty) {
      issues.add('companyName');
    }

    // Validate email format
    final email = remoteData['email']?.toString();
    if (email != null && !_isValidEmail(email)) {
      issues.add('email_format');
    }

    // Validate field lengths
    if ((remoteData['name']?.toString().length ?? 0) > 50) {
      issues.add('name_length');
    }
    if ((remoteData['companyName']?.toString().length ?? 0) > 100) {
      issues.add('companyName_length');
    }
    if ((remoteData['phone']?.toString().length ?? 0) > 15) {
      issues.add('phone_length');
    }
    if ((remoteData['postcodeOrArea']?.toString().length ?? 0) > 20) {
      issues.add('postcodeOrArea_length');
    }

    // Check field types
    if (remoteData['name'] != null && remoteData['name'] is! String) {
      issues.add('name_type');
    }
    if (remoteData['email'] != null && remoteData['email'] is! String) {
      issues.add('email_type');
    }

    return issues;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  AppUser _mapRemoteToUser(AppUser localUser, Map<String, dynamic> remoteData) {
    return localUser.copyWith(
      name: remoteData['name']?.toString() ?? localUser.name,
      email: remoteData['email']?.toString() ?? localUser.email,
      companyName: remoteData['companyName']?.toString() ?? localUser.companyName,
      phone: remoteData['phone']?.toString(),
      jobTitle: remoteData['jobTitle']?.toString(),
      postcodeOrArea: remoteData['postcodeOrArea']?.toString(),
      dateFormat: remoteData['dateFormat']?.toString() ?? localUser.dateFormat,
      imageFirebaseUrl: remoteData['imageFirebaseUrl']?.toString(),
      signatureFirebaseUrl: remoteData['signatureFirebaseUrl']?.toString(),
      firebaseVersion: _getRemoteVersion(remoteData) ?? localUser.firebaseVersion,
    );
  }

  AppUser _mergeUsers(AppUser localUser, Map<String, dynamic> remoteData) {
    // Merge based on field-level timestamps if available
    final nameUpdatedAt = _getFieldTimestamp(remoteData, 'nameUpdatedAt');
    final companyUpdatedAt = _getFieldTimestamp(remoteData, 'companyNameUpdatedAt');
    final jobTitleUpdatedAt = _getFieldTimestamp(remoteData, 'jobTitleUpdatedAt');

    final localUpdateTime = localUser.updatedAt;

    return localUser.copyWith(
      name: (nameUpdatedAt != null && nameUpdatedAt.isAfter(localUpdateTime))
          ? remoteData['name']?.toString() ?? localUser.name
          : localUser.name,
      email: remoteData['email']?.toString() ?? localUser.email,
      companyName: (companyUpdatedAt != null && companyUpdatedAt.isAfter(localUpdateTime))
          ? remoteData['companyName']?.toString() ?? localUser.companyName
          : localUser.companyName,
      phone: remoteData['phone']?.toString() ?? localUser.phone,
      jobTitle: (jobTitleUpdatedAt != null && jobTitleUpdatedAt.isAfter(localUpdateTime))
          ? remoteData['jobTitle']?.toString() ?? localUser.jobTitle
          : localUser.jobTitle,
      postcodeOrArea: remoteData['postcodeOrArea']?.toString() ?? localUser.postcodeOrArea,
      imageFirebaseUrl: remoteData['imageFirebaseUrl']?.toString() ?? localUser.imageFirebaseUrl,
      signatureFirebaseUrl: remoteData['signatureFirebaseUrl']?.toString() ?? localUser.signatureFirebaseUrl,
    );
  }

  AppUser _mergeValidFields(
    AppUser localUser,
    Map<String, dynamic> remoteData,
    List<String> invalidFields,
  ) {
    // Only use valid fields from remote
    return localUser.copyWith(
      name: !invalidFields.contains('name') && !invalidFields.contains('name_length')
          ? remoteData['name']?.toString() ?? localUser.name
          : localUser.name,
      email: !invalidFields.contains('email') && !invalidFields.contains('email_format')
          ? remoteData['email']?.toString() ?? localUser.email
          : localUser.email,
      companyName: !invalidFields.contains('companyName') && !invalidFields.contains('companyName_length')
          ? remoteData['companyName']?.toString() ?? localUser.companyName
          : localUser.companyName,
      phone: !invalidFields.contains('phone_length')
          ? remoteData['phone']?.toString() ?? localUser.phone
          : localUser.phone,
      postcodeOrArea: !invalidFields.contains('postcodeOrArea_length')
          ? remoteData['postcodeOrArea']?.toString() ?? localUser.postcodeOrArea
          : localUser.postcodeOrArea,
    );
  }

  DateTime? _getFieldTimestamp(Map<String, dynamic> data, String field) {
    final timestamp = data[field];
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}