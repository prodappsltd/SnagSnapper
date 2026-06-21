import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Data/models/site.dart';

/// Shows the share site bottom sheet
///
/// Returns the updated sharedWith map if changes were saved, null otherwise
Future<Map<String, String>?> showShareSiteSheet({
  required BuildContext context,
  required Site site,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSiteSheet(site: site),
  );
}

/// Bottom sheet for managing site collaborators
class _ShareSiteSheet extends StatefulWidget {
  final Site site;

  const _ShareSiteSheet({required this.site});

  @override
  State<_ShareSiteSheet> createState() => _ShareSiteSheetState();
}

class _ShareSiteSheetState extends State<_ShareSiteSheet> {
  late Map<String, String> _sharedWith;
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  String _selectedPermission = 'WORKING_SEE_ALL';
  String? _emailError;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _sharedWith = Map<String, String>.from(widget.site.sharedWith);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  /// Validates email format using tightened regex (2026 best practice):
  /// - Allows + tags (user+newsletter@gmail.com)
  /// - Allows long TLDs (.museum, .technology)
  /// - Rejects: consecutive dots, dot before/after @, domain segments starting/ending with hyphen
  /// - Synced with CF validation in functions/index.js
  /// Negative lookaheads:
  ///   (?!.*\.\.) - no consecutive dots
  ///   (?!.*\.@)  - no dot before @
  ///   (?!.*@\.)  - no dot after @
  ///   (?!.*@-)   - no hyphen after @
  ///   (?!.*-\.)  - no hyphen before dot (segment ending with hyphen)
  ///   (?!.*\.-)  - no dot before hyphen (segment starting with hyphen)
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^(?!.*\.\.)(?!.*\.@)(?!.*@\.)(?!.*@-)(?!.*-\.)(?!.*\.-)[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  void _addCollaborator() {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter an email address');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      return;
    }

    if (_sharedWith.containsKey(email)) {
      setState(() => _emailError = 'Already a collaborator');
      return;
    }

    if (email == widget.site.ownerEmail.toLowerCase()) {
      setState(() => _emailError = 'Cannot add the site owner');
      return;
    }

    setState(() {
      _sharedWith[email] = _selectedPermission;
      _emailController.clear();
      _emailError = null;
      _hasChanges = true;
    });

    _emailFocusNode.unfocus();
  }

  void _removeCollaborator(String email) {
    setState(() {
      _sharedWith.remove(email);
      _hasChanges = true;
    });
  }

  void _changePermission(String email, String newPermission) {
    setState(() {
      _sharedWith[email] = newPermission;
      _hasChanges = true;
    });
  }

