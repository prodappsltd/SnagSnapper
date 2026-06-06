import 'package:drift/drift.dart';

/// Snags table definition for Drift database
/// Implements offline-first architecture for construction defect tracking
///
/// This table stores all snag information locally with sync capabilities.
/// ImageSlot lists are stored as JSON strings and converted by DAOs.
///
/// See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md
@DataClassName('SnagEntry')
class Snags extends Table {
  // ============== Identity Fields ==============
  /// Unique identifier for the snag (UUID v4)
  TextColumn get id => text().named('id')();

  /// Parent site ID (foreign key to sites table)
  TextColumn get siteUID => text().named('site_uid')();

  /// Site owner email (for permission checks)
  TextColumn get ownerEmail => text().named('owner_email')();

  /// Email of user who created this snag
  TextColumn get creatorEmail => text().named('creator_email')();

  // ============== Core Business Fields ==============
  /// Snag title (Required)
  TextColumn get title => text().named('title')();

  /// Problem description (Optional)
  TextColumn get description => text().named('description').nullable()();

  /// Location within the site (Optional)
  TextColumn get location => text().named('location').nullable()();

  /// Priority level 1-5 (Optional)
  IntColumn get priority => integer().named('priority').nullable()();

  /// Due date for fixing (Optional)
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();

  /// When the snag was created
  DateTimeColumn get creationDate => dateTime().named('creation_date')();

  /// Category from site's category list (Optional)
  TextColumn get snagCategory => text().named('snag_category').nullable()();

  // ============== Assignment ==============
  /// Assigned fixer's email (Optional)
  TextColumn get assignedEmail => text().named('assigned_email').nullable()();

  /// Assigned fixer's display name (Optional)
  TextColumn get assignedName => text().named('assigned_name').nullable()();

  // ============== Problem Documentation (6 slots) ==============
  /// Problem photos stored as JSON array of ImageSlot objects
  /// Each slot: {localPath, firebasePath, needsSync, markedForDeletion, version}
  TextColumn get images => text().named('images').withDefault(const Constant('[]'))();

  // ============== Fix Documentation ==============
  /// Description of how the problem was fixed (Optional)
  TextColumn get snagFixDescription => text().named('snag_fix_description').nullable()();

  /// Fix photos stored as JSON array of ImageSlot objects (6 slots)
  TextColumn get fixImages => text().named('fix_images').withDefault(const Constant('[]'))();

  // ============== Status (Two-boolean system) ==============
  /// true = open, false = completed by fixer
  BoolColumn get snagStatus => boolean().named('snag_status').withDefault(const Constant(true))();

  /// true = pending confirmation, false = confirmed closed by owner
  BoolColumn get snagConfirmedStatus => boolean().named('snag_confirmed_status').withDefault(const Constant(true))();

  // ============== Tracking Fields ==============
  /// Email of last person who modified this snag
  TextColumn get lastModifiedBy => text().named('last_modified_by').nullable()();

  /// When the snag was last modified
  DateTimeColumn get lastModifiedDate => dateTime().named('last_modified_date').nullable()();

  /// When the fixer marked it complete
  DateTimeColumn get completedDate => dateTime().named('completed_date').nullable()();

  /// Reason owner rejected the fix (Optional)
  TextColumn get rejectionReason => text().named('rejection_reason').nullable()();

  /// Number of times the fix was rejected
  IntColumn get rejectionCount => integer().named('rejection_count').withDefault(const Constant(0))();

  /// Estimated cost to fix (Optional)
  RealColumn get costEstimate => real().named('cost_estimate').nullable()();

  // ============== Sync Management ==============
  /// Flag indicating snag data has changed and needs sync
  BoolColumn get needsSnagSync => boolean().named('needs_snag_sync').withDefault(const Constant(false))();

  /// Flag indicating images have changed and need sync
  BoolColumn get needsImagesSync => boolean().named('needs_images_sync').withDefault(const Constant(false))();

  /// Timestamp of last successful sync to Firebase
  DateTimeColumn get lastSyncTime => dateTime().named('last_sync_time').nullable()();

  // ============== Versioning ==============
  /// Local database version number
  IntColumn get localVersion => integer().named('local_version').withDefault(const Constant(1))();

  /// Firebase version number
  IntColumn get firebaseVersion => integer().named('firebase_version').withDefault(const Constant(0))();

  // ============== Metadata ==============
  /// When the record was created
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// When the record was last updated
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'snags';
}
