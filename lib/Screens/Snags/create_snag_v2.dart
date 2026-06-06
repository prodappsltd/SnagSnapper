import 'dart:convert';
import 'dart:io';
import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/snag.dart';
import 'package:uuid/uuid.dart';

/// Modern CreateSnag screen with improved UX and visual design
/// This replaces the legacy CreateEditSnag.dart while keeping that file as backup
class CreateSnagV2 extends StatefulWidget {
  final Snag? snag;
  final String siteID;
  final String siteOwnersEmail;

  const CreateSnagV2({
    super.key,
    required this.snag,
    required this.siteID,
    required this.siteOwnersEmail,
  });

  @override
  State<CreateSnagV2> createState() => _CreateSnagV2State();
}

class _CreateSnagV2State extends State<CreateSnagV2>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form fields
  final _locationController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Images (base64)
  String _mainImage = '';
  String _image2 = '';
  String _image3 = '';
  String _image4 = '';

  // Other fields
  int _priority = 0;
  DateTime? _dueDate;
  String _assignedEmail = '';
  String _assignedName = '';

  // State
  bool _isNewSnag = true;
  bool _isSaving = false;
  bool _isOwner = false;

  // Focus nodes
  final _locationFocus = FocusNode();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _initializeForm();
    _animationController.forward();
  }

  void _initializeForm() {
    final appUser = Provider.of<CP>(context, listen: false).getAppUser();
    _isOwner = appUser?.email.toLowerCase() == widget.siteOwnersEmail.toLowerCase();

    if (widget.snag != null) {
      _isNewSnag = false;
      final snag = widget.snag!;
      _locationController.text = snag.location ?? '';
      _titleController.text = snag.title;
      _descriptionController.text = snag.description ?? '';
      _mainImage = snag.imageMain1 ?? '';
      _image2 = snag.image2 ?? '';
      _image3 = snag.image3 ?? '';
      _image4 = snag.image4 ?? '';
      _priority = snag.priority;
      _dueDate = snag.dueDate;
      _assignedEmail = snag.assignedEmail ?? '';
      _assignedName = snag.assignedName ?? '';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationFocus.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          _buildAppBar(colorScheme),

          // Main Image Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildMainImageSection(colorScheme),
            ),
          ),

          // Form Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildFormSection(colorScheme),
            ),
          ),

          // Supporting Images Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSupportingImagesSection(colorScheme),
            ),
          ),

          // Priority Section (Owner only)
          if (_isOwner)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildPrioritySection(colorScheme),
              ),
            ),

          // Due Date Section (Owner only)
          if (_isOwner)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildDueDateSection(colorScheme),
              ),
            ),

          // Assignment Section (Owner only - placeholder)
          if (_isOwner)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildAssignmentSection(colorScheme),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(colorScheme),
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ),
        onPressed: () => _handleBack(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isNewSnag ? 'New Snag' : 'Edit Snag',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (!_isNewSnag && widget.snag != null)
            Text(
              'Created ${_formatDate(widget.snag!.creationDate)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        if (!_isSaving)
          TextButton.icon(
            onPressed: _saveSnag,
            icon: Icon(Icons.check_rounded, color: colorScheme.primary),
            label: Text(
              'Save',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMainImageSection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Main Photo',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickMainImage(),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _mainImage.isEmpty
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _mainImage.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBase64Image(_mainImage),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                _buildImageActionButton(
                                  icon: Icons.edit_rounded,
                                  onTap: () => _pickMainImage(),
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(width: 8),
                                _buildImageActionButton(
                                  icon: Icons.delete_rounded,
                                  onTap: () => setState(() => _mainImage = ''),
                                  colorScheme: colorScheme,
                                  isDestructive: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _buildEmptyImagePlaceholder(
                        icon: Icons.add_a_photo_rounded,
                        label: 'Add main photo of the snag',
                        colorScheme: colorScheme,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Snag Details',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Location Field
            _buildTextField(
              controller: _locationController,
              focusNode: _locationFocus,
              label: 'Location / Room No.',
              hint: 'e.g., Kitchen, Bedroom 1, Bathroom',
              icon: Icons.location_on_rounded,
              required: true,
              colorScheme: colorScheme,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _titleFocus.requestFocus(),
            ),
            const SizedBox(height: 16),

            // Title Field
            _buildTextField(
              controller: _titleController,
              focusNode: _titleFocus,
              label: 'Title',
              hint: 'Brief description of the issue',
              icon: Icons.title_rounded,
              required: true,
              colorScheme: colorScheme,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _descriptionFocus.requestFocus(),
            ),
            const SizedBox(height: 16),

            // Description Field
            _buildTextField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              label: 'Detailed Description',
              hint: 'Provide more details about the snag...',
              icon: Icons.notes_rounded,
              required: false,
              colorScheme: colorScheme,
              maxLines: 4,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool required,
    required ColorScheme colorScheme,
    int maxLines = 1,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          textInputAction: textInputAction,
          textCapitalization: TextCapitalization.sentences,
          onFieldSubmitted: onSubmitted,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(icon, color: colorScheme.primary, size: 22),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: required
              ? (value) => value?.isEmpty ?? true ? 'Required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildSupportingImagesSection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: colorScheme.onSecondaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supporting Photos',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Add up to 3 additional photos',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSmallImagePicker(
                  image: _image2,
                  onPick: () => _pickSupportingImage(2),
                  onDelete: () => setState(() => _image2 = ''),
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallImagePicker(
                  image: _image3,
                  onPick: () => _pickSupportingImage(3),
                  onDelete: () => setState(() => _image3 = ''),
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallImagePicker(
                  image: _image4,
                  onPick: () => _pickSupportingImage(4),
                  onDelete: () => setState(() => _image4 = ''),
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallImagePicker({
    required String image,
    required VoidCallback onPick,
    required VoidCallback onDelete,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: image.isEmpty ? onPick : null,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: image.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildBase64Image(image),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 28,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrioritySection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: colorScheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Priority',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPriorityChip(
                  label: 'Low',
                  value: 0,
                  color: Colors.green,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityChip(
                  label: 'Medium',
                  value: 1,
                  color: Colors.orange,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityChip(
                  label: 'High',
                  value: 2,
                  color: Colors.red,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required int value,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _priority == value;
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_rounded,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateSection(ColorScheme colorScheme) {
    final cp = Provider.of<CP>(context, listen: false);
    final dateFormat = cp.getDateFormat();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Due Date',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DateTimeField(
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
            initialValue: _dueDate,
            onChanged: (date) => setState(() => _dueDate = date),
            decoration: InputDecoration(
              hintText: 'Select due date',
              hintStyle: GoogleFonts.inter(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(
                Icons.event_rounded,
                color: colorScheme.primary,
              ),
              suffixIcon: _dueDate != null
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.error),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
            format: DateFormat(dateFormat),
            onShowPicker: (context, currentValue) {
              return showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                initialDate: _dueDate ?? DateTime.now(),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: colorScheme,
                    ),
                    child: child!,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Snag',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Coming soon - Share the site first to assign',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
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
          // Image count indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.image_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_countImages()}/4',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Save Button
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveSnag,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Snag',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildEmptyImagePlaceholder({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 40,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Tap to add',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBase64Image(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildBrokenImagePlaceholder(),
      );
    } catch (e) {
      return _buildBrokenImagePlaceholder();
    }
  }

  Widget _buildBrokenImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
      ),
    );
  }

  // Image picking methods
  Future<void> _pickMainImage() async {
    final result = await _showImagePickerSheet();
    if (result != null) {
      setState(() => _mainImage = result);
    }
  }

  Future<void> _pickSupportingImage(int index) async {
    final result = await _showImagePickerSheet();
    if (result != null) {
      setState(() {
        switch (index) {
          case 2:
            _image2 = result;
            break;
          case 3:
            _image3 = result;
            break;
          case 4:
            _image4 = result;
            break;
        }
      });
    }
  }

  Future<String?> _showImagePickerSheet() async {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Photo',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                    colorScheme: colorScheme,
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                    colorScheme: colorScheme,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        if (mounted) {
          Navigator.pop(context, base64String);
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera/gallery permission required: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  int _countImages() {
    int count = 0;
    if (_mainImage.isNotEmpty) count++;
    if (_image2.isNotEmpty) count++;
    if (_image3.isNotEmpty) count++;
    if (_image4.isNotEmpty) count++;
    return count;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleBack() {
    if (_hasChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _hasChanges() {
    if (_isNewSnag) {
      return _locationController.text.isNotEmpty ||
          _titleController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _mainImage.isNotEmpty;
    }
    // For editing, check if values changed from original
    final snag = widget.snag!;
    return _locationController.text != (snag.location ?? '') ||
        _titleController.text != snag.title ||
        _descriptionController.text != (snag.description ?? '') ||
        _mainImage != (snag.imageMain1 ?? '') ||
        _priority != snag.priority;
  }

  Future<void> _saveSnag() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cp = Provider.of<CP>(context, listen: false);
      final appUser = cp.getAppUser()!;

      Snag snag;
      if (_isNewSnag) {
        snag = Snag(
          uID: const Uuid().v4(),
          siteUID: widget.siteID,
          ownerEmail: widget.siteOwnersEmail,
          creatorEmail: appUser.email.toLowerCase(),
          location: _locationController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          creationDate: DateTime.now(),
          imageMain1: _mainImage,
          image2: _image2,
          image3: _image3,
          image4: _image4,
          assignedEmail: _assignedEmail,
          assignedName: _assignedName,
          snagStatus: true,
          snagConfirmedStatus: true,
        );
        await cp.addSnag(snag);
      } else {
        snag = widget.snag!;
        snag.location = _locationController.text.trim();
        snag.title = _titleController.text.trim();
        snag.description = _descriptionController.text.trim();
        snag.priority = _priority;
        snag.dueDate = _dueDate;
        snag.imageMain1 = _mainImage;
        snag.image2 = _image2;
        snag.image3 = _image3;
        snag.image4 = _image4;
        snag.assignedEmail = _assignedEmail;
        snag.assignedName = _assignedName;
        await cp.updateSnag(snag);
      }

      if (mounted) {
        Navigator.pop(context, snag);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving snag: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving snag: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
