import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/Data/models/priority_level.dart';
// import 'package:snagsnapper/Screens/Sites/SiteInfo/siteInfo.dart'; // BACKUP - legacy UI
import 'package:snagsnapper/Screens/Sites/SiteInfo/site_info_v2.dart';
// import 'package:snagsnapper/Screens/Snags/CreateEditSnag.dart'; // BACKUP - legacy UI
import 'package:snagsnapper/Screens/Snags/create_snag_v2.dart';
import 'package:snagsnapper/Widgets/share_site_dialog.dart';

/// Modern SiteStatus screen with improved UX and visual design
/// This replaces the legacy siteStatus.dart while keeping that file as backup
class SiteStatusV2 extends StatefulWidget {
  final Site site;
  const SiteStatusV2({super.key, required this.site});

  @override
  State<SiteStatusV2> createState() => _SiteStatusV2State();
}

class _SiteStatusV2State extends State<SiteStatusV2>
    with SingleTickerProviderStateMixin {
  // Filter options
  static const String ALL = 'All';
  static const String OPEN = 'Open';
  static const String CLOSED = 'Closed';
  static const String UNASSIGNED = 'Unassigned';
  static const String FOR_REVIEW = 'Review';
  static const String ASSIGNED = 'Assigned';

  final List<String> _filters = [ALL, OPEN, CLOSED, UNASSIGNED, FOR_REVIEW, ASSIGNED];
  String _selectedFilter = ALL;

  List<Snag> _allSnags = [];
  List<Snag> _displaySnags = [];

  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isOwner = false;
  bool _viewAccess = false;

  // Snag counters
  Map<String, int> _counters = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSnags();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadSnags() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final appUser = Provider.of<CP>(context, listen: false).getAppUser();
    _isOwner = widget.site.ownerEmail.toLowerCase() == user.email!.toLowerCase();
    _viewAccess = widget.site.sharedWith[appUser?.email.toLowerCase()] == 'VIEW';

    // Load snags from SnagDao
    final snags = await AppDatabase.instance.snagDao.getSnagsBySite(widget.site.id);
    if (!mounted) return;

    setState(() {
      _allSnags = snags;
      _calculateCounters();
      _filterSnags(_selectedFilter);
    });
  }

  void _calculateCounters() {
    _counters = {
      ALL: _allSnags.length,
      OPEN: _allSnags.where((s) => s.snagConfirmedStatus).length,
      CLOSED: _allSnags.where((s) => !s.snagConfirmedStatus && !s.snagStatus).length,
      UNASSIGNED: _allSnags.where((s) => s.assignedEmail?.isEmpty ?? true).length,
      FOR_REVIEW: _allSnags.where((s) => s.snagConfirmedStatus && !s.snagStatus).length,
      ASSIGNED: _allSnags.where((s) => s.assignedEmail?.isNotEmpty ?? false).length,
    };
  }

  void _filterSnags(String filter) {
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case ALL:
          _displaySnags = List.from(_allSnags);
          break;
        case OPEN:
          _displaySnags = _allSnags.where((s) => s.snagConfirmedStatus).toList();
          break;
        case CLOSED:
          _displaySnags = _allSnags.where((s) => !s.snagConfirmedStatus && !s.snagStatus).toList();
          break;
        case UNASSIGNED:
          _displaySnags = _allSnags.where((s) => s.assignedEmail?.isEmpty ?? true).toList();
          break;
        case FOR_REVIEW:
          _displaySnags = _allSnags.where((s) => s.snagConfirmedStatus && !s.snagStatus).toList();
          break;
        case ASSIGNED:
          _displaySnags = _allSnags.where((s) => s.assignedEmail?.isNotEmpty ?? false).toList();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Hero Header with Site Image
          _buildSliverHeader(colorScheme),

          // Stats Dashboard
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildStatsDashboard(colorScheme),
            ),
          ),

          // Filter Chips
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              filters: _filters,
              selectedFilter: _selectedFilter,
              counters: _counters,
              onFilterChanged: _filterSnags,
              colorScheme: colorScheme,
            ),
          ),

          // Snags List
          _displaySnags.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,  // Prevents overflow when keyboard appears
                  child: _buildEmptyState(colorScheme),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.1 * (index % 5)),
                              end: Offset.zero,
                            ).animate(_fadeAnimation),
                            child: _buildSnagCard(_displaySnags[index], colorScheme),
                          ),
                        );
                      },
                      childCount: _displaySnags.length,
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: _viewAccess
          ? null
          : _buildFAB(colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSliverHeader(ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: _buildBackButton(colorScheme),
      actions: [
        if (_isOwner) _buildShareButton(colorScheme),
        if (_isOwner) _buildEditButton(colorScheme),
        if (_isOwner) _buildMoreButton(colorScheme),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image - handles both absolute and relative paths
            _SiteHeaderImage(
              imageLocalPath: widget.site.imageLocalPath,
              colorScheme: colorScheme,
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // Site Info Overlay
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Site Name
                  Text(
                    widget.site.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Company/Client Name
                  if (widget.site.companyName?.isNotEmpty ?? false)
                    Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.site.companyName!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 4),

                  // Address
                  if (widget.site.address?.isNotEmpty ?? false)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.site.address!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildShareButton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.people_alt_rounded, size: 20),
        color: Colors.white,
        onPressed: () => _showShareSheet(),
      ),
    );
  }

  void _showShareSheet() async {
    // Fetch latest site data from database to ensure sharedWith is current
    final currentSite = await AppDatabase.instance.siteDao.getSiteById(widget.site.id);
    if (currentSite == null || !mounted) return;

    final newSharedWith = await showShareSiteSheet(
      context: context,
      site: currentSite,
    );

    // If user saved changes
    if (newSharedWith != null) {
      // Update the site with new sharing permissions
      final updatedSite = currentSite.copyWith(
        sharedWith: newSharedWith,
        needsSiteSync: true,
        updatedAt: DateTime.now(),
      );

      // Save to database
      await AppDatabase.instance.siteDao.updateSite(updatedSite);

      if (kDebugMode) {
        print('SiteStatusV2: Updated site sharing - ${newSharedWith.length} collaborators');
      }

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing updated - ${newSharedWith.length} collaborator${newSharedWith.length == 1 ? '' : 's'}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildEditButton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.edit_rounded, size: 20),
        color: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SiteInfoV2(widget.site)),
          ).then((_) => _loadSnags());
        },
      ),
    );
  }

  Widget _buildMoreButton(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        color: Colors.white,
        onPressed: () => _showActionsSheet(colorScheme),
      ),
    );
  }

  Widget _buildStatsDashboard(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.list_alt_rounded,
            label: 'Total',
            value: _counters[ALL] ?? 0,
            color: colorScheme.primary,
            colorScheme: colorScheme,
          ),
          _buildStatDivider(colorScheme),
          _buildStatItem(
            icon: Icons.pending_actions_rounded,
            label: 'Open',
            value: _counters[OPEN] ?? 0,
            color: Colors.orange,
            colorScheme: colorScheme,
          ),
          _buildStatDivider(colorScheme),
          _buildStatItem(
            icon: Icons.rate_review_rounded,
            label: 'Review',
            value: _counters[FOR_REVIEW] ?? 0,
            color: Colors.amber.shade700,
            colorScheme: colorScheme,
          ),
          _buildStatDivider(colorScheme),
          _buildStatItem(
            icon: Icons.check_circle_rounded,
            label: 'Closed',
            value: _counters[CLOSED] ?? 0,
            color: Colors.green,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(ColorScheme colorScheme) {
    return Container(
      height: 40,
      width: 1,
      color: colorScheme.outlineVariant.withOpacity(0.5),
    );
  }

  Widget _buildSnagCard(Snag snag, ColorScheme colorScheme) {
    final isAssignedToMe = snag.assignedEmail?.toLowerCase() ==
        Provider.of<CP>(context, listen: false).getAppUser()?.email.toLowerCase();
    final isClosed = !snag.snagConfirmedStatus && !snag.snagStatus;
    final isForReview = snag.snagConfirmedStatus && !snag.snagStatus;

    // Priority color based on code
    Color priorityColor = Colors.grey;
    String priorityLabel = snag.priority ?? 'None';
    final priorityCode = snag.priority;
    if (priorityCode != null) {
      // Find priority in defaults to determine color based on severity
      final index = PriorityLevel.defaults.indexWhere((p) => p.code == priorityCode);
      switch (index) {
        case 0: priorityColor = Colors.green; break;      // OK
        case 1: priorityColor = Colors.blue; break;       // OBS
        case 2: priorityColor = Colors.orange; break;     // CAT3
        case 3: priorityColor = Colors.deepOrange; break; // CAT2
        case 4: priorityColor = Colors.red; break;        // CAT1
        default: priorityColor = Colors.grey;
      }
    }

    // Due date status
    // TIMEZONE: Convert UTC midnight to local for comparison
    Color? dueDateColor;
    if (!isClosed && snag.dueDate != null) {
      final daysUntilDue = snag.dueDate!.toLocal().difference(DateTime.now()).inDays;
      final cp = Provider.of<CP>(context, listen: false);
      if (daysUntilDue >= cp.greenCondition) {
        dueDateColor = Colors.green;
      } else if (daysUntilDue >= cp.orangeCondition) {
        dueDateColor = Colors.orange;
      } else {
        dueDateColor = Colors.red;
      }
    }

    return Dismissible(
      key: Key(snag.id),
      direction: _viewAccess ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => _confirmDeleteSnag(snag, colorScheme),
      onDismissed: (_) => _deleteSnag(snag),
      child: GestureDetector(
        onTap: () => _openSnagDetail(snag),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isForReview
                  ? Colors.amber.withOpacity(0.5)
                  : colorScheme.outlineVariant.withOpacity(0.3),
              width: isForReview ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                // Snag Image
                SizedBox(
                  width: 100,
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSnagImage(snag, colorScheme),
                      if (isClosed)
                        Container(
                          color: Colors.green.withOpacity(0.3),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Snag Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                snag.location ?? 'No location',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Due Date
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: dueDateColor ?? colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              snag.dueDate != null
                                  ? _formatDate(snag.dueDate!)
                                  : 'No due date',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: dueDateColor ?? colorScheme.onSurfaceVariant,
                                fontWeight: dueDateColor != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Bottom Row: Assignee & Priority
                        Row(
                          children: [
                            // Assignee
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 14,
                                    color: isAssignedToMe
                                        ? Colors.green
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      snag.assignedName?.isNotEmpty ?? false
                                          ? snag.assignedName!
                                          : 'Unassigned',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isAssignedToMe
                                            ? Colors.green
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: isAssignedToMe
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Priority Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 12,
                                    color: priorityColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    priorityLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: priorityColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Status Indicator Strip
                Container(
                  width: 6,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isClosed
                        ? Colors.green
                        : isForReview
                            ? Colors.amber
                            : dueDateColor ?? colorScheme.outlineVariant,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnagImage(Snag snag, ColorScheme colorScheme) {
    // Check if first image slot has an image (NEW model uses file-based images)
    final firstSlot = snag.images.isNotEmpty ? snag.images[0] : null;
    if (firstSlot == null || !firstSlot.hasImage) {
      return _buildPlaceholderImage(colorScheme);
    }

    // Load image from local file path
    return FutureBuilder<String>(
      future: _getAbsolutePath(firstSlot.localPath!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildPlaceholderImage(colorScheme);
        }
        final file = File(snapshot.data!);
        if (!file.existsSync()) {
          return _buildPlaceholderImage(colorScheme);
        }
        return Image.file(file, fit: BoxFit.cover);
      },
    );
  }

  Future<String> _getAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  Widget _buildPlaceholderImage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_rounded,
          size: 32,
          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,  // Don't expand to fill available space
          children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: colorScheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedFilter == ALL
                ? 'No snags yet'
                : 'No $_selectedFilter snags',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == ALL
                ? 'Tap + to add your first snag'
                : 'Try selecting a different filter',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFAB(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: _createNewSnag,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Add Snag',
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showActionsSheet(ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Site Actions',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              _buildActionTile(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Create Report',
                subtitle: 'Generate PDF report',
                color: colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  _showReportOptions(colorScheme);
                },
              ),
              _buildActionTile(
                icon: Icons.color_lens_rounded,
                label: 'Report Color',
                subtitle: 'Customize report theme',
                color: Provider.of<CP>(context).getPDFColor(),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show color picker
                },
              ),
              _buildActionTile(
                icon: Icons.history_rounded,
                label: 'Past Reports',
                subtitle: 'View generated reports',
                color: colorScheme.secondary,
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show past reports
                },
              ),
              const Divider(height: 32),
              _buildActionTile(
                icon: Icons.delete_rounded,
                label: 'Delete Site',
                subtitle: 'This cannot be undone',
                color: colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSite(colorScheme);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: color == Theme.of(context).colorScheme.error ? color : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  void _showReportOptions(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create Report',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('All Snags', 0, colorScheme),
            _buildReportOption('Open Snags', 1, colorScheme),
            _buildReportOption('Closed Snags', 2, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String label, int value, ColorScheme colorScheme) {
    return ListTile(
      title: Text(label),
      leading: Icon(
        value == 0
            ? Icons.list_rounded
            : value == 1
                ? Icons.pending_actions_rounded
                : Icons.check_circle_rounded,
        color: colorScheme.primary,
      ),
      onTap: () {
        Navigator.pop(context);
        // TODO: Generate report
        if (kDebugMode) print('Generate report for: $label');
      },
    );
  }

  void _confirmDeleteSite(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            Text(
              'Delete Site',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.site.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete site via SiteDao
              if (kDebugMode) print('Delete site disabled - pending migration');
              Navigator.popUntil(context, ModalRoute.withName('/mySites'));
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeleteSnag(Snag snag, ColorScheme colorScheme) {
    final appUser = Provider.of<CP>(context, listen: false).getAppUser();
    final isAssigned = snag.assignedEmail?.isNotEmpty ?? false;
    final isOwner = snag.ownerEmail.toLowerCase() == appUser?.email.toLowerCase();

    if (_viewAccess || (isAssigned && !isOwner)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Not Allowed'),
          content: Text(
            _viewAccess
                ? 'View access does not allow deleting snags.'
                : 'You cannot delete snags that are already assigned.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return Future.value(false);
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete Snag'),
          ],
        ),
        content: const Text('Are you sure you want to delete this snag?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSnag(Snag snag) async {
    // Delete via SnagDao (sync handler will delete from Firebase)
    await AppDatabase.instance.snagDao.deleteSnag(snag.id);
    setState(() {
      _allSnags.removeWhere((s) => s.id == snag.id);
      _displaySnags.removeWhere((s) => s.id == snag.id);
      _calculateCounters();
    });
  }

  void _openSnagDetail(Snag snag) {
    // Navigate directly to edit screen (skip intermediate detail view)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSnagV2(
          snag: snag,
          siteID: widget.site.id,
          siteOwnersEmail: widget.site.ownerEmail,
          siteOwnerUID: widget.site.ownerUID,
        ),
      ),
    ).then((_) => _loadSnags());
  }

  void _createNewSnag() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSnagV2(
          snag: null,
          siteID: widget.site.id,
          siteOwnersEmail: widget.site.ownerEmail,
          siteOwnerUID: widget.site.ownerUID,
        ),
      ),
    ).then((_) => _loadSnags());
  }

  // TIMEZONE: Convert UTC midnight to local for display
  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = localDate.difference(now).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';

    // Format based on user preference
    final cp = Provider.of<CP>(context, listen: false);
    final dateFormat = cp.getDateFormat();
    if (dateFormat.contains('MM-dd')) {
      return '${localDate.month}/${localDate.day}/${localDate.year}';
    }
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }
}

/// Sticky header delegate for filter chips
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> filters;
  final String selectedFilter;
  final Map<String, int> counters;
  final Function(String) onFilterChanged;
  final ColorScheme colorScheme;

  _FilterHeaderDelegate({
    required this.filters,
    required this.selectedFilter,
    required this.counters,
    required this.onFilterChanged,
    required this.colorScheme,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return selectedFilter != oldDelegate.selectedFilter ||
        counters != oldDelegate.counters;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = filter == selectedFilter;
                final count = counters[filter] ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(filter),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.onPrimary.withOpacity(0.2)
                                  : colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selectedColor: colorScheme.primary,
                    checkmarkColor: colorScheme.onPrimary,
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) => onFilterChanged(filter),
                  ),
                );
              },
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

/// Widget for loading site header image from local file path
/// Handles both absolute and relative paths
class _SiteHeaderImage extends StatelessWidget {
  final String? imageLocalPath;
  final ColorScheme colorScheme;

  const _SiteHeaderImage({
    required this.imageLocalPath,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (imageLocalPath == null || imageLocalPath!.isEmpty) {
      return _buildPlaceholder();
    }

    // If it's an absolute path, use directly
    if (imageLocalPath!.startsWith('/')) {
      final file = File(imageLocalPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return _buildPlaceholder();
    }

    // For relative paths, resolve from app documents directory
    return FutureBuilder<String>(
      future: _resolveRelativePath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            return Image.file(file, fit: BoxFit.cover);
          }
        }
        return _buildPlaceholder();
      },
    );
  }

  Future<String> _resolveRelativePath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, imageLocalPath!);
    } catch (e) {
      return '';
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.domain_rounded,
          size: 80,
          color: colorScheme.onPrimaryContainer.withOpacity(0.3),
        ),
      ),
    );
  }
}