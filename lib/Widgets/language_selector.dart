import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_typography.dart';

class LanguageSelector extends StatelessWidget {
  final String currentLanguageCode;
  final Function(String) onLanguageChanged;

  const LanguageSelector({
    Key? key,
    required this.currentLanguageCode,
    required this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLanguage = AppLanguages.getLanguageByCode(currentLanguageCode);

    return InkWell(
      onTap: () => _showLanguageDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLanguage.flag,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Language',
                  style: AppTypography.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentLanguage.nativeName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Language',
                        style: AppTypography.headlineSmall,
                      ),
                    ],
                  ),
                ),
                // Language list
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: AppLanguages.supportedLanguages.length,
                    itemBuilder: (context, index) {
                      final language = AppLanguages.supportedLanguages[index];
                      final isSelected = language.code == currentLanguageCode;
                      
                      return ListTile(
                        leading: Text(
                          language.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          language.nativeName,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          language.name,
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          onLanguageChanged(language.code);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
                // Close button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTypography.labelLarge.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Example usage in settings or profile screen:
/// 
/// ```dart
/// LanguageSelector(
///   currentLanguageCode: 'en',
///   onLanguageChanged: (languageCode) {
///     // Update app locale
///     setState(() {
///       _currentLocale = Locale(languageCode);
///     });
///     // Save to preferences
///     LocaleStorage.saveLocale(languageCode);
///   },
/// )
/// ```