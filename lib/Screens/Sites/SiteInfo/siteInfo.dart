import 'package:firebase_auth/firebase_auth.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/services/site_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';
import 'package:snagsnapper/Widgets/reusable_image_picker.dart';
import 'package:snagsnapper/Widgets/info_text_field.dart';

// Removed BasicDateField import - date is now auto-set



class SiteInfo extends StatefulWidget {
  const SiteInfo(this.site, {super.key});
  final Site? site;
  @override
  _SiteInfoState createState() => _SiteInfoState();
}

class _SiteInfoState extends State<SiteInfo> {

  final _formKey = GlobalKey<FormState>();

  /// If existing site is clicked this will be filled in with existing site details
  Site? site;
  /// If no existing sound found then this will be true
  bool newSite = false;


  /// Picture quality button selection
  late int _btnPicQuality;
  /// Emails shared with for this site. <Email, Permission> map
  Map<String,String> _assignedEmails = {};
  /// Site image path (relative path for database storage)
  late String _siteImagePath;
  /// Site ID - for new sites, generated upfront to ensure image paths match
  late String _siteId;
  late String _siteAddress; // Renamed from _siteLocation
  late String _siteName;
  late String _siteCompanyName; // Renamed from _siteClientName
  late String _siteContactPerson;
  late String _siteContactPhone;
  late String _siteReportTitle;
  late DateTime? _siteExpectedCompletion;

  /// Firebase user
  final User _firebaseUser = FirebaseAuth.instance.currentUser!;
  /// General purpose busy flag
  bool busy = false;

  @override
  void initState() {
    super.initState();
    site = widget.site;
    if (site != null) { // If existing site is there, load values
      _loadValuesFromSite(site!);
    } else { // Else start with default values
      _loadDefaults();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          newSite ? 'Create Site' : 'Edit Site',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: _handleBackPressed,
        ),
        actions: [
          if (!busy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _saveSite,
                icon: Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Save',
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 24),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Site Image Section
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ImageHelper(
                    filePath: _siteImagePath,
                    height: MediaQuery.of(context).size.width * 0.6,
                    text: 'Add site photo',
                    callBackFunction: _pickSiteImage,
                  ),
                ),
              ),
              // Main Form Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Site Information Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Site Information',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Company Name Field
                            InfoTextField(
                              labelText: 'Client Name',
                              infoText: 'Enter the company or client name associated with this site. This will appear on reports and helps identify the project owner.',
                              hintText: 'Enter client name',
                              prefixIcon: Icons.business_center,
                              initialValue: _siteCompanyName,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              isRequired: true,
                              onChanged: (value) {
                                _siteCompanyName = value.trim();
                              },
                              validator: (value) {
                                return value != null && value.isNotEmpty ? null : 'Client name is required';
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Site Name Field
                            InfoTextField(
                              labelText: 'Site Name',
                              infoText: 'Provide a unique, descriptive name for this site. Examples: "Main Street Renovation", "Office Building Phase 2", "Smith Residence Extension".',
                              hintText: 'Enter site name',
                              prefixIcon: Icons.apartment,
                              initialValue: _siteName,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              isRequired: true,
                              onChanged: (value) {
                                _siteName = value.trim();
                              },
                              validator: (value) {
                                return value != null && value.isNotEmpty ? null : 'Site name is required';
                              },
                            ),
                            const SizedBox(height: 16),

                            // Report Title Field
                            InfoTextField(
                              labelText: 'Report Title',
                              infoText: 'Custom title that appears at the top of PDF reports for this site. If left empty, the site name will be used as the report title.',
                              hintText: 'Enter report title (optional)',
                              prefixIcon: Icons.description_outlined,
                              initialValue: _siteReportTitle,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ,.-]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                _siteReportTitle = value.trim();
                              },
                            ),
                            const SizedBox(height: 16),

                            // Address Field
                            InfoTextField(
                              labelText: 'Location',
                              infoText: 'Enter the full street address or a description of the site location. This helps team members find the site and appears on reports.',
                              hintText: 'Enter location or address',
                              prefixIcon: Icons.location_on,
                              initialValue: _siteAddress,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ,.-]'))],
                              keyboardType: TextInputType.streetAddress,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                _siteAddress = value.trim();
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Contact Person Field
                            InfoTextField(
                              labelText: 'Contact Person',
                              infoText: 'Name of the primary contact person at this site. This could be the client, site supervisor, or main point of contact for the project.',
                              hintText: 'Enter contact person name',
                              prefixIcon: Icons.person_outline,
                              initialValue: _siteContactPerson,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) {
                                _siteContactPerson = value.trim();
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Contact Phone Field
                            InfoTextField(
                              labelText: 'Contact Phone',
                              infoText: 'Phone number of the site contact person. Include country code for international numbers.',
                              hintText: 'Enter contact phone number',
                              prefixIcon: Icons.phone_outlined,
                              initialValue: _siteContactPhone,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9+() -]'))],
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                _siteContactPhone = value.trim();
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Expected Completion Date Field
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                                title: Text(
                                  'Expected Completion',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                subtitle: Text(
                                  _siteExpectedCompletion != null
                                      ? DateFormat('dd MMM yyyy').format(_siteExpectedCompletion!)
                                      : 'Not set',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    color: _siteExpectedCompletion != null
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                ),
                                trailing: _siteExpectedCompletion != null
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _siteExpectedCompletion = null;
                                          });
                                        },
                                      )
                                    : null,
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _siteExpectedCompletion ?? DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      _siteExpectedCompletion = pickedDate;
                                    });
                                  }
                                },
                              ),
                            ),
                            // Date field removed - date is now auto-set on creation
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Picture Quality Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Picture Quality',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lower quality results in smaller PDF report size',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: [
                                ButtonSegment<int>(
                                  value: 0,
                                  label: Text('Low', style: GoogleFonts.montserrat(fontSize: 13)),
                                  icon: const Icon(Icons.compress, size: 18),
                                ),
                                ButtonSegment<int>(
                                  value: 1,
                                  label: Text('Medium', style: GoogleFonts.montserrat(fontSize: 13)),
                                  icon: const Icon(Icons.tune, size: 18),
                                ),
                                ButtonSegment<int>(
                                  value: 2,
                                  label: Text('High', style: GoogleFonts.montserrat(fontSize: 13)),
                                  icon: const Icon(Icons.high_quality, size: 18),
                                ),
                              ],
                              selected: {_btnPicQuality},
                              onSelectionChanged: (Set<int> newSelection) {
                                FocusScope.of(context).unfocus();
                                setState(() => _btnPicQuality = newSelection.first);
                              },
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                visualDensity: VisualDensity.comfortable,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // TODO: Site sharing will be implemented with email-based sharing
                    // See Claude/00-CORE/SHARING_ARCHITECTURE.md for design
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle back button press with cleanup for unsaved new sites
  Future<void> _handleBackPressed() async {
    // Clean up orphaned image for unsaved new site
    if (newSite && _siteImagePath.isNotEmpty) {
      final imageStorageService = ImageStorageService.instance;
      await imageStorageService.deleteSiteImage(_firebaseUser.uid, _siteId);
      // Also delete the empty directory
      await imageStorageService.deleteSiteDirectory(_firebaseUser.uid, _siteId);
      if (kDebugMode) {
        print('Cleaned up orphaned image for unsaved new site: $_siteId');
      }
    }
    if (mounted) Navigator.pop(context);
  }

  void _loadDefaults() {
    newSite = true;
    _siteImagePath = '';
    _siteId = getuID(); // Generate real UUID upfront for consistent image paths
    _siteName = '';
    _siteCompanyName = '';
    _siteAddress = '';
    _siteContactPerson = '';
    _siteContactPhone = '';
    _siteReportTitle = '';
    _siteExpectedCompletion = null;
    _btnPicQuality = 1; // Default to medium
    _assignedEmails = {};
  }

  void _loadValuesFromSite(Site site) {
    newSite = false; // Explicit - editing existing site
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
  }

  /// Handle site image selection using ReusableImagePicker
  Future<void> _pickSiteImage() async {
    // If image exists, only show Remove option (no direct replace per design)
    if (_siteImagePath.isNotEmpty) {
      ReusableImagePicker.showRemoveOnly(
        context: context,
        onImageRemoved: _removeSiteImage,
        removeItemName: 'Photo',
        removeItemDescription: 'Delete site photo',
      );
    } else {
      // No image - show Camera and Gallery options
      ReusableImagePicker.show(
        context: context,
        onImageSelected: (ImageSource source) => _processImageFromSource(source),
        removeItemName: 'Photo',
        removeItemDescription: 'Delete site photo',
        hasExistingImage: false,
      );
    }
  }

  /// Process image from the selected source (camera or gallery)
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

      // Read image bytes
      final bytes = await pickedFile.readAsBytes();

      // Compress image using the compression service
      // Note: If image is too large, processSiteImageFromBytes throws ImageTooLargeException
      final compressionService = ImageCompressionService.instance;
      final result = await compressionService.processSiteImageFromBytes(bytes);

      // Save to local storage
      final imageStorageService = ImageStorageService.instance;
      final siteId = site?.id ?? _siteId;
      final relativePath = await imageStorageService.saveSiteImageFromBytes(
        result.data,
        _firebaseUser.uid,
        siteId,
      );

      // Clear image cache to force reload (same path, new content)
      imageCache.clear();

      setState(() {
        _siteImagePath = relativePath;
        busy = false;
      });

      // Instant DB update for existing sites (no waiting for Save button)
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

      if (kDebugMode) {
        print('Site image saved: $relativePath');
        print('Compression: ${result.message}');
      }
    } on ImageTooLargeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => busy = false);
    } on InvalidImageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => busy = false);
    } catch (e) {
      if (kDebugMode) print('Error processing site image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => busy = false);
    }
  }

  /// Remove site image
  Future<void> _removeSiteImage() async {
    try {
      final imageStorageService = ImageStorageService.instance;
      final siteId = site?.id ?? _siteId;
      await imageStorageService.deleteSiteImage(_firebaseUser.uid, siteId);

      setState(() {
        _siteImagePath = '';
      });

      // Instant DB update for existing sites (no waiting for Save button)
      if (!newSite && site != null) {
        site = site!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true, // Mark for Firebase deletion during sync
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

  Future<void> _saveSite() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (kDebugMode) print('Site - Form validated');

      // Check if any TEXT field changes were made (image ops are instant/independent)
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
            // Create new site using the service with pre-generated ID
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

            // Add shared users if any
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
            // Update existing site using offline-first pattern
            // Use copyWith to create updated Site with sync flags
            // Note: needsImageSync is NOT set here - instant image operations handle it
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
              needsSiteSync: true, // Mark for background sync
              updatedAt: DateTime.now(),
            );

            // Save to local SQLite - MainMenu watcher will trigger Firebase sync
            await database.siteDao.updateSite(updatedSite);

            if (kDebugMode) print('Site updated locally: ${site!.id}, needsSync: true');
          }
        } catch (e) {
          if (kDebugMode) print('Error saving site: $e');
          if (mounted) {
            showFlushbar(
              context: context,
              flushbar: Flushbar(
                boxShadows: const [
                  BoxShadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3, spreadRadius: 4),
                ],
                duration: const Duration(seconds: 6),
                flushbarPosition: FlushbarPosition.TOP,
                title: 'Error',
                message: 'Error saving Site, please try again',
                icon: const Icon(Icons.error, size: 35.0),
                shouldIconPulse: true,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                backgroundColor: Colors.red,
              )..show(context),
            );
            setState(() => busy = false);
          }
          return; // Stay on screen for retry
        }
      }
      // Always navigate back after Save (even if no text changes - image ops are instant)
      if (mounted) Navigator.pop(context);
    }
  }

}
