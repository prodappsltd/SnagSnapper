import 'package:drift/drift.dart';

/// Profile table definition for Drift database
/// Implements PRD Section 4.2.2 database schema
@DataClassName('ProfileEntry')
class Profiles extends Table {
  // Core fields
  TextColumn get id => text().named('id')(); // Firebase UID - Primary Key
  TextColumn get name => text().named('name')();
  TextColumn get email => text().named('email')();
  TextColumn get phone => text().named('phone').nullable()();
  TextColumn get jobTitle => text().named('job_title').nullable()();
  TextColumn get companyName => text().named('company_name')();
  TextColumn get postcodeArea => text().named('postcode_area').nullable()();
  TextColumn get dateFormat => text().named('date_format').withDefault(const Constant('dd-MM-yyyy'))();
  
  // Image paths (RELATIVE only)
  TextColumn get imageLocalPath => text().named('image_local_path').nullable()();
  TextColumn get imageFirebasePath => text().named('image_firebase_path').nullable()();
  TextColumn get signatureLocalPath => text().named('signature_local_path').nullable()();
  TextColumn get signatureFirebasePath => text().named('signature_firebase_path').nullable()();
  
  // Colleagues list (stored as JSON string)
  TextColumn get colleagues => text().named('colleagues').nullable()();
  
  // Deletion flags for offline sync
  BoolColumn get imageMarkedForDeletion => boolean().named('image_marked_for_deletion').withDefault(const Constant(false))();
  BoolColumn get signatureMarkedForDeletion => boolean().named('signature_marked_for_deletion').withDefault(const Constant(false))();
  
  // Sync management
  BoolColumn get needsProfileSync => boolean().named('needs_profile_sync').withDefault(const Constant(false))();
  BoolColumn get needsImageSync => boolean().named('needs_image_sync').withDefault(const Constant(false))();
  BoolColumn get needsSignatureSync => boolean().named('needs_signature_sync').withDefault(const Constant(false))();
  DateTimeColumn get lastSyncTime => dateTime().named('last_sync_time').nullable()();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('pending'))();
  TextColumn get syncErrorMessage => text().named('sync_error_message').nullable()();
  IntColumn get syncRetryCount => integer().named('sync_retry_count').withDefault(const Constant(0))();
  
  // Device management
  TextColumn get currentDeviceId => text().named('current_device_id').nullable()();
  DateTimeColumn get lastLoginTime => dateTime().named('last_login_time').nullable()();
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  
  // Versioning
  IntColumn get localVersion => integer().named('local_version').withDefault(const Constant(1))();
  IntColumn get firebaseVersion => integer().named('firebase_version').withDefault(const Constant(0))();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'profiles';
}