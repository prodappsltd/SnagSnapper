import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/security_service.dart';
import 'security_dialog.dart';

/// Floating debug button for testing security dialogs
///
/// Only visible in debug mode (kDebugMode == true).
/// Provides buttons to test:
/// - Warning dialog (dismissible)
/// - Block dialog (non-dismissible, exits app)
///
/// Usage: Add to Stack in any screen:
/// ```dart
/// Stack(
///   children: [
///     // Your content
///     const DebugSecurityButton(),
///   ],
/// )
/// ```
class DebugSecurityButton extends StatefulWidget {
  const DebugSecurityButton({super.key});

  @override
  State<DebugSecurityButton> createState() => _DebugSecurityButtonState();
}

class _DebugSecurityButtonState extends State<DebugSecurityButton> {
  // Tracks if the menu is expanded
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded menu options
          if (_isExpanded) ...[
            // Test Warning Dialog button
            _buildOptionButton(
              icon: Icons.warning_amber_rounded,
              label: 'Test Warning',
              color: Colors.orange,
              onPressed: () => _showTestWarning(context),
            ),
            const SizedBox(height: 8),
            // Test Block Dialog button
            _buildOptionButton(
              icon: Icons.block_rounded,
              label: 'Test Block',
              color: Colors.red,
              onPressed: () => _showTestBlock(context),
            ),
            const SizedBox(height: 8),
            // Test specific threats dropdown
            _buildOptionButton(
              icon: Icons.list_alt_rounded,
              label: 'All Threats',
              color: Colors.purple,
              onPressed: () => _showThreatPicker(context),
            ),
            const SizedBox(height: 12),
          ],
          // Main toggle button
          FloatingActionButton.small(
            heroTag: 'debug_security_fab',
            backgroundColor: _isExpanded ? Colors.grey[700] : Colors.blue,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Icon(
              _isExpanded ? Icons.close : Icons.security_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an option button for the expanded menu
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a test warning dialog
  void _showTestWarning(BuildContext context) {
    setState(() => _isExpanded = false);
    SecurityDialog.showTestDialog(
      context,
      responseType: ThreatResponse.warn,
      customTitle: 'Test Warning Dialog',
      customMessage: 'This is how the warning dialog looks. In production, this would be shown for root/jailbreak detection.',
    );
  }

  /// Shows a test block dialog
  void _showTestBlock(BuildContext context) {
    setState(() => _isExpanded = false);
    SecurityDialog.showTestDialog(
      context,
      responseType: ThreatResponse.block,
      customTitle: 'Test Block Dialog',
      customMessage: 'This is how the block dialog looks. In production, the user would be forced to exit the app.',
    );
  }

  /// Shows a picker to test specific threat types
  void _showThreatPicker(BuildContext context) {
    setState(() => _isExpanded = false);

    // All configured threat types with their response types
    final threats = [
      ('privileged_access', 'Root/Jailbreak', ThreatResponse.warn),
      ('simulator', 'Emulator', ThreatResponse.block),
      ('multi_instance', 'App Cloning', ThreatResponse.block),
      ('hooks', 'Frida/Hooking', ThreatResponse.block),
      ('debug', 'Debugger', ThreatResponse.block),
      ('app_integrity', 'Tampering', ThreatResponse.block),
      ('unofficial_store', 'Sideloaded', ThreatResponse.block),
      ('dev_mode', 'Developer Mode', ThreatResponse.log),
      ('adb_enabled', 'ADB Enabled', ThreatResponse.log),
      ('device_binding', 'Device Binding', ThreatResponse.log),
    ];

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEBUG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Test Security Threats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: threats.length,
                  itemBuilder: (listContext, index) {
                    final (threatType, displayName, response) = threats[index];
                    return ListTile(
                      leading: Icon(
                        response == ThreatResponse.block
                            ? Icons.block_rounded
                            : response == ThreatResponse.warn
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                        color: response == ThreatResponse.block
                            ? Colors.red
                            : response == ThreatResponse.warn
                                ? Colors.orange
                                : Colors.grey,
                      ),
                      title: Text(displayName),
                      subtitle: Text(
                        response == ThreatResponse.block
                            ? 'Block'
                            : response == ThreatResponse.warn
                                ? 'Warning'
                                : 'Log only',
                        style: TextStyle(
                          color: response == ThreatResponse.block
                              ? Colors.red
                              : response == ThreatResponse.warn
                                  ? Colors.orange
                                  : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: response == ThreatResponse.log
                          ? const Text(
                              'No dialog',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (response != ThreatResponse.log) {
                          // Get threat info and show dialog
                          final threatInfo = SecurityService.getThreatInfo(threatType);
                          SecurityDialog.showTestDialog(
                            context,
                            responseType: response,
                            customTitle: threatInfo.title,
                            customMessage: threatInfo.message,
                          );
                        } else {
                          // Show snackbar for log-only threats
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$displayName is log-only (no dialog shown)'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
