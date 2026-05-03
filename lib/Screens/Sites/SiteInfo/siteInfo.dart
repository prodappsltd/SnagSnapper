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
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/site.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/services/site_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';
import 'package:snagsnapper/Widgets/reusable_image_picker.dart';
import 'package:snagsnapper/Screens/profile/components/colleagues_section.dart';

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
  /// Emails from map of colleagues where colleague is selected. <Name, Email> map
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
  late DateTime? _siteExpectedCompletion;
  late DateTime _siteDate; // Temporary for old Site model compatibility

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
                            TextFormField(
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              initialValue: _siteCompanyName,
                              style: GoogleFonts.montserrat(fontSize: 16),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.business_center,
                                  color: Theme.of(context).colorScheme.primary),
                                labelText: 'Client Name',
                                labelStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                helperText: 'Company or client name for this site',
                                helperStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                hintText: 'Enter client name',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) {
                                _siteCompanyName = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : 'Client name is required';
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Site Name Field
                            TextFormField(
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              initialValue: _siteName,
                              style: GoogleFonts.montserrat(fontSize: 16),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.apartment,
                                  color: Theme.of(context).colorScheme.primary),
                                labelText: 'Site Name',
                                labelStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                helperText: 'e.g., Main Street Renovation, Phase 2',
                                helperStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                hintText: 'Enter site name',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) {
                                _siteName = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : 'Site name is required';
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Address Field
                            TextFormField(
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ,.-]'))],
                              keyboardType: TextInputType.streetAddress,
                              textCapitalization: TextCapitalization.words,
                              initialValue: _siteAddress,
                              style: GoogleFonts.montserrat(fontSize: 16),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.location_on,
                                  color: Theme.of(context).colorScheme.primary),
                                labelText: 'Location (Optional)',
                                labelStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                helperText: 'Street address or location description',
                                helperStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                hintText: 'Enter location or address',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) {
                                _siteAddress = value.toString().trim();
                              },
                              validator: (value) => null, // Optional field
                            ),
                            const SizedBox(height: 16),
                            
                            // Contact Person Field
                            TextFormField(
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              initialValue: _siteContactPerson,
                              style: GoogleFonts.montserrat(fontSize: 16),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.person_outline,
                                  color: Theme.of(context).colorScheme.primary),
                                labelText: 'Contact Person (Optional)',
                                labelStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                helperText: 'Primary contact at this site',
                                helperStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                hintText: 'Enter contact person name',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) {
                                _siteContactPerson = value.toString().trim();
                              },
                              validator: (value) => null, // Optional field
                            ),
                            const SizedBox(height: 16),
                            
                            // Contact Phone Field
                            TextFormField(
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9+() -]'))],
                              keyboardType: TextInputType.phone,
                              initialValue: _siteContactPhone,
                              style: GoogleFonts.montserrat(fontSize: 16),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.phone_outlined,
                                  color: Theme.of(context).colorScheme.primary),
                                labelText: 'Contact Phone (Optional)',
                                labelStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                helperText: 'Phone number for site contact',
                                helperStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                hintText: 'Enter contact phone number',
                                hintStyle: GoogleFonts.montserrat(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                              ),
                              onChanged: (value) {
                                _siteContactPhone = value.toString().trim();
                              },
                              validator: (value) => null, // Optional field
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
                    const SizedBox(height: 16),
                    
                    // Share with Colleagues Section
                    Builder(
                      builder: (context) {
                        final colleagueCount = Provider.of<CP>(context).getListOFColleagues().length;
                        final isAtLimit = colleagueCount >= MAX_COLLEAGUES;

                        return Container(
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
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Share with Colleagues',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                // Counter badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAtLimit
                                        ? Colors.orange.withOpacity(0.2)
                                        : Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$colleagueCount/$MAX_COLLEAGUES',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isAtLimit
                                          ? Colors.orange.shade800
                                          : Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(
                              minHeight: 100,
                              maxHeight: 300,
                            ),
                            child: Provider.of<CP>(context).getListOFColleagues().isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_add_outlined,
                                            size: 48,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No colleagues added yet',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            onPressed: () {
                                              // Show AddColleagueDialog directly
                                              showDialog(
                                                context: context,
                                                builder: (dialogContext) => AddColleagueDialog(
                                                  onAdd: (colleague) {
                                                    Provider.of<CP>(context, listen: false).addColleague(colleague);
                                                    setState(() {}); // Refresh UI
                                                  },
                                                  existingColleagues: Provider.of<CP>(context, listen: false).getListOFColleagues(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.add),
                                            label: Text(
                                              'Add Colleague',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      itemCount: Provider.of<CP>(context).getListOFColleagues().length,
                                      itemBuilder: (BuildContext context, int position) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: AssignCheckBoxView(
                                            selectedChkBxFunction: (value) async {
                                              setState(() {
                                                if (value != null && value) {
                                                  _assignedEmails.putIfAbsent(
                                                    Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email,
                                                    () => 'FULL'
                                                  );
                                                } else if (value != null && !value) {
                                                  _assignedEmails.remove(
                                                    Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email
                                                  );
                                                }
                                              });
                                              if (kDebugMode) print(_assignedEmails);
                                            },
                                            permissionCalBckFunction: () async {
                                              setState(() {
                                                final email = Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email;
                                                if (_assignedEmails[email] == 'FULL') {
                                                  _assignedEmails[email] = 'VIEW';
                                                } else {
                                                  _assignedEmails[email] = 'FULL';
                                                }
                                              });
                                              if (kDebugMode) print(_assignedEmails);
                                            },
                                            permissionString: _assignedEmails[Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email],
                                            selectedStatus: _assignedEmails.containsKey(Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email),
                                            colleague: Provider.of<CP>(context, listen: false).getListOFColleagues()[position],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                          if (Provider.of<CP>(context).getListOFColleagues().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: isAtLimit
                                      ? null // Disabled when limit reached
                                      : () {
                                          // Show AddColleagueDialog directly
                                          showDialog(
                                            context: context,
                                            builder: (dialogContext) => AddColleagueDialog(
                                              onAdd: (colleague) {
                                                Provider.of<CP>(context, listen: false).addColleague(colleague);
                                                setState(() {}); // Refresh UI
                                              },
                                              existingColleagues: Provider.of<CP>(context, listen: false).getListOFColleagues(),
                                            ),
                                          );
                                        },
                                  icon: Icon(
                                    isAtLimit ? Icons.block : Icons.person_add,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isAtLimit ? 'Limit Reached ($MAX_COLLEAGUES)' : 'Add Colleague',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                        );
                      },
                    ),
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
    _siteExpectedCompletion = null;
    _siteDate = DateTime.now(); // Temporary for old Site model
    _btnPicQuality = 1; // Default to medium
    _assignedEmails = {};
  }

  void _loadValuesFromSite(Site site) {
    _siteImagePath = site.image; // Now stores file path instead of base64
    _siteId = site.uID;
    _siteName = site.name;
    _siteCompanyName = site.companyName;
    _siteAddress = site.location;
    _siteContactPerson = ''; // TODO: Update when Site model has this field
    _siteContactPhone = ''; // TODO: Update when Site model has this field
    _siteExpectedCompletion = null; // TODO: Update when Site model has this field
    _siteDate = site.date; // Temporary for old Site model
    _btnPicQuality = site.pictureQuality;
    _assignedEmails = site.sharedWith;
  }

  /// Handle site image selection using ReusableImagePicker
  Future<void> _pickSiteImage() async {
    ReusableImagePicker.show(
      context: context,
      onImageSelected: (ImageSource source) => _processImageFromSource(source),
      onImageRemoved: _siteImagePath.isNotEmpty ? _removeSiteImage : null,
      removeItemName: 'Photo',
      removeItemDescription: 'Delete site photo',
      hasExistingImage: _siteImagePath.isNotEmpty,
    );
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
      final siteId = site?.uID ?? _siteId;
      final relativePath = await imageStorageService.saveSiteImageFromBytes(
        result.data,
        _firebaseUser.uid,
        siteId,
      );

      setState(() {
        _siteImagePath = relativePath;
        busy = false;
      });

      // Instant DB update for existing sites (no waiting for Save button)
      if (!newSite && site != null) {
        site!.image = relativePath;
        await Provider.of<CP>(context, listen: false).updateSite(site!);
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
      final siteId = site?.uID ?? _siteId;
      await imageStorageService.deleteSiteImage(_firebaseUser.uid, siteId);

      setState(() {
        _siteImagePath = '';
      });

      // Instant DB update for existing sites (no waiting for Save button)
      if (!newSite && site != null) {
        site!.image = '';
        await Provider.of<CP>(context, listen: false).updateSite(site!);
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
      if (newSite || _siteImagePath != site!.image ||
          _siteName != site!.name ||
          _siteCompanyName != site!.companyName ||
          _siteAddress != site!.location ||
          _siteDate != site!.date ||
          _btnPicQuality != site!.pictureQuality ||
          !mapEquals(_assignedEmails, site!.sharedWith)) {
        setState(() => busy = true);
        if (kDebugMode) print('Site - Create Update initiated');

        // Use new database service for creating/updating sites
        try {
          final database = AppDatabase.instance;
          final siteService = SiteService(
            database: database,
            userEmail: _firebaseUser.email!,
            userUID: _firebaseUser.uid,
          );

          if (newSite) {
            // Create new site using the service with pre-generated ID
            // This ensures the image path (saved earlier) matches the site ID
            await siteService.createSite(
              siteId: _siteId, // Use pre-generated ID for consistency with image path
              name: _siteName,
              companyName: _siteCompanyName.isNotEmpty ? _siteCompanyName : null,
              address: _siteAddress.isNotEmpty ? _siteAddress : null,
              contactPerson: _siteContactPerson.isNotEmpty ? _siteContactPerson : null,
              contactPhone: _siteContactPhone.isNotEmpty ? _siteContactPhone : null,
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
            // For now, still use old update method until we migrate fully
            // TODO: Implement update using new model
            Site nSite = Site(
              image: _siteImagePath, // Now stores file path instead of base64
              name: _siteName,
              companyName: _siteCompanyName,
              location: _siteAddress,
              date: _siteDate,
              pictureQuality: _btnPicQuality,
              sharedWith: _assignedEmails,
              archive: site!.archive,
              uID: site!.uID,
              ownerEmail: site!.ownerEmail,
              ownerName: Provider.of<CP>(context, listen: false).getAppUser()!.name,
            );
            await Provider.of<CP>(context, listen: false).updateSite(nSite);
          }
          Navigator.pop(context, site);
        } catch (e) {
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
                message: 'Error updating Site, please try again',
                icon: const Icon(Icons.error, size: 35.0),
                shouldIconPulse: true,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                backgroundColor: Colors.red,
              )..show(context),
            );
            setState(() => busy = false);
          }
        }
        setState(() => busy = false);
      }
    }
  }

}


class AssignCheckBoxView extends StatelessWidget {
  final Colleague colleague;
  final bool selectedStatus;
  final Function(bool?) selectedChkBxFunction;
  final VoidCallback permissionCalBckFunction;
  final String? permissionString;
  const AssignCheckBoxView({
    super.key,
    this.permissionString,
    required this.colleague,
    required this.selectedStatus,
    required this.selectedChkBxFunction,
    required this.permissionCalBckFunction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedStatus
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (selectedStatus)
            GestureDetector(
              onTap: permissionCalBckFunction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: permissionString == 'VIEW'
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      permissionString == 'VIEW' ? Icons.visibility : Icons.edit,
                      size: 16,
                      color: permissionString == 'VIEW'
                          ? Theme.of(context).colorScheme.onTertiary
                          : Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      permissionString == 'VIEW' ? 'View' : 'Edit',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: permissionString == 'VIEW'
                            ? Theme.of(context).colorScheme.onTertiary
                            : Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    colleague.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    colleague.email,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Checkbox(
            value: selectedStatus,
            onChanged: selectedChkBxFunction,
            activeColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

