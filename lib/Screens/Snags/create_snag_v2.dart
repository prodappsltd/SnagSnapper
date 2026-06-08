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
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/Data/models/image_slot.dart';
import 'package:snagsnapper/Data/models/priority_level.dart';
import 'package:snagsnapper/services/snag_image_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Modern CreateSnag screen with improved UX and visual design
/// This replaces the legacy CreateEditSnag.dart while keeping that file as backup
class CreateSnagV2 extends StatefulWidget {
  final Snag? snag;
  final String siteID;
  final String siteOwnersEmail;
  final String siteOwnerUID;

  const CreateSnagV2({
    super.key,
    required this.snag,
    required this.siteID,
    required this.siteOwnersEmail,
    required this.siteOwnerUID,
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
  final _assetController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Images - 6 slots using ImageSlot model (file-based, not base64)
  late List<ImageSlot> _images;
  late String _snagId; // Generated once for new snags, used for image paths

  // Other fields
  int _priority = 0; // Index into _priorities list
  List<PriorityLevel> _priorities = PriorityLevel.defaults;
  DateTime? _dueDate;
  String _assignedEmail = '';
  String _assignedName = '';

  // State
  bool _isNewSnag = true;
  bool _isSaving = false;
  bool _isOwner = false;

  // Focus nodes
  final _locationFocus = FocusNode();
  final _assetFocus = FocusNode();
  final _titleFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Initialize snagId - use existing or generate new
    _snagId = widget.snag?.id ?? const Uuid().v4();

    // Initialize images - 6 empty slots (will be populated in _initializeForm)
    _images = List.generate(6, (_) => ImageSlot.empty);

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

    // Load priorities from user's profile (or use defaults)
    if (appUser?.priorities != null && appUser!.priorities!.isNotEmpty) {
      _priorities = appUser.priorities!;
    } else {
      _priorities = PriorityLevel.defaults;
    }

    if (widget.snag != null) {
      _isNewSnag = false;
      final snag = widget.snag!;
      _locationController.text = snag.location ?? '';
      _assetController.text = snag.asset ?? '';
      _titleController.text = snag.title;
      _descriptionController.text = snag.description ?? '';
      // Load images from NEW model (List<ImageSlot>)
      _images = List.from(snag.images);
      _priority = _priorityCodeToIndex(snag.priority);
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
    _assetController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationFocus.dispose();
    _assetFocus.dispose();
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

          // Image Grid Section (6 slots)
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildImageGrid(colorScheme),
            ),
          ),

          // Form Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildFormSection(colorScheme),
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

  Widget _buildImageGrid(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Problem Photos',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Add up to 6 photos documenting the issue',
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
          // 2x3 Grid of image slots
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => _buildImageSlot(
              index: index,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSlot({
    required int index,
    required ColorScheme colorScheme,
  }) {
    final slot = _images[index];
    final hasImage = slot.hasImage;

    return GestureDetector(
      onTap: () => _pickImageForSlot(index),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildFileImage(slot.localPath!),
                    // Slot number badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImageFromSlot(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
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
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Build image from local file path
  Widget _buildFileImage(String relativePath) {
    return FutureBuilder<String>(
      future: _getAbsolutePath(relativePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final file = File(snapshot.data!);
        if (!file.existsSync()) {
          return _buildBrokenImagePlaceholder();
        }
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildBrokenImagePlaceholder(),
        );
      },
    );
  }

  Future<String> _getAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
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
            // SYNC: Firebase rules enforce max 200 chars. Update firestore.rules if changed.
            _buildTextField(
              controller: _locationController,
              focusNode: _locationFocus,
              label: 'Location',
              hint: 'e.g., Kitchen, Bedroom 1, Bathroom',
              icon: Icons.location_on_rounded,
              required: false,
              colorScheme: colorScheme,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _assetFocus.requestFocus(),
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // Asset Field
            // SYNC: Firebase rules enforce max 200 chars. Update firestore.rules if changed.
            _buildTextField(
              controller: _assetController,
              focusNode: _assetFocus,
              label: 'Asset / Room No.',
              hint: 'e.g., Boiler #123, Room 101, Window W-5',
              icon: Icons.inventory_2_rounded,
              required: false,
              colorScheme: colorScheme,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _descriptionFocus.requestFocus(),
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // Description Field (adaptive height, multiline)
            // SYNC: Firebase rules enforce max 5000 chars. Update firestore.rules if changed.
            _buildTextField(
              controller: _descriptionController,
              focusNode: _descriptionFocus,
              label: 'Description',
              hint: 'Describe the snag in detail...',
              icon: Icons.notes_rounded,
              required: false,
              colorScheme: colorScheme,
              maxLines: null, // Unlimited lines
              minLines: 3,
              maxLength: 5000,
              textInputAction: TextInputAction.newline, // Enter creates new line
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
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
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
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: maxLines == null ? TextInputType.multiline : TextInputType.text,
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

  Widget _buildPrioritySection(ColorScheme colorScheme) {
    final selectedPriority = _priorities.isNotEmpty && _priority < _priorities.length
        ? _priorities[_priority]
        : null;

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
          // Header
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

          // Segmented button bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Row(
                children: List.generate(_priorities.length, (index) {
                  return Expanded(
                    child: _buildPrioritySegment(
                      priority: _priorities[index],
                      index: index,
                      isFirst: index == 0,
                      isLast: index == _priorities.length - 1,
                      colorScheme: colorScheme,
                    ),
                  );
                }),
              ),
            ),
          ),

          // Description info box
          if (selectedPriority != null) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPriorityColor(_priority).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getPriorityColor(_priority).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: _getPriorityColor(_priority),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedPriority.description,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get color for priority based on severity index
  /// Index 0 = lowest severity (green), Index 4 = highest severity (red)
  Color _getPriorityColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF4CAF50); // Green - OK
      case 1:
        return const Color(0xFF8BC34A); // Light Green - OBS
      case 2:
        return const Color(0xFFFFC107); // Amber - CAT3
      case 3:
        return const Color(0xFFFF9800); // Orange - CAT2
      case 4:
        return const Color(0xFFF44336); // Red - CAT1
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  Widget _buildPrioritySegment({
    required PriorityLevel priority,
    required int index,
    required bool isFirst,
    required bool isLast,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _priority == index;
    final color = _getPriorityColor(index);

    return GestureDetector(
      onTap: () => setState(() => _priority = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : colorScheme.surfaceContainerHighest,
          border: Border(
            right: isLast
                ? BorderSide.none
                : BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
          ),
        ),
        child: Center(
          child: Text(
            priority.code,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : colorScheme.onSurface,
            ),
          ),
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
            // Display in local time (UTC midnight shows correct date in all timezones)
            initialValue: _dueDate?.toLocal(),
            // TIMEZONE: Normalize to UTC midnight for cross-timezone consistency
            onChanged: (date) => setState(() {
              _dueDate = date != null
                  ? DateTime.utc(date.year, date.month, date.day)
                  : null;
            }),
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
                initialDate: _dueDate?.toLocal() ?? DateTime.now(),
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
                  '${_countImages()}/6',
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

  Widget _buildBrokenImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
      ),
    );
  }

  // Image picking methods using SnagImageService
  Future<void> _pickImageForSlot(int index) async {
    final source = await _showImageSourceSheet();
    if (source == null || !mounted) return;

    try {
      final cp = Provider.of<CP>(context, listen: false);
      final appUser = cp.getAppUser();
      if (appUser == null) return;

      final snagImageService = SnagImageService.instance;

      // For NEW snags + Gallery: use multi-pick to fill available slots
      if (_isNewSnag && source == ImageSource.gallery) {
        final results = await snagImageService.pickMultipleImages(
          userId: appUser.id,
          siteId: widget.siteID,
          snagId: _snagId,
          ownerUID: widget.siteOwnerUID,
          currentSlots: _images,
          isFix: false,
        );

        if (results.isNotEmpty && mounted) {
          setState(() {
            for (final (slotIndex, slot) in results) {
              _images[slotIndex] = slot;
            }
          });
        }
        return;
      }

      // For EXISTING snags or Camera: single pick
      final updatedSlot = await snagImageService.pickImage(
        source: source,
        snag: widget.snag, // null for new snag, existing for edit
        slotIndex: index,
        isFix: false, // Problem photos, not fix photos
        userId: appUser.id,
        siteId: widget.siteID,
        snagId: _snagId,
        ownerUID: widget.siteOwnerUID, // TODO: Should be ownerUID, not email
      );

      if (updatedSlot != null && mounted) {
        setState(() {
          _images[index] = updatedSlot;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeImageFromSlot(int index) async {
    try {
      final snagImageService = SnagImageService.instance;
      final updatedSlot = await snagImageService.removeImage(
        snag: widget.snag,
        slotIndex: index,
        isFix: false,
      );

      if (mounted) {
        setState(() {
          _images[index] = updatedSlot;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error removing image: $e');
    }
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<ImageSource>(
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
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                    colorScheme: colorScheme,
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
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

  int _countImages() {
    return _images.where((slot) => slot.hasImage).length;
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
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Cleanup orphan images for NEW snag before navigating away
                await _cleanupOrphanImagesIfNeeded();

                if (mounted) Navigator.pop(context); // Close screen
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

  /// Cleanup orphan image files for NEW snags that were never saved.
  /// Only needed for NEW snags - EXISTING snags use instant DB operations.
  Future<void> _cleanupOrphanImagesIfNeeded() async {
    // Only cleanup for NEW snags with images
    if (!_isNewSnag) {
      if (kDebugMode) {
        print('CreateSnagV2: Skip cleanup - editing existing snag');
      }
      return;
    }

    final hasImages = _images.any((slot) => slot.hasImage);
    if (!hasImages) {
      if (kDebugMode) {
        print('CreateSnagV2: Skip cleanup - no images to cleanup');
      }
      return;
    }

    try {
      final appUser = Provider.of<CP>(context, listen: false).getAppUser();
      if (appUser == null) {
        if (kDebugMode) {
          print('CreateSnagV2: Skip cleanup - no user');
        }
        return;
      }

      if (kDebugMode) {
        print('CreateSnagV2: Cleaning up orphan images for unsaved snag $_snagId');
        print('  - userId: ${appUser.id}');
        print('  - siteId: ${widget.siteID}');
        print('  - images to cleanup: ${_images.where((s) => s.hasImage).length}');
      }

      await SnagImageService.instance.cleanupOrphanedImages(
        userId: appUser.id,
        siteId: widget.siteID,
        snagId: _snagId,
      );

      if (kDebugMode) {
        print('CreateSnagV2: Orphan image cleanup complete');
      }
    } catch (e) {
      // Don't block navigation on cleanup failure
      if (kDebugMode) {
        print('CreateSnagV2: Error cleaning up orphan images: $e');
      }
    }
  }

  bool _hasChanges() {
    if (_isNewSnag) {
      return _locationController.text.isNotEmpty ||
          _assetController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _images.any((slot) => slot.hasImage);
    }
    // For editing, check if values changed from original
    final snag = widget.snag!;
    // Check if any image slot changed
    bool imagesChanged = false;
    for (int i = 0; i < 6; i++) {
      if (_images[i].localPath != snag.images[i].localPath) {
        imagesChanged = true;
        break;
      }
    }
    return _locationController.text != (snag.location ?? '') ||
        _assetController.text != (snag.asset ?? '') ||
        _descriptionController.text != (snag.description ?? '') ||
        _priority != _priorityCodeToIndex(snag.priority) ||
        imagesChanged;
  }

  Future<void> _saveSnag() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final database = AppDatabase.instance;
      final snagDao = database.snagDao;

      // Get AppUser for creator email
      final appUser = Provider.of<CP>(context, listen: false).getAppUser();
      if (appUser == null) {
        throw Exception('User not logged in');
      }

      // Get Site to obtain correct ownerUID
      final site = await database.siteDao.getSiteById(widget.siteID);
      if (site == null) {
        throw Exception('Site not found');
      }

      final now = DateTime.now();

      // Title field is unused - always empty
      // SYNC: Firebase rules enforce title.size() == 0. Update firestore.rules if changed.
      const String title = '';

      if (_isNewSnag) {
        // === NEW SNAG: Insert with images from UI state ===
        final snag = Snag(
          id: _snagId,
          siteUID: widget.siteID,
          ownerEmail: site.ownerEmail,
          creatorEmail: appUser.email,
          title: title,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          asset: _assetController.text.isEmpty ? null : _assetController.text,
          priority: _indexToPriorityCode(_priority),
          dueDate: _dueDate,
          creationDate: now,
          images: _images, // Include images from UI state
          fixImages: ImageSlot.emptyList(),
          snagStatus: true, // Open
          snagConfirmedStatus: true, // Pending
          needsSnagSync: true, // Mark for Firebase sync
          needsImagesSync: _images.any((s) => s.needsSync),
          localVersion: 1,
          firebaseVersion: 0,
          createdAt: now,
          updatedAt: now,
        );

        await snagDao.insertSnag(snag);

        if (kDebugMode) {
          print('CreateSnagV2: Created new snag $_snagId');
          print('  - Images: ${_images.where((s) => s.hasImage).length}');
          print('  - needsSnagSync: true, needsImagesSync: ${snag.needsImagesSync}');
        }
      } else {
        // === EXISTING SNAG: Update text fields only (images are instant) ===
        // Fetch current snag from DB to preserve latest image state
        final currentSnag = await snagDao.getSnagById(_snagId);
        if (currentSnag == null) {
          throw Exception('Snag not found');
        }

        // Apply text field changes (images preserved from DB)
        final updatedSnag = currentSnag.copyWith(
          title: title,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          asset: _assetController.text.isEmpty ? null : _assetController.text,
          priority: _indexToPriorityCode(_priority),
          dueDate: _dueDate,
          // Note: updateSnag() handles localVersion++, updatedAt, needsSnagSync
        );

        await snagDao.updateSnag(updatedSnag);

        if (kDebugMode) {
          print('CreateSnagV2: Updated existing snag $_snagId');
          print('  - Images preserved: ${currentSnag.imageCount}');
        }
      }

      if (mounted) {
        Navigator.pop(context);
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

  // ============== Priority Helpers ==============

  /// Convert priority code (e.g., "CAT1") to UI index (0-4)
  /// Uses loaded _priorities from user's profile
  int _priorityCodeToIndex(String? code) {
    if (code == null || code.isEmpty) return 0;
    final index = _priorities.indexWhere((p) => p.code == code);
    return index >= 0 ? index : 0;
  }

  /// Convert UI index (0-4) to priority code (e.g., "CAT1")
  /// Uses loaded _priorities from user's profile
  String _indexToPriorityCode(int index) {
    if (index >= 0 && index < _priorities.length) {
      return _priorities[index].code;
    }
    return _priorities.isNotEmpty ? _priorities[0].code : 'OK';
  }
}
