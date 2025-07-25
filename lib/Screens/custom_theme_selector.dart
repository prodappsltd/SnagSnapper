import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Data/contentProvider.dart';

/// Simple theme selector to test custom color schemes
class CustomThemeSelector extends StatelessWidget {
  const CustomThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final cp = Provider.of<CP>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Theme Style',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Theme options
            RadioListTile<String>(
              title: const Text('Construction Orange'),
              subtitle: const Text('Bright orange with blue accents'),
              value: 'orange',
              groupValue: cp.themeType,
              activeColor: theme.colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  cp.changeThemeType(value);
                }
              },
            ),
            
            RadioListTile<String>(
              title: const Text('Safety Orange'),
              subtitle: const Text('Safety orange with purple accents'),
              value: 'safety',
              groupValue: cp.themeType,
              activeColor: theme.colorScheme.primary,
              onChanged: (value) {
                if (value != null) {
                  cp.changeThemeType(value);
                }
              },
            ),
            
            const SizedBox(height: 32),
            
            // Dark mode toggle
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(
                cp.brightness == Brightness.dark ? 'Enabled' : 'Disabled',
              ),
              value: cp.brightness == Brightness.dark,
              activeColor: theme.colorScheme.primary,
              onChanged: (value) {
                cp.changeBrightness(
                  value ? Brightness.dark : Brightness.light,
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Color preview
            Text(
              'Current Theme Colors',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorChip(
                  label: 'Primary',
                  color: theme.colorScheme.primary,
                  textColor: theme.colorScheme.onPrimary,
                ),
                _ColorChip(
                  label: 'Secondary',
                  color: theme.colorScheme.secondary,
                  textColor: theme.colorScheme.onSecondary,
                ),
                _ColorChip(
                  label: 'Tertiary',
                  color: theme.colorScheme.tertiary,
                  textColor: theme.colorScheme.onTertiary,
                ),
                _ColorChip(
                  label: 'Surface',
                  color: theme.colorScheme.surface,
                  textColor: theme.colorScheme.onSurface,
                ),
              ],
            ),
            
            const Spacer(),
            
            // Info text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These themes use custom color schemes instead of Material 3 seed generation to maintain true orange colors.',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  
  const _ColorChip({
    required this.label,
    required this.color,
    required this.textColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}