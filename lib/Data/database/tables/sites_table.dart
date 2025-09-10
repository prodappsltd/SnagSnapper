import 'package:drift/drift.dart';

/// Sites table definition for Drift database
/// Implements offline-first architecture for construction site management
/// 
/// This table stores all site information locally with sync capabilities.
/// Maps are stored as JSON strings and converted by DAOs.
@DataClassName('SiteEntry')
class Sites extends Table {
  // ============== Identity Fields ==============
  /// Unique identifier for the site (UUID v4)
  TextColumn get id => text().named('id')();
  
  /// Firebase UID of the site owner
  TextColumn get ownerUID => text().named('owner_uid')();
  
  /// Email address of the site owner
  TextColumn get ownerEmail => text().named('owner_email')();
  
  // ============== Core Business Fields ==============
  /// Site name (Required)
  TextColumn get name => text().named('name')();
  
  /// Client company or individual name (Optional)
  TextColumn get companyName => text().named('company_name').nullable()();
  
  /// Physical address or location of the site (Optional)
  TextColumn get address => text().named('address').nullable()();
  
  /// Primary contact person for this site (Optional)
  TextColumn get contactPerson => text().named('contact_person').nullable()();
  
  /// Contact person's phone number (Optional)
  TextColumn get contactPhone => text().named('contact_phone').nullable()();
  
  /// Site creation/start date
  DateTimeColumn get date => dateTime().named('date')();
  
  /// Expected completion date (Optional)
  DateTimeColumn get expectedCompletion => dateTime().named('expected_completion').nullable()();
  
  // ============== Media Storage ==============
  /// Local file path for site image (Relative path)
  TextColumn get imageLocalPath => text().named('image_local_path').nullable()();
  
  /// Firebase Storage path for site image
  TextColumn get imageFirebasePath => text().named('image_firebase_path').nullable()();
  
  // ============== Settings ==============
  /// Image quality for PDF reports: 0=Low, 1=Medium, 2=High
  IntColumn get pictureQuality => integer().named('picture_quality').withDefault(const Constant(1))();
  
  /// Archive status to hide completed/old sites
  BoolColumn get archive => boolean().named('archive').withDefault(const Constant(false))();
  
  // ============== Sharing & Permissions ==============
  /// Map of user emails to permissions (stored as JSON)
  /// Format: {"email@example.com": "VIEW", "email2@example.com": "CONTRIBUTOR"}
  TextColumn get sharedWith => text().named('shared_with').withDefault(const Constant('{}'))();
  
  // ============== Statistics ==============
  /// Total number of snags in this site
  IntColumn get totalSnags => integer().named('total_snags').withDefault(const Constant(0))();
  
  /// Number of open/unresolved snags
  IntColumn get openSnags => integer().named('open_snags').withDefault(const Constant(0))();
  
  /// Number of closed/resolved snags
  IntColumn get closedSnags => integer().named('closed_snags').withDefault(const Constant(0))();
  
  // ============== Categories ==============
  /// Dynamic categories for organizing snags (stored as JSON)
  /// Format: {"1": "Electrical", "2": "Plumbing", "3": "Painting"}
  TextColumn get snagCategories => text().named('snag_categories').withDefault(const Constant('{}'))();
  
  // ============== Sync Management ==============
  /// Flag indicating site data has changed and needs sync
  BoolColumn get needsSiteSync => boolean().named('needs_site_sync').withDefault(const Constant(false))();
  
  /// Flag indicating site image has changed and needs sync
  BoolColumn get needsImageSync => boolean().named('needs_image_sync').withDefault(const Constant(false))();
  
  /// Flag indicating snags under this site need sync
  BoolColumn get needsSnagsSync => boolean().named('needs_snags_sync').withDefault(const Constant(false))();
  
  /// Timestamp of last successful sync to Firebase
  DateTimeColumn get lastSyncTime => dateTime().named('last_sync_time').nullable()();
  
  // ============== Update Tracking ==============
  /// Timestamp when any snag in this site was last modified
  DateTimeColumn get lastSnagUpdate => dateTime().named('last_snag_update').nullable()();
  
  /// List of snag IDs that have pending updates (stored as JSON array)
  TextColumn get updatedSnags => text().named('updated_snags').withDefault(const Constant('[]'))();
  
  /// Count of pending updates
  IntColumn get updateCount => integer().named('update_count').withDefault(const Constant(0))();
  
  // ============== Deletion Management ==============
  /// Soft delete flag
  BoolColumn get markedForDeletion => boolean().named('marked_for_deletion').withDefault(const Constant(false))();
  
  /// Timestamp when site was marked for deletion
  DateTimeColumn get deletionDate => dateTime().named('deletion_date').nullable()();
  
  /// Date when site will be permanently deleted (deletionDate + 7 days)
  DateTimeColumn get scheduledDeletionDate => dateTime().named('scheduled_deletion_date').nullable()();
  
  // ============== Versioning ==============
  /// Local database version number
  IntColumn get localVersion => integer().named('local_version').withDefault(const Constant(1))();
  
  /// Firebase version number
  IntColumn get firebaseVersion => integer().named('firebase_version').withDefault(const Constant(0))();
  
  // ============== Metadata ==============
  /// Timestamp when record was last updated
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'sites';
}