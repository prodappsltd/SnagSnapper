import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Data/colleague.dart';

class ColleaguesSection extends StatefulWidget {
  final List<Colleague> colleagues;
  final Function(Colleague) onAddColleague;
  final Function(int) onRemoveColleague;
  final bool isEditable;

  const ColleaguesSection({
    Key? key,
    required this.colleagues,
    required this.onAddColleague,
    required this.onRemoveColleague,
    this.isEditable = true,
  }) : super(key: key);

  @override
  State<ColleaguesSection> createState() => _ColleaguesSectionState();
}

class _ColleaguesSectionState extends State<ColleaguesSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: Radius.circular(_isExpanded ? 0 : 16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Colleagues',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (widget.colleagues.isNotEmpty)
                          Text(
                            '${widget.colleagues.length} colleague${widget.colleagues.length > 1 ? 's' : ''} added',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.isEditable && !_isExpanded)
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () => _showAddColleagueDialog(context),
                      tooltip: 'Add colleague',
                    ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (widget.colleagues.isEmpty)
                  _buildEmptyState(context)
                else
                  _buildColleaguesList(context),
                if (widget.isEditable)
                  _buildAddButton(context),
              ],
            ),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No colleagues added yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add colleagues to share sites and collaborate',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildColleaguesList(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.colleagues.length,
        itemBuilder: (context, index) {
          final colleague = widget.colleagues[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                child: Text(
                  colleague.name.isNotEmpty 
                      ? colleague.name[0].toUpperCase() 
                      : '?',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              title: Text(
                colleague.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    colleague.email,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (colleague.phone != null && colleague.phone!.isNotEmpty)
                    Text(
                      colleague.phone!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              trailing: widget.isEditable
                  ? IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      onPressed: () => _confirmRemoveColleague(context, index, colleague),
                      tooltip: 'Remove colleague',
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: () => _showAddColleagueDialog(context),
        icon: const Icon(Icons.person_add),
        label: Text(
          'Add Colleague',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveColleague(BuildContext context, int index, Colleague colleague) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Colleague?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove ${colleague.name} from your colleagues list?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onRemoveColleague(index);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddColleagueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddColleagueDialog(
        onAdd: widget.onAddColleague,
        existingColleagues: widget.colleagues,
      ),
    );
  }
}

class AddColleagueDialog extends StatefulWidget {
  final Function(Colleague) onAdd;
  final List<Colleague> existingColleagues;

  const AddColleagueDialog({
    Key? key,
    required this.onAdd,
    required this.existingColleagues,
  }) : super(key: key);

  @override
  State<AddColleagueDialog> createState() => _AddColleagueDialogState();
}

class _AddColleagueDialogState extends State<AddColleagueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Generate a temporary ID (will be replaced with actual Firebase UID later)
    _idController.text = 'temp_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Colleague',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name field (Required)
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter colleague\'s name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelStyle: GoogleFonts.inter(),
                  hintStyle: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                style: GoogleFonts.inter(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email field (Required)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  hintText: 'colleague@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelStyle: GoogleFonts.inter(),
                  hintStyle: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                style: GoogleFonts.inter(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  // Email validation regex
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  // Check for duplicate emails
                  if (widget.existingColleagues.any(
                      (c) => c.email.toLowerCase() == value.trim().toLowerCase())) {
                    return 'This colleague already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone field (Optional)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone (Optional)',
                  hintText: '+1234567890',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelStyle: GoogleFonts.inter(),
                  hintStyle: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                style: GoogleFonts.inter(),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Basic phone validation - at least 7 digits
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length < 7) {
                      return 'Phone number seems too short';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Helper text
              Text(
                '* Required fields',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: _handleAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'Add',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAdd() {
    if (_formKey.currentState!.validate()) {
      final colleague = Colleague(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        uniqueID: _idController.text,
      );
      
      widget.onAdd(colleague);
      Navigator.pop(context);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${colleague.name} to colleagues',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}