  void _showPermissionDetails(String permission) {
    final colorScheme = Theme.of(context).colorScheme;

    String title;
    String emoji;
    Color color;
    List<String> canDo;
    List<String> cannotDo;

    switch (permission) {
      case 'VIEW':
        title = 'View Only';
        emoji = '👁️';
        color = Colors.blue;
        canDo = [
          'View all snags and reports',
          'See site details and photos',
          'Download PDF reports',
        ];
        cannotDo = [
          'Create or edit snags',
          'Add photos or mark complete',
          'Change anything',
        ];
        break;
      case 'WORKING_SEE_ALL':
        title = 'Worker (View All Snags)';
        emoji = '🔧';
        color = Colors.orange;
        canDo = [
          'View ALL snags under this site',
          'Fix & update snags assigned to them only',
        ];
        cannotDo = [
          'Create new snags',
          'Update snags assigned to others or are unassigned',
          'Change site settings',
        ];
        break;
      case 'WORKING_SEE_SELF':
        title = 'Worker (View Only Assigned Snags)';
        emoji = '🎯';
        color = Colors.deepOrange;
        canDo = [
          'View snags assigned to them only under this site',
          'Fix & update snags assigned to them only',
        ];
        cannotDo = [
          'Create new snags',
          'Change site settings',
        ];
        break;
      case 'CONTRIBUTOR':
        title = 'Contributor';
        emoji = '✏️';
        color = Colors.green;
        canDo = [
          'View all snags',
          'Create new snags',
          'Work on snags assigned to them',
          'Add fix photos and mark complete',
        ];
        cannotDo = [
          'Edit snags created by others',
          'Delete snags',
          'Change site settings or sharing',
        ];
        break;
      default:
        return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with emoji
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Permission Level',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // CAN section
                      _buildPermissionSection(
                        title: 'CAN DO',
                        items: canDo,
                        icon: Icons.check_circle_rounded,
                        color: Colors.green,
                        colorScheme: colorScheme,
                      ),

                      const SizedBox(height: 20),

                      // CAN'T section
                      _buildPermissionSection(
                        title: "CAN'T DO",
                        items: cannotDo,
                        icon: Icons.cancel_rounded,
                        color: colorScheme.error,
                        colorScheme: colorScheme,
                      ),

                      const SizedBox(height: 24),

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Got it',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Bottom safe area padding
                      SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionSection({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Site',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.site.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Collaborators
                  if (_sharedWith.isNotEmpty) ...[
                    _buildSectionHeader('COLLABORATORS', '${_sharedWith.length}'),
                    const SizedBox(height: 12),
                    ..._sharedWith.entries.map((entry) => _CollaboratorCard(
                          email: entry.key,
                          permission: entry.value,
                          onRemove: () => _removeCollaborator(entry.key),
                          onPermissionChange: (p) => _changePermission(entry.key, p),
                          onInfoTap: () => _showPermissionDetails(entry.value),
                        )),
                    const SizedBox(height: 28),
                  ],

                  // Add New Section
                  _buildSectionHeader('ADD NEW COLLABORATOR', null),
                  const SizedBox(height: 16),

                  // Email Input
                  TextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,           // Disables double-space to period
                    enableSuggestions: false,     // No suggestions for email
                    textCapitalization: TextCapitalization.none,  // No auto-caps
                    style: GoogleFonts.inter(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter email address',
                      hintStyle: GoogleFonts.inter(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12),
                        child: Icon(
                          Icons.email_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      errorText: _emailError,
                      errorStyle: GoogleFonts.inter(fontSize: 13),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    onSubmitted: (_) => _addCollaborator(),
                  ),

                  const SizedBox(height: 24),

                  // Permission Selection Header
                  Text(
                    'SELECT PERMISSION',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Permission Cards
                  _PermissionCard(
                    permission: 'VIEW',
                    title: 'View Only',
                    description: 'Can see everything but cannot make changes',
                    emoji: '👁️',
                    color: Colors.blue,
                    isSelected: _selectedPermission == 'VIEW',
                    onTap: () => setState(() => _selectedPermission = 'VIEW'),
                    onInfoTap: () => _showPermissionDetails('VIEW'),
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    permission: 'WORKING_SEE_ALL',
                    title: 'Worker (See ALL snags)',
                    description: 'Can see all snags, complete assigned ones only',
                    emoji: '🔧',
                    color: Colors.orange,
                    isSelected: _selectedPermission == 'WORKING_SEE_ALL',
                    onTap: () => setState(() => _selectedPermission = 'WORKING_SEE_ALL'),
                    onInfoTap: () => _showPermissionDetails('WORKING_SEE_ALL'),
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    permission: 'WORKING_SEE_SELF',
                    title: 'Worker (Assigned Only)',
                    description: 'Can only see and complete their assigned snags',
                    emoji: '🎯',
                    color: Colors.deepOrange,
                    isSelected: _selectedPermission == 'WORKING_SEE_SELF',
                    onTap: () => setState(() => _selectedPermission = 'WORKING_SEE_SELF'),
                    onInfoTap: () => _showPermissionDetails('WORKING_SEE_SELF'),
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    permission: 'CONTRIBUTOR',
                    title: 'Contributor',
                    description: 'Can create new snags and work on assigned',
                    emoji: '✏️',
                    color: Colors.green,
                    isSelected: _selectedPermission == 'CONTRIBUTOR',
                    onTap: () => setState(() => _selectedPermission = 'CONTRIBUTOR'),
                    onInfoTap: () => _showPermissionDetails('CONTRIBUTOR'),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Actions
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                // Add Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _emailController.text.trim().isNotEmpty
                          ? _addCollaborator
                          : null,
                      icon: const Icon(Icons.person_add_rounded, size: 22),
                      label: Text(
                        'Add',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),

                // Save Button (if changes made)
                if (_hasChanges) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, _sharedWith),
                        icon: const Icon(Icons.check_rounded, size: 22),
                        label: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Card showing a collaborator with permission and actions
class _CollaboratorCard extends StatelessWidget {
  final String email;
  final String permission;
  final VoidCallback onRemove;
  final Function(String) onPermissionChange;
  final VoidCallback onInfoTap;

  const _CollaboratorCard({
    required this.email,
    required this.permission,
    required this.onRemove,
    required this.onPermissionChange,
    required this.onInfoTap,
  });

  Color _getPermissionColor() {
    switch (permission) {
      case 'VIEW':
        return Colors.blue;
      case 'WORKING_SEE_ALL':
        return Colors.orange;
      case 'WORKING_SEE_SELF':
        return Colors.deepOrange;
      case 'CONTRIBUTOR':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPermissionEmoji() {
    switch (permission) {
      case 'VIEW':
        return '👁️';
      case 'WORKING_SEE_ALL':
        return '🔧';
      case 'WORKING_SEE_SELF':
        return '🎯';
      case 'CONTRIBUTOR':
        return '✏️';
      default:
        return '👤';
    }
  }

  String _getPermissionLabel() {
    switch (permission) {
      case 'VIEW':
        return 'View';
      case 'WORKING_SEE_ALL':
        return 'Worker (All)';
      case 'WORKING_SEE_SELF':
        return 'Worker (Assigned)';
      case 'CONTRIBUTOR':
        return 'Contributor';
      default:
        return permission;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _getPermissionColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email row
          Row(
            children: [
              // Avatar with emoji
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getPermissionEmoji(),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _getPermissionLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onInfoTap,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Remove button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_remove_rounded,
                      color: colorScheme.error,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Permission quick-change chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Change to:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (permission != 'VIEW')
                _QuickChangeChip(
                  label: '👁️ View',
                  onTap: () => onPermissionChange('VIEW'),
                ),
              if (permission != 'WORKING_SEE_ALL')
                _QuickChangeChip(
                  label: '🔧 All',
                  onTap: () => onPermissionChange('WORKING_SEE_ALL'),
                ),
              if (permission != 'WORKING_SEE_SELF')
                _QuickChangeChip(
                  label: '🎯 Assigned',
                  onTap: () => onPermissionChange('WORKING_SEE_SELF'),
                ),
              if (permission != 'CONTRIBUTOR')
                _QuickChangeChip(
                  label: '✏️ Contrib',
                  onTap: () => onPermissionChange('CONTRIBUTOR'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small chip for quick permission change
class _QuickChangeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChangeChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Permission selection card with large touch target
class _PermissionCard extends StatelessWidget {
  final String permission;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _PermissionCard({
    required this.permission,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Row(
            children: [
              // Emoji container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Info button - large touch target
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onInfoTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: isSelected ? color : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Selection indicator
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
