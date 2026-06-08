import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/services/site_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/Widgets/reusable_image_picker.dart';

/// Modern Create/Edit Site Screen with 2026 Design Trends
/// Features: Glassmorphism, Bento Grid, Micro-animations, Immersive Hero
class SiteInfoV2 extends StatefulWidget {
  const SiteInfoV2(this.site, {super.key});
  final Site? site;

  @override
  State<SiteInfoV2> createState() => _SiteInfoV2State();
}

class _SiteInfoV2State extends State<SiteInfoV2> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _heroAnimationController;
  late AnimationController _cardsAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _heroScale;
  late Animation<double> _cardsSlide;
  late Animation<double> _fabScale;
  late Animation<double> _pulseAnimation;

  // State
  Site? site;
  bool newSite = false;
  bool busy = false;
  double _scrollOffset = 0;

  // Form fields
  late int _btnPicQuality;
  Map<String, String> _assignedEmails = {};
  late String _siteImagePath;
  late String _siteId;
  late String _siteAddress;
  late String _siteName;
  late String _siteCompanyName;
  late String _siteContactPerson;
  late String _siteContactPhone;
  late String _siteReportTitle;
  late DateTime? _siteExpectedCompletion;

  // Text controllers for animations
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _contactPersonController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _reportTitleController;

  // Focus nodes for field animations
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _fieldFocused = {};

  final User _firebaseUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeControllers();
    _initializeFocusNodes();

    site = widget.site;
    if (site != null) {
      _loadValuesFromSite(site!);
    } else {
      _loadDefaults();
    }

    _scrollController.addListener(_onScroll);
    _startEntryAnimations();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _initializeAnimations() {
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _heroScale = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(parent: _heroAnimationController, curve: Curves.easeOutCubic),
    );
    _cardsSlide = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _cardsAnimationController, curve: Curves.easeOutCubic),
    );
    _fabScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _companyController = TextEditingController();
    _addressController = TextEditingController();
    _contactPersonController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _reportTitleController = TextEditingController();
  }

  void _initializeFocusNodes() {
    final fields = ['name', 'company', 'address', 'contact', 'phone', 'report'];
    for (final field in fields) {
      _focusNodes[field] = FocusNode();
      _fieldFocused[field] = false;
      _focusNodes[field]!.addListener(() {
        setState(() => _fieldFocused[field] = _focusNodes[field]!.hasFocus);
      });
    }
  }

  void _startEntryAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _heroAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _cardsAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _fabAnimationController.forward();
    });
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroAnimationController.dispose();
    _cardsAnimationController.dispose();
    _fabAnimationController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _reportTitleController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            // Background gradient mesh
            _buildBackgroundMesh(theme),

            // Main content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Hero image section
                SliverToBoxAdapter(
                  child: _buildHeroSection(theme, size, topPadding),
                ),

                // Form sections
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _cardsSlide,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _cardsSlide.value),
                        child: Opacity(
                          opacity: 1 - (_cardsSlide.value / 100),
                          child: child,
                        ),
                      );
                    },
                    child: _buildFormSections(theme),
                  ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),

            // Floating back button
            _buildFloatingBackButton(theme, topPadding),

            // Save FAB
            _buildSaveFab(theme),

            // Loading overlay
            if (busy) _buildLoadingOverlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundMesh(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.03),
              theme.colorScheme.surface,
              theme.colorScheme.secondary.withValues(alpha: 0.02),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme, Size size, double topPadding) {
    final heroHeight = size.height * 0.45;
    final parallaxOffset = _scrollOffset * 0.5;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background image with parallax
          AnimatedBuilder(
            animation: _heroScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _heroScale.value,
                child: Transform.translate(
                  offset: Offset(0, parallaxOffset),
                  child: child,
                ),
              );
            },
            child: _buildHeroImage(theme, heroHeight),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.5),
                    theme.colorScheme.surface,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Title overlay
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated chip
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          newSite ? Icons.add_rounded : Icons.edit_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          newSite ? 'NEW SITE' : 'EDIT SITE',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  newSite ? 'Create Your Site' : _siteName.isEmpty ? 'Edit Site' : _siteName,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Camera button
          Positioned(
            bottom: 40,
            right: 24,
            child: _buildCameraButton(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(ThemeData theme, double height) {
    if (_siteImagePath.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.primary.withValues(alpha: 0.4),
              theme.colorScheme.secondary.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Site Photo',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _resolveImagePath(_siteImagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            return Image.file(
              file,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          }
        }
        return Container(
          height: height,
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildCameraButton(ThemeData theme) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _siteImagePath.isEmpty ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _pickSiteImage,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            _siteImagePath.isEmpty ? Icons.camera_alt_rounded : Icons.edit_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBackButton(ThemeData theme, double topPadding) {
    final opacity = (1 - (_scrollOffset / 100)).clamp(0.0, 1.0);

    return Positioned(
      top: topPadding + 8,
      left: 16,
      child: Opacity(
        opacity: opacity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GestureDetector(
              onTap: _handleBackPressed,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSections(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Site Info Card (Bento style)
            _buildGlassCard(
              theme: theme,
              title: 'Site Info',
              icon: Icons.apartment_rounded,
              iconGradient: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.7),
              ],
              child: Column(
                children: [
                  _buildModernTextField(
                    theme: theme,
                    controller: _companyController,
                    label: 'Client Name',
                    hint: 'Enter client or company name',
                    icon: Icons.business_rounded,
                    focusKey: 'company',
                    isRequired: true,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value != null && value.isNotEmpty ? null : 'Client name is required',
                  ),
                  const SizedBox(height: 20),
                  _buildModernTextField(
                    theme: theme,
                    controller: _nameController,
                    label: 'Site Name',
                    hint: 'Enter a unique site name',
                    icon: Icons.location_city_rounded,
                    focusKey: 'name',
                    isRequired: true,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value != null && value.isNotEmpty ? null : 'Site name is required',
                  ),
                  const SizedBox(height: 20),
                  _buildModernTextField(
                    theme: theme,
                    controller: _reportTitleController,
                    label: 'Report Title',
                    hint: 'Custom title for PDF reports (optional)',
                    icon: Icons.description_outlined,
                    focusKey: 'report',
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ,.-]'))],
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Site Location Card
            _buildGlassCard(
              theme: theme,
              title: 'Site Location',
              icon: Icons.location_on_rounded,
              iconGradient: [
                Colors.orange,
                Colors.deepOrange,
              ],
              child: _buildModernTextField(
                theme: theme,
                controller: _addressController,
                label: 'Address',
                hint: 'Full site address or location description',
                icon: Icons.pin_drop_outlined,
                focusKey: 'address',
                keyboardType: TextInputType.streetAddress,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ,.-]'))],
                textCapitalization: TextCapitalization.words,
              ),
            ),

            const SizedBox(height: 16),

            // Site Contact Card
            _buildGlassCard(
              theme: theme,
              title: 'Site Contact',
              icon: Icons.contact_phone_rounded,
              iconGradient: [
                Colors.teal,
                Colors.teal.shade700,
              ],
              child: Column(
                children: [
                  _buildModernTextField(
                    theme: theme,
                    controller: _contactPersonController,
                    label: 'Contact Person',
                    hint: 'Primary contact name',
                    icon: Icons.person_outline_rounded,
                    focusKey: 'contact',
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 20),
                  _buildModernTextField(
                    theme: theme,
                    controller: _contactPhoneController,
                    label: 'Phone Number',
                    hint: 'Contact phone number',
                    icon: Icons.phone_outlined,
                    focusKey: 'phone',
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9+() -]'))],
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Site Completion Card
            _buildGlassCard(
              theme: theme,
              title: 'Site Completion',
              icon: Icons.event_available_rounded,
              iconGradient: [
                Colors.purple,
                Colors.purple.shade700,
              ],
              child: _buildDateSelector(theme),
            ),

            const SizedBox(height: 16),

            // Image Quality Card (full width)
            _buildGlassCard(
              theme: theme,
              title: 'Image Quality',
              icon: Icons.high_quality_rounded,
              iconGradient: [
                Colors.indigo,
                Colors.indigo.shade700,
              ],
              child: _buildQualitySelector(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required Widget child,
    bool compact = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: iconGradient,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String focusKey,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final isFocused = _fieldFocused[focusKey] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isFocused
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _siteExpectedCompletion ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          builder: (context, child) {
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: Colors.purple,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          HapticFeedback.selectionClick();
          setState(() => _siteExpectedCompletion = pickedDate);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: Colors.purple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected Date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _siteExpectedCompletion != null
                        ? DateFormat('dd MMM yyyy').format(_siteExpectedCompletion!)
                        : 'Tap to select',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _siteExpectedCompletion != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (_siteExpectedCompletion != null)
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _siteExpectedCompletion = null);
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySelector(ThemeData theme) {
    // Image quality settings affect PDF report output
    final qualities = [
      {'value': 0, 'label': 'Low', 'icon': Icons.compress_rounded, 'desc': 'Smaller files'},
      {'value': 1, 'label': 'Medium', 'icon': Icons.tune_rounded, 'desc': 'Recommended'},
      {'value': 2, 'label': 'High', 'icon': Icons.hd_rounded, 'desc': 'Best quality'},
    ];

    return Row(
      children: qualities.map((q) {
        final isSelected = _btnPicQuality == q['value'];
        final index = qualities.indexOf(q);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == 2 ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                FocusScope.of(context).unfocus();
                setState(() => _btnPicQuality = q['value'] as int);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.indigo,
                            Colors.indigo.shade700,
                          ],
                        )
                      : null,
                  color: isSelected ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.indigo.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      q['icon'] as IconData,
                      color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveFab(ThemeData theme) {
    return Positioned(
      bottom: 32,
      right: 20,
      left: 20,
      child: AnimatedBuilder(
        animation: _fabScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScale.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: busy ? null : _saveSite,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  newSite ? 'Create Site' : 'Save Changes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Saving...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============ Helper Methods ============

  Future<String> _resolveImagePath(String relativePath) async {
    if (relativePath.startsWith('/')) return relativePath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$relativePath';
    } catch (e) {
      return '';
    }
  }

  void _loadDefaults() {
    newSite = true;
    _siteImagePath = '';
    _siteId = getuID();
    _siteName = '';
    _siteCompanyName = '';
    _siteAddress = '';
    _siteContactPerson = '';
    _siteContactPhone = '';
    _siteReportTitle = '';
    _siteExpectedCompletion = null;
    _btnPicQuality = 1;
    _assignedEmails = {};

    // Initialize controllers
    _nameController.text = '';
    _companyController.text = '';
    _addressController.text = '';
    _contactPersonController.text = '';
    _contactPhoneController.text = '';
    _reportTitleController.text = '';
  }

  void _loadValuesFromSite(Site site) {
    newSite = false;
    _siteImagePath = site.imageLocalPath ?? '';
    _siteId = site.id;
    _siteName = site.name;
    _siteCompanyName = site.companyName ?? '';
    _siteAddress = site.address ?? '';
    _siteContactPerson = site.contactPerson ?? '';
    _siteContactPhone = site.contactPhone ?? '';
    _siteReportTitle = site.reportTitle ?? '';
    _siteExpectedCompletion = site.expectedCompletion;
    _btnPicQuality = site.pictureQuality;
    _assignedEmails = Map<String, String>.from(site.sharedWith);

    // Initialize controllers
    _nameController.text = _siteName;
    _companyController.text = _siteCompanyName;
    _addressController.text = _siteAddress;
    _contactPersonController.text = _siteContactPerson;
    _contactPhoneController.text = _siteContactPhone;
    _reportTitleController.text = _siteReportTitle;
  }

  Future<void> _handleBackPressed() async {
    HapticFeedback.lightImpact();

    // Clean up orphaned image for unsaved new site
    if (newSite && _siteImagePath.isNotEmpty) {
      final imageStorageService = ImageStorageService.instance;
      await imageStorageService.deleteSiteImage(_firebaseUser.uid, _siteId);
      await imageStorageService.deleteSiteDirectory(_firebaseUser.uid, _siteId);
      if (kDebugMode) {
        print('Cleaned up orphaned image for unsaved new site: $_siteId');
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickSiteImage() async {
    HapticFeedback.lightImpact();

    if (_siteImagePath.isNotEmpty) {
      ReusableImagePicker.showRemoveOnly(
        context: context,
        onImageRemoved: _removeSiteImage,
        removeItemName: 'Photo',
        removeItemDescription: 'Delete site photo',
      );
    } else {
      ReusableImagePicker.show(
        context: context,
        onImageSelected: (ImageSource source) => _processImageFromSource(source),
        removeItemName: 'Photo',
        removeItemDescription: 'Delete site photo',
        hasExistingImage: false,
      );
    }
  }

  Future<void> _processImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      setState(() => busy = true);

      final bytes = await pickedFile.readAsBytes();
      final compressionService = ImageCompressionService.instance;
      final result = await compressionService.processSiteImageFromBytes(bytes);

      final imageStorageService = ImageStorageService.instance;
      final siteId = site?.id ?? _siteId;
      final relativePath = await imageStorageService.saveSiteImageFromBytes(
        result.data,
        _firebaseUser.uid,
        siteId,
      );

      imageCache.clear();

      setState(() {
        _siteImagePath = relativePath;
        busy = false;
      });

      // Instant DB update for existing sites
      if (!newSite && site != null) {
        site = site!.copyWith(
          imageLocalPath: relativePath,
          imageFirebasePath: 'sites/${site!.ownerUID}/${site!.id}/site.jpg',
          needsImageSync: true,
          updatedAt: DateTime.now(),
        );
        await AppDatabase.instance.siteDao.updateSite(site!);
        if (kDebugMode) {
          print('Instant DB update: site image saved for existing site');
        }
      }

      HapticFeedback.heavyImpact();

      if (kDebugMode) {
        print('Site image saved: $relativePath');
        print('Compression: ${result.message}');
      }
    } on ImageTooLargeException catch (e) {
      _showErrorSnackBar(e.message);
      setState(() => busy = false);
    } on InvalidImageException catch (e) {
      _showErrorSnackBar(e.message);
      setState(() => busy = false);
    } catch (e) {
      if (kDebugMode) print('Error processing site image: $e');
      _showErrorSnackBar('Failed to process image. Please try again.');
      setState(() => busy = false);
    }
  }

  Future<void> _removeSiteImage() async {
    HapticFeedback.lightImpact();

    try {
      final imageStorageService = ImageStorageService.instance;
      final siteId = site?.id ?? _siteId;
      await imageStorageService.deleteSiteImage(_firebaseUser.uid, siteId);

      setState(() => _siteImagePath = '');

      // Instant DB update for existing sites
      if (!newSite && site != null) {
        site = site!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
          updatedAt: DateTime.now(),
        );
        await AppDatabase.instance.siteDao.updateSite(site!);
        if (kDebugMode) {
          print('Instant DB update: site image removed for existing site');
        }
      }

      if (kDebugMode) print('Site image removed');
    } catch (e) {
      if (kDebugMode) print('Error removing site image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _saveSite() async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    // Update field values from controllers
    _siteName = _nameController.text.trim();
    _siteCompanyName = _companyController.text.trim();
    _siteAddress = _addressController.text.trim();
    _siteContactPerson = _contactPersonController.text.trim();
    _siteContactPhone = _contactPhoneController.text.trim();
    _siteReportTitle = _reportTitleController.text.trim();

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (kDebugMode) print('Site - Form validated');

      final bool hasChanges = newSite ||
          _siteName != site!.name ||
          _siteCompanyName != (site!.companyName ?? '') ||
          _siteAddress != (site!.address ?? '') ||
          _siteContactPerson != (site!.contactPerson ?? '') ||
          _siteContactPhone != (site!.contactPhone ?? '') ||
          _siteReportTitle != (site!.reportTitle ?? '') ||
          _siteExpectedCompletion != site!.expectedCompletion ||
          _btnPicQuality != site!.pictureQuality ||
          !mapEquals(_assignedEmails, site!.sharedWith);

      if (hasChanges) {
        setState(() => busy = true);
        if (kDebugMode) print('Site - Create/Update initiated');

        try {
          final database = AppDatabase.instance;
          final siteService = SiteService(
            database: database,
            userEmail: _firebaseUser.email!,
            userUID: _firebaseUser.uid,
          );

          if (newSite) {
            await siteService.createSite(
              siteId: _siteId,
              name: _siteName,
              companyName: _siteCompanyName.isNotEmpty ? _siteCompanyName : null,
              address: _siteAddress.isNotEmpty ? _siteAddress : null,
              contactPerson: _siteContactPerson.isNotEmpty ? _siteContactPerson : null,
              contactPhone: _siteContactPhone.isNotEmpty ? _siteContactPhone : null,
              reportTitle: _siteReportTitle.isNotEmpty ? _siteReportTitle : null,
              expectedCompletion: _siteExpectedCompletion,
              pictureQuality: _btnPicQuality,
              imagePath: _siteImagePath.isNotEmpty ? _siteImagePath : null,
            );

            for (final entry in _assignedEmails.entries) {
              if (entry.key != _firebaseUser.email!.toLowerCase()) {
                await siteService.shareSiteWithUser(
                  siteId: _siteId,
                  userEmail: entry.key,
                  permission: entry.value,
                );
              }
            }

            if (kDebugMode) print('Site created successfully: $_siteId');
          } else {
            final updatedSite = site!.copyWith(
              name: _siteName,
              companyName: _siteCompanyName.isNotEmpty ? _siteCompanyName : null,
              address: _siteAddress.isNotEmpty ? _siteAddress : null,
              contactPerson: _siteContactPerson.isNotEmpty ? _siteContactPerson : null,
              contactPhone: _siteContactPhone.isNotEmpty ? _siteContactPhone : null,
              reportTitle: _siteReportTitle.isNotEmpty ? _siteReportTitle : null,
              expectedCompletion: _siteExpectedCompletion,
              pictureQuality: _btnPicQuality,
              imageLocalPath: _siteImagePath.isNotEmpty ? _siteImagePath : null,
              sharedWith: _assignedEmails,
              needsSiteSync: true,
              updatedAt: DateTime.now(),
            );

            await database.siteDao.updateSite(updatedSite);

            if (kDebugMode) print('Site updated locally: ${site!.id}, needsSync: true');
          }

          HapticFeedback.heavyImpact();
        } catch (e) {
          if (kDebugMode) print('Error saving site: $e');
          _showErrorSnackBar('Error saving Site, please try again');
          setState(() => busy = false);
          return;
        }
      }

      if (mounted) Navigator.pop(context);
    }
  }
}