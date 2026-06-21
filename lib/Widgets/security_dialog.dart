import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';

/// Dialog widget for displaying security threat warnings and blocks
///
/// Two modes:
/// - Warning mode: Dismissible dialog with "I Understand" button
/// - Block mode: Non-dismissible dialog with "Exit App" button only
///
/// Usage:
/// ```dart
/// SecurityDialog.show(context, threatInfo);
/// ```
class SecurityDialog {
  /// Shows the appropriate security dialog based on threat response type
  ///
  /// For [ThreatResponse.warn]: Shows dismissible warning dialog
  /// For [ThreatResponse.block]: Shows non-dismissible block dialog
  /// For [ThreatResponse.log]: Does nothing (log-only threats don't show UI)
  static Future<void> show(BuildContext context, ThreatInfo threatInfo) async {
    // Log-only threats don't show any dialog
    if (threatInfo.response == ThreatResponse.log) {
      return;
    }

    // For warnings, check if already dismissed
    if (threatInfo.response == ThreatResponse.warn) {
      final isDismissed = await SecurityService.isWarningDismissed(threatInfo.threatType);
      if (isDismissed) {
        // Warning was already shown and dismissed, don't show again
        return;
      }
    }

    // Ensure context is still valid before showing dialog
    if (!context.mounted) return;

    // Show the appropriate dialog type
    if (threatInfo.response == ThreatResponse.block) {
      await _showBlockDialog(context, threatInfo);
    } else {
      await _showWarningDialog(context, threatInfo);
    }
  }

  /// Shows a dismissible warning dialog
  /// User can tap "I Understand" to dismiss and continue using the app
  static Future<void> _showWarningDialog(BuildContext context, ThreatInfo threatInfo) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Must tap button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // Warning icon in amber/orange color
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
          title: Text(
            threatInfo.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            threatInfo.message,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Mark warning as dismissed so it won't show again
                await SecurityService.markWarningDismissed(threatInfo.threatType);
                // Close the dialog
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a non-dismissible block dialog
  /// User must tap "Exit App" - back button and outside tap are disabled
  static Future<void> _showBlockDialog(BuildContext context, ThreatInfo threatInfo) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (BuildContext dialogContext) {
        // Wrap with PopScope to prevent back button from dismissing
        return PopScope(
          canPop: false, // Prevents back button from closing dialog
          child: AlertDialog(
            // Error/block icon in red
            icon: const Icon(
              Icons.block_rounded,
              color: Colors.red,
              size: 48,
            ),
            title: Text(
              threatInfo.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  threatInfo.message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Additional info text explaining this is a security measure
                Text(
                  'For security reasons, the app cannot continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () {
                  // Reset the block dialog flag before exiting
                  SecurityService.resetBlockDialogFlag();
                  // Exit the app - this closes the app completely
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Exit App'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a test dialog for debugging purposes
  /// Allows testing both warning and block dialogs in debug mode
  static Future<void> showTestDialog(
    BuildContext context, {
    required ThreatResponse responseType,
    String? customTitle,
    String? customMessage,
  }) async {
    final threatInfo = ThreatInfo(
      threatType: 'test_${responseType.name}',
      title: customTitle ?? (responseType == ThreatResponse.block ? 'Test Block Dialog' : 'Test Warning Dialog'),
      message: customMessage ?? (responseType == ThreatResponse.block
          ? 'This is a test block dialog. In production, you would need to exit the app.'
          : 'This is a test warning dialog. You can dismiss this and continue.'),
      response: responseType,
      severity: 0,
    );

    // For test dialogs, bypass the dismissal check
    if (!context.mounted) return;

    if (responseType == ThreatResponse.block) {
      await _showTestBlockDialog(context, threatInfo);
    } else {
      await _showTestWarningDialog(context, threatInfo);
    }
  }

  /// Test warning dialog that doesn't persist dismissal state
  static Future<void> _showTestWarningDialog(BuildContext context, ThreatInfo threatInfo) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Text(threatInfo.title),
            ],
          ),
          content: Text(
            threatInfo.message,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Dismiss Test'),
            ),
          ],
        );
      },
    );
  }

  /// Test block dialog that allows dismissal (unlike production)
  static Future<void> _showTestBlockDialog(BuildContext context, ThreatInfo threatInfo) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.block_rounded,
            color: Colors.red,
            size: 48,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  threatInfo.title,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                threatInfo.message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'In production, this would force app exit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            // In test mode, allow dismissal instead of exiting
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Dismiss Test'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Optionally exit app even in test mode
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Exit App'),
            ),
          ],
        );
      },
    );
  }
}
