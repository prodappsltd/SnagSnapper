import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/Data/models/priority_level.dart';
import 'package:snagsnapper/Screens/Snags/create_snag_v2.dart';

/// Simplified Snag Detail View
///
/// TODO: M7 Migration - This is a temporary simplified version
/// Full migration needed:
/// - Display images from snag.images[0-5] using file-based ImageSlot
/// - Display fix images from snag.fixImages[0-5]
/// - Update snag status using SnagDao (immutable model)
/// - Add image viewer for file-based images
class SnagDetailedView extends StatefulWidget {
  final Snag snag;
  final String siteID;
  final String siteOwnersEmail;
  final String siteOwnerUID;

  const SnagDetailedView({
    Key? key,
    required this.snag,
    required this.siteID,
    required this.siteOwnersEmail,
    required this.siteOwnerUID,
  }) : super(key: key);

  @override
  State<SnagDetailedView> createState() => _SnagDetailedViewState();
}

class _SnagDetailedViewState extends State<SnagDetailedView> {
  late Snag _snag;

  @override
  void initState() {
    super.initState();
    _snag = widget.snag;
  }

  void _refreshSnag() async {
    final updated = await AppDatabase.instance.snagDao.getSnagById(_snag.id);
    if (updated != null && mounted) {
      setState(() => _snag = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cp = Provider.of<CP>(context, listen: false);
    final appUser = cp.getAppUser();

    final isOwner = _snag.ownerEmail.toLowerCase() == appUser?.email.toLowerCase();
    final isCreator = _snag.creatorEmail.toLowerCase() == appUser?.email.toLowerCase();
    final isAssignee = _snag.assignedEmail?.toLowerCase() == appUser?.email.toLowerCase();
    final canEdit = (isCreator && (_snag.assignedEmail?.isEmpty ?? true)) || isOwner;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          title: Text(
            'SNAG DETAILS',
            style: GoogleFonts.montserrat(
              textStyle: TextStyle(color: colorScheme.onBackground),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: colorScheme.onBackground,
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateSnagV2(
                        snag: _snag,
                        siteID: widget.siteID,
                        siteOwnersEmail: widget.siteOwnersEmail,
                        siteOwnerUID: widget.siteOwnerUID,
                      ),
                    ),
                  ).then((_) => _refreshSnag());
                },
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image placeholder
              _buildImagePlaceholder(colorScheme),
              const SizedBox(height: 16),

              // Status card
              _buildStatusCard(colorScheme, cp),
              const SizedBox(height: 16),

              // Details card
              _buildDetailsCard(colorScheme, cp),
              const SizedBox(height: 16),

              // Fix section placeholder
              if (isAssignee || isOwner)
                _buildFixSectionPlaceholder(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    final hasImage = _snag.images.isNotEmpty && _snag.images[0].hasImage;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasImage ? Icons.image : Icons.image_not_supported,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              hasImage
                ? 'TODO: Display ${_snag.images.where((s) => s.hasImage).length} image(s)'
                : 'No images',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (kDebugMode && hasImage)
              Text(
                'Path: ${_snag.images[0].localPath}',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme, CP cp) {
    final isClosed = !_snag.snagConfirmedStatus && !_snag.snagStatus;
    final isPendingReview = _snag.snagConfirmedStatus && !_snag.snagStatus;

    Color statusColor = colorScheme.primary;
    String statusText = 'Open';
    if (isClosed) {
      statusColor = Colors.green;
      statusText = 'Closed';
    } else if (isPendingReview) {
      statusColor = Colors.amber;
      statusText = 'Pending Review';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _snag.location ?? 'No location',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  Icons.person,
                  _snag.assignedName?.isNotEmpty == true
                      ? _snag.assignedName!
                      : 'Unassigned',
                  colorScheme,
                ),
                _buildInfoItem(
                  Icons.flag,
                  _getPriorityLabel(_snag.priority),
                  colorScheme,
                  color: _getPriorityColor(_snag.priority),
                ),
                _buildInfoItem(
                  Icons.calendar_today,
                  _snag.dueDate != null
                      // TIMEZONE: Display UTC midnight as local date
                      ? DateFormat(cp.getDateFormat()).format(_snag.dueDate!.toLocal())
                      : 'No due date',
                  colorScheme,
                  color: _getDueDateColor(_snag.dueDate, cp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, ColorScheme colorScheme, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(ColorScheme colorScheme, CP cp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Title', _snag.title.isEmpty ? 'No title' : _snag.title),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Description',
              _snag.description?.isEmpty ?? true ? 'No description' : _snag.description!,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Created',
              DateFormat(cp.getDateFormat()).format(_snag.creationDate),
            ),
            if (kDebugMode) ...[
              const Divider(),
              _buildDetailRow('Owner', _snag.ownerEmail),
              _buildDetailRow('Creator', _snag.creatorEmail),
              _buildDetailRow('ID', _snag.id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildFixSectionPlaceholder(ColorScheme colorScheme) {
    final hasFixImages = _snag.fixImages.any((s) => s.hasImage);

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Fix Section',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'TODO: Migrate fix section to use NEW Snag model',
              style: TextStyle(color: Colors.amber.shade800),
            ),
            if (_snag.snagFixDescription?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Fix description: ${_snag.snagFixDescription}',
                  style: TextStyle(color: Colors.amber.shade900),
                ),
              ),
            if (hasFixImages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Fix images: ${_snag.fixImages.where((s) => s.hasImage).length}',
                  style: TextStyle(color: Colors.amber.shade900),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get label for priority code (e.g., "CAT1" -> "CAT1")
  /// Returns the code itself for display, or "None" if not set
  String _getPriorityLabel(String? priority) {
    if (priority == null || priority.isEmpty) return 'None';
    return priority;
  }

  /// Get color for priority code based on severity
  /// Maps priority codes to colors (higher severity = warmer colors)
  Color _getPriorityColor(String? priority) {
    if (priority == null || priority.isEmpty) return Colors.grey;

    // Find priority in defaults to determine color based on index (severity)
    final index = PriorityLevel.defaults.indexWhere((p) => p.code == priority);
    switch (index) {
      case 0: return Colors.green;     // OK - no action required
      case 1: return Colors.blue;      // OBS - observation
      case 2: return Colors.orange;    // CAT3 - improvement required
      case 3: return Colors.deepOrange; // CAT2 - potentially dangerous
      case 4: return Colors.red;       // CAT1 - significant risk
      default: return Colors.grey;
    }
  }

  // TIMEZONE: Convert UTC midnight to local for comparison
  Color? _getDueDateColor(DateTime? dueDate, CP cp) {
    if (dueDate == null) return null;
    final daysLeft = dueDate.toLocal().difference(DateTime.now()).inDays;
    if (daysLeft >= cp.greenCondition) return Colors.green;
    if (daysLeft >= cp.orangeCondition) return Colors.orange;
    return Colors.red;
  }
}
