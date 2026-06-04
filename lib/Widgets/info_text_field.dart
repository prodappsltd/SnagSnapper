import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable TextFormField widget with an info icon that shows help text in a popup.
///
/// This widget replaces the standard helperText (which appears underneath the field)
/// with an info icon (ℹ️) positioned after the label. When tapped, the icon shows
/// a popup dialog with the help text in a larger, more readable format.
///
/// Usage:
/// ```dart
/// InfoTextField(
///   labelText: 'Site Name',
///   infoText: 'Provide a unique, descriptive name for this site',
///   prefixIcon: Icons.apartment,
///   initialValue: _siteName,
///   onChanged: (value) => _siteName = value,
///   validator: (value) => value!.isEmpty ? 'Required' : null,
/// )
/// ```
class InfoTextField extends StatelessWidget {
  /// The label text displayed above/inside the field
  final String labelText;

  /// The help text shown in the info popup (replaces helperText)
  final String infoText;

  /// Optional hint text shown when field is empty
  final String? hintText;

  /// Optional prefix icon displayed at the start of the field
  final IconData? prefixIcon;

  /// Initial value for the field
  final String? initialValue;

  /// Controller for the text field (alternative to initialValue)
  final TextEditingController? controller;

  /// Callback when the text changes
  final ValueChanged<String>? onChanged;

  /// Validation function
  final FormFieldValidator<String>? validator;

  /// Keyboard type for the field
  final TextInputType? keyboardType;

  /// Text capitalization behavior
  final TextCapitalization textCapitalization;

  /// Input formatters for restricting input
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the field is enabled
  final bool enabled;

  /// Whether this is a required field (shows asterisk)
  final bool isRequired;

  /// Maximum number of lines
  final int? maxLines;

  /// Minimum number of lines
  final int? minLines;

  /// Whether the field obscures text (for passwords)
  final bool obscureText;

  /// Suffix icon widget
  final Widget? suffixIcon;

  /// Focus node for the field
  final FocusNode? focusNode;

  /// Action when user submits
  final TextInputAction? textInputAction;

  /// Callback when user submits
  final ValueChanged<String>? onFieldSubmitted;

  const InfoTextField({
    super.key,
    required this.labelText,
    required this.infoText,
    this.hintText,
    this.prefixIcon,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
    this.isRequired = false,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.suffixIcon,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  /// Shows the info popup dialog with the help text
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  labelText,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            infoText,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Got it',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row with info icon
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelText,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.error,
                  ),
                ),
              const SizedBox(width: 4),
              // Info icon button
              GestureDetector(
                onTap: () => _showInfoDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Text field
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          obscureText: obscureText,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: GoogleFonts.montserrat(fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? theme.colorScheme.surface
                : theme.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: theme.colorScheme.primary)
                : null,
            suffixIcon: suffixIcon,
            hintText: hintText,
            hintStyle: GoogleFonts.montserrat(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            errorStyle: GoogleFonts.montserrat(
              fontSize: 12,
              color: theme.colorScheme.error,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}