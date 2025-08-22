# SnagSnapper - Product Requirements Document (PRD)

## 1. Product Overview

### 1.1 Product Vision
SnagSnapper is an offline-first mobile application designed for construction site management, enabling contractors and site managers to document, track, and manage construction defects (snags) in areas with poor or no internet connectivity.

**Marketing Tagline**: "Professional Site Management That Works Everywhere™"

### 1.2 Core Philosophy
**"SnagSnapper is an OFFLINE app that happens to sync with cloud, NOT a cloud app with offline support."**

- Local database is the single source of truth
- Firebase serves as backup/sync destination
- App works 100% without internet forever
- Sync is optional and user-controlled
- When switching devices, entire data can be restored from cloud backup

### 1.3 Key Features
- User profile management with company branding
- Site creation and management
- Snag documentation with photos and details
- Colleague/sub-contractor management
- Snag assignment and tracking
- Two-way sync between site managers and assignees
- PDF report generation
- Site sharing with colleagues
- Offline-first architecture with background sync

**Marketing Highlights**:
- 🚀 "Lightning-fast offline performance"
- 🔒 "Bank-grade security with encrypted storage"
- 📱 "Works without internet - perfect for remote sites"
- 🤝 "Seamless team collaboration"
- 📊 "Professional PDF reports with your branding"
- ⚡ "Instant photo capture and annotation"
- 🔄 "Automatic background sync when connected"

### 1.4 Target Platforms
- iOS (14.0+)
- Android (API 25+)

---

## 2. User Requirements

### 2.1 User Personas

#### Primary: Site Manager
- Manages multiple construction sites
- Documents snags daily
- Adds colleagues and sub-contractors to sites
- Assigns snags to specific contractors
- Reviews completion photos from assignees
- Decides whether to close completed snags
- Generates reports for clients
- Works in areas with poor connectivity

#### Secondary: Contractor/Sub-contractor
- Receives snag assignments from site manager
- Views assigned snag details and location
- Updates snag status as work progresses
- Adds completion photos as proof of work
- Syncs updates back to site manager
- Needs offline access for field work

### 2.2 Critical Requirements
1. **100% Offline Functionality** - All features must work without internet
2. **Single Device Login** - Only one device logged in per user at any time
3. **Data Persistence** - User data must sync when switching devices
4. **Two-way Sync** - Snag assignments must sync between site manager and assignees
5. **Collaborative Workflow** - Multiple users can work on same site with proper sync
6. **Cost Efficiency** - Minimize Firebase usage to reduce operational costs

**Marketing Value Propositions**:
- "Never lose work due to poor signal"
- "Secure single-device access prevents data breaches"
- "Seamless device switching for field teams"
- "Real-time collaboration between office and site"
- "Enterprise-ready at small business pricing"

---

## 3. Technical Architecture

### 3.1 Technology Stack
- **Framework**: Flutter
- **Local Database**: Drift (SQLite)
- **Cloud Backend**: Firebase (Firestore, Storage, Auth)
- **State Management**: Provider Pattern
- **Image Storage**: Local filesystem + Firebase Storage

### 3.2 Data Flow Architecture
```
User → UI → Local Database → Sync Service → Firebase
         ↑                                      ↓
         ←────────────────────────────────────←
```

### 3.3 Sync Strategy
Sync flags are set ONLY when changes are saved to local database.
Background sync is then triggered by:
1. Manual sync button (user control when flags are set)
2. On object load from database (checks and syncs if flags are true)
3. After object save to database (attempts sync after flag is set)

---

## 4. Sites Module Requirements

### 4.1 Overview
The Sites module enables construction site management with offline-first architecture, supporting both owned and shared sites with granular permission controls for collaborative workflows.

### 4.2 Data Models

#### 4.2.1 Site Model
```dart
class Site {
  // Identity
  String id;                        // UUID v4 (locally generated)
  String ownerUID;                  // Firebase UID of owner
  String ownerEmail;
  String ownerName;
  
  // Core Fields (Owner-editable)
  String name;                      // Required - Site name
  String? companyName;              // Optional - Client company
  String? address;                  // Optional - Site address (renamed from location)
  String? contactPerson;            // Optional - Client contact name
  String? contactPhone;             // Optional - Client phone
  DateTime date;                    // Auto-set creation date
  DateTime? expectedCompletion;     // Optional - Target completion
  
  // Site Image
  String? imageLocalPath;           // Local file path
  String? imageFirebasePath;        // Firebase Storage path
  
  // Settings (Hidden from colleagues)
  int pictureQuality;               // 0-2 (kept for future use)
  bool archive;                     // Archive status
  
  // Sharing & Permissions
  Map<String, String> sharedWith;  // {email: permission}
  // Permissions: VIEW, FIXER, CONTRIBUTOR
  
  // Statistics (Auto-calculated)
  int totalSnags;                   // Total snag count
  int openSnags;                    // Open snag count  
  int closedSnags;                  // Closed snag count
  
  // Categories (Site-specific)
  List<String> snagCategories;      // Custom categories for this site
  
  // Sync Management
  bool needsSiteSync;               // Site data changed
  bool needsImageSync;              // Site image changed
  bool needsSnagsSync;              // Snags under site changed
  DateTime? lastSyncTime;
  
  // Update Tracking (For shared sites)
  DateTime? lastSnagUpdate;         // When any snag was last modified
  List<String> updatedSnags;        // IDs of snags with changes
  int updateCount;                  // Number of pending updates
  
  // Deletion Management  
  bool markedForDeletion;           // Soft delete flag
  DateTime? deletionDate;           // When marked for deletion
  DateTime? scheduledDeletionDate;  // deletion date + 7 days
  
  // Versioning
  int localVersion;
  int firebaseVersion;
}
```

#### 4.2.2 Snag Model
```dart
class Snag {
  // Identity
  String id;                        // UUID v4 (locally generated)
  String siteUID;                   // Parent site ID
  String ownerEmail;                // Site owner email
  String creatorEmail;              // Who created the snag
  
  // Core Fields (Owner-editable, Colleague read-only)
  String title;                     // Required - Snag title
  String? description;              // Optional - Problem description
  String? location;                 // Optional - Location in site
  int? priority;                    // Optional - Priority level (1-5)
  DateTime? dueDate;                // Optional - Due date
  DateTime creationDate;            // Auto-set creation date
  String? snagCategory;             // Optional - Category from site list
  
  // Assignment (Owner-only)
  String? assignedEmail;            // Assigned colleague email
  String? assignedName;             // Assigned colleague name
  
  // Problem Documentation (Owner-only)
  String? imageMain1LocalPath;
  String? imageMain1FirebasePath;
  String? image2LocalPath;
  String? image2FirebasePath;
  String? image3LocalPath;
  String? image3FirebasePath;
  String? image4LocalPath;
  String? image4FirebasePath;
  
  // Fix Documentation (Colleague-editable when assigned)
  String? snagFixDescription;       // How it was fixed
  String? snagFixMainImageLocalPath;
  String? snagFixMainImageFirebasePath;
  String? snagFixImage1LocalPath;
  String? snagFixImage1FirebasePath;
  String? snagFixImage2LocalPath;
  String? snagFixImage2FirebasePath;
  String? snagFixImage3LocalPath;
  String? snagFixImage3FirebasePath;
  
  // Status (Two-boolean system)
  bool snagStatus;                  // true=open, false=completed by FIXER
  bool snagConfirmedStatus;         // true=pending, false=confirmed closed by owner
  
  // Tracking Fields (New)
  String? lastModifiedBy;           // Email of last modifier
  DateTime? lastModifiedDate;       // When last modified
  DateTime? completedDate;          // When FIXER marked complete
  String? rejectionReason;          // Why owner rejected fix
  int rejectionCount;               // Number of rejections
  double? costEstimate;             // Optional cost estimate
  
  // Sync Management
  bool needsSnagSync;               // Snag data changed
  bool needsImagesSync;             // Images changed
  DateTime? lastSyncTime;
  
  // Versioning
  int localVersion;
  int firebaseVersion;
}
```

### 4.3 Permission Model

#### 4.3.1 Permission Levels
1. **OWNER** - Full control
   - All CRUD operations on site and snags
   - Manage sharing and permissions
   - Delete site
   - Assign snags to colleagues

2. **CONTRIBUTOR** - Can create and work
   - View all site info and snags
   - Create new snags (tracked as creator)
   - Edit assigned snag fix fields
   - Cannot assign snags
   - Cannot edit others' snags
   - Manually granted by owner

3. **FIXER** - Work on assigned only
   - View site info
   - See ONLY assigned snags
   - Edit fix fields on assigned snags
   - Cannot create new snags
   - Auto-granted when snag assigned

4. **VIEW** - Read-only access
   - View site and all snags
   - Cannot edit anything
   - Cannot create snags

#### 4.3.2 Field-Level Permissions

**Site Fields:**
- Owner: Full edit access
- Others: Read-only for visible fields
- Hidden from colleagues: pictureQuality, archive, sharedWith

**Snag Fields:**
- Owner can edit: All fields except colleague fix fields
- FIXER/CONTRIBUTOR can edit (when assigned):
  - snagFixDescription
  - snagFixMainImage, snagFixImage1-3
  - snagStatus (mark complete, needs owner confirmation)
- System manages: IDs, timestamps, sync flags

### 4.4 Database Schema

#### 4.4.1 Sites Table
```sql
CREATE TABLE sites (
  -- Identity
  id TEXT PRIMARY KEY,              -- UUID v4
  owner_uid TEXT NOT NULL,
  owner_email TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  
  -- Core Data
  name TEXT NOT NULL,
  company_name TEXT,
  address TEXT,
  contact_person TEXT,
  contact_phone TEXT,
  date INTEGER NOT NULL,
  expected_completion INTEGER,
  
  -- Images
  image_local_path TEXT,
  image_firebase_path TEXT,
  
  -- Settings
  picture_quality INTEGER DEFAULT 0,
  archive BOOLEAN DEFAULT FALSE,
  
  -- Sharing (JSON)
  shared_with TEXT,                 -- JSON map of {email: permission}
  
  -- Statistics
  total_snags INTEGER DEFAULT 0,
  open_snags INTEGER DEFAULT 0,
  closed_snags INTEGER DEFAULT 0,
  
  -- Categories (JSON)
  snag_categories TEXT,             -- JSON array of strings
  
  -- Sync Management
  needs_site_sync BOOLEAN DEFAULT FALSE,
  needs_image_sync BOOLEAN DEFAULT FALSE,
  needs_snags_sync BOOLEAN DEFAULT FALSE,
  last_sync_time INTEGER,
  
  -- Update Tracking
  last_snag_update INTEGER,
  updated_snags TEXT,               -- JSON array of snag IDs
  update_count INTEGER DEFAULT 0,
  
  -- Deletion
  marked_for_deletion BOOLEAN DEFAULT FALSE,
  deletion_date INTEGER,
  scheduled_deletion_date INTEGER,
  
  -- Metadata
  local_version INTEGER DEFAULT 1,
  firebase_version INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  
  -- Ownership Type
  is_owned BOOLEAN NOT NULL        -- true if owner, false if shared
);
```

#### 4.4.2 Snags Table
```sql
CREATE TABLE snags (
  -- Identity
  id TEXT PRIMARY KEY,              -- UUID v4
  site_uid TEXT NOT NULL,
  owner_email TEXT NOT NULL,
  creator_email TEXT NOT NULL,
  
  -- Core Data
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  priority INTEGER,
  due_date INTEGER,
  creation_date INTEGER NOT NULL,
  snag_category TEXT,
  
  -- Assignment
  assigned_email TEXT,
  assigned_name TEXT,
  
  -- Problem Images (Paths)
  image_main1_local_path TEXT,
  image_main1_firebase_path TEXT,
  image2_local_path TEXT,
  image2_firebase_path TEXT,
  image3_local_path TEXT,
  image3_firebase_path TEXT,
  image4_local_path TEXT,
  image4_firebase_path TEXT,
  
  -- Fix Documentation
  snag_fix_description TEXT,
  snag_fix_main_image_local_path TEXT,
  snag_fix_main_image_firebase_path TEXT,
  snag_fix_image1_local_path TEXT,
  snag_fix_image1_firebase_path TEXT,
  snag_fix_image2_local_path TEXT,
  snag_fix_image2_firebase_path TEXT,
  snag_fix_image3_local_path TEXT,
  snag_fix_image3_firebase_path TEXT,
  
  -- Status
  snag_status BOOLEAN DEFAULT TRUE,       -- true=open
  snag_confirmed_status BOOLEAN DEFAULT TRUE, -- true=pending
  
  -- Tracking
  last_modified_by TEXT,
  last_modified_date INTEGER,
  completed_date INTEGER,
  rejection_reason TEXT,
  rejection_count INTEGER DEFAULT 0,
  cost_estimate REAL,
  
  -- Sync Management
  needs_snag_sync BOOLEAN DEFAULT FALSE,
  needs_images_sync BOOLEAN DEFAULT FALSE,
  last_sync_time INTEGER,
  
  -- Versioning
  local_version INTEGER DEFAULT 1,
  firebase_version INTEGER DEFAULT 0,
  
  FOREIGN KEY (site_uid) REFERENCES sites(id)
);
```

### 4.5 User Flows

#### 4.5.1 Site Creation Flow
```
1. User navigates to Sites → My Sites
2. Taps "Create Site" (Pro users only)
3. Form appears with fields:
   - Name (required)
   - Company, Address, Contact (optional)
   - Expected Completion (optional)
   - Site Image (optional)
4. User fills form and taps Save
5. System:
   - Generates UUID locally
   - Saves to local database
   - Sets needsSiteSync = true
   - Shows success message
   - Navigates to site detail
6. Background sync when navigating away
```

#### 4.5.2 Snag Creation Flow
```
1. User opens site detail screen
2. Taps "Add Snag" button
3. Form appears:
   - Title (required)
   - All other fields optional
   - Category dropdown from site categories
4. User can:
   - Quick save with just title
   - Add photos (up to 4)
   - Fill detailed information
5. System:
   - Generates UUID locally
   - Saves to local database
   - Updates site statistics
   - Sets needsSnagSync = true
6. UI updates immediately
7. Sync on navigation
```

#### 4.5.3 Snag Assignment Flow
```
1. Owner opens snag detail
2. Taps "Assign" button
3. Selects colleague from list (Profile colleagues)
4. System:
   - Updates snag with assignment
   - Auto-shares site with FIXER permission
   - Sets sync flags
5. On sync:
   - Snag appears in colleague's app
   - Site appears in "Shared With Me"
```

#### 4.5.4 FIXER Workflow
```
1. FIXER opens app
2. Navigates to Sites → Shared With Me
3. Opens shared site
4. Sees only assigned snags
5. Opens assigned snag:
   - Views problem details (read-only)
   - Adds fix description
   - Adds completion photos
   - Marks as complete
6. System:
   - Saves locally
   - Shows sync indicator on snag tile
7. FIXER manually syncs when ready
8. Owner receives update on next refresh
```

#### 4.5.5 Site Deletion Flow
```
1. Owner marks site for deletion
2. System:
   - Sets markedForDeletion = true
   - Sets deletionDate = now
   - Sets scheduledDeletionDate = now + 7 days
3. On sync to Firebase:
   - Notifies all shared users
   - Starts 7-day countdown
4. During grace period:
   - Owner: Can unmark, full access
   - Others: Read-only, can export their work
5. Day 8: Cloud Function deletes site and all snags
```

### 4.6 Sync Strategy

#### 4.6.1 Owner Sites
- **Save**: Local first, immediate
- **Sync**: Automatic on navigation (fire-and-forget)
- **Direction**: Bidirectional (upload and download)
- **Conflict**: Owner changes win

#### 4.6.2 Shared Sites
- **Initial**: Download when shared/assigned
- **Updates**: Manual refresh by user
- **Changes**: Save locally, manual sync
- **Storage**: Site info + assigned snags only (FIXER)
- **Storage**: Site info + all snags (CONTRIBUTOR/VIEW)

#### 4.6.3 Update Detection
- Site maintains `lastSnagUpdate` timestamp
- Cloud Function updates parent site when snag changes
- Owner checks site for updates (1 read)
- Downloads only changed snags (N reads for changes)

### 4.7 Subscription Tiers

#### 4.7.1 FREE Tier
- 3 Sites (owner)
- 100 Snags per site
- 5GB total storage
- Cannot share sites
- Can be shared WITH (unlimited)

#### 4.7.2 PRO Tier ($9.99/month)
- 10 Sites (owner)
- 500 Snags per site
- 25GB total storage
- Can share sites (all permissions)
- Custom snag categories
- Branded PDF reports

#### 4.7.3 BUSINESS Tier ($24.99/month)
- Unlimited Sites (owner)
- 1000 Snags per site
- 100GB total storage
- All PRO features
- Priority support

### 4.8 Storage Management
- Monthly storage calculation via Firebase Storage list
- Cost: ~$0.005 per user per check
- Images: 300KB target size after compression
- Local caching for offline access
- Shared sites: Only assigned snags cached

### 4.9 Cloud Functions

#### 4.9.1 Site Deletion Function
```javascript
// Runs daily at 8pm
exports.deleteMarkedSites = functions.pubsub
  .schedule('0 20 * * *')
  .onRun(async (context) => {
    // Find sites where scheduledDeletionDate < now
    // Delete site document
    // Delete all snags subcollection
    // Delete all images from Storage
    // Log deletion for audit
  });
```

#### 4.9.2 Update Tracking Function
```javascript
// Triggered on snag changes
exports.trackSnagUpdates = functions.firestore
  .document('sites/{siteId}/snags/{snagId}')
  .onUpdate(async (change, context) => {
    // Update parent site's lastSnagUpdate
    // Add snag ID to updatedSnags list
    // Increment updateCount
  });
```

---

## 5. Profile Module Requirements

### 5.1 Overview
The Profile module manages user information, company branding, and preferences. It establishes the offline-first pattern that will be used throughout the app.

### 5.2 Data Model

#### 5.2.1 AppUser Class
```dart
class AppUser {
  // Core Fields
  String id;                  // Firebase UID (primary key for both local and cloud)
  String name;
  String email;
  String phone;
  String jobTitle;
  String companyName;
  String postcodeOrArea;
  String dateFormat;          // 'dd-MM-yyyy' or 'MM-dd-yyyy'
  
  // Image Paths (RELATIVE paths only for cross-platform compatibility)
  String? imageLocalPath;     // Relative path: SnagSnapper/{userId}/Profile/profile.jpg
  String? imageFirebasePath;  // Firebase Storage path: users/{userId}/profile.jpg
  String? signatureLocalPath; // Relative path: SnagSnapper/{userId}/Profile/signature.jpg
  String? signatureFirebasePath; // Firebase Storage path: users/{userId}/signature.jpg
  
  // Deletion flags for offline sync (✅ IMPLEMENTED)
  bool imageMarkedForDeletion;     // Track pending image deletion
  bool signatureMarkedForDeletion; // Track pending signature deletion
  
  // Sync Management
  bool needsProfileSync;      // Firestore profile data changed
  bool needsImageSync;        // Firebase Storage image changed  
  bool needsSignatureSync;    // Firebase Storage signature changed
  DateTime? lastSyncTime;     // Last successful sync
  
  // Device Management
  String? currentDeviceId;    // Current device identifier
  DateTime? lastLoginTime;    // Last login timestamp
  
  // Metadata
  DateTime createdAt;
  DateTime updatedAt;
  
  // Versioning
  int localVersion;
  int firebaseVersion;
  
  // Colleague Management (✅ IMPLEMENTED - 2025-08-21)
  List<Colleague>? listOfALLColleagues; // List of all colleagues/sub-contractors
  
  // Future Module Fields (not yet implemented)
  Map<String, String>? mapOfSitePaths;  // For Sites module (Section 7.2) - Map of <SiteID, OwnerID>
}
```

#### 5.2.2 Database Schema
```sql
CREATE TABLE profiles (
  -- Core Data
  id TEXT PRIMARY KEY,        -- Firebase UID
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  job_title TEXT,
  company_name TEXT,
  postcode_area TEXT,
  date_format TEXT DEFAULT 'dd-MM-yyyy',
  
  -- Image Storage (✅ IMPLEMENTED - Using paths not URLs)
  image_local_path TEXT,
  image_firebase_path TEXT,    -- Path not URL
  signature_local_path TEXT,
  signature_firebase_path TEXT, -- Path not URL
  
  -- Deletion Flags (✅ IMPLEMENTED)
  image_marked_for_deletion BOOLEAN DEFAULT FALSE,
  signature_marked_for_deletion BOOLEAN DEFAULT FALSE,
  
  -- Sync Management
  needs_profile_sync BOOLEAN DEFAULT FALSE,
  needs_image_sync BOOLEAN DEFAULT FALSE,
  needs_signature_sync BOOLEAN DEFAULT FALSE,
  last_sync_time INTEGER,
  sync_status TEXT DEFAULT 'pending',
  sync_error_message TEXT,
  sync_retry_count INTEGER DEFAULT 0,
  
  -- Device Management
  current_device_id TEXT,
  last_login_time INTEGER,
  
  -- Timestamps
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  
  -- Versioning
  local_version INTEGER DEFAULT 1,
  firebase_version INTEGER DEFAULT 0
);
```

### 5.3 User Flows

#### 5.3.1 First App Launch / Initial Setup
```
1. User installs app (fresh installation)
2. Login screen appears
3. User logs in with email/Google
4. Generate unique device_id for this device
5. Check local database for profile (will be empty on first install)
6. Attempt to load from Firebase:
   
   a. IF Firebase has profile WITH device_id:
      - Check Realtime Database for existing device session
      - Compare Firebase device_id with current device_id
      - IF SAME device (reinstall scenario):
        - Download profile data
        - Download images to local storage
        - Save all to local database
        - Update Realtime Database session (refresh last_active)
        - Continue to main app
      - IF DIFFERENT device:
        - This is a device switch scenario
        - Follow Device Switching Flow (4.3.2)
   
   b. IF Firebase has profile WITHOUT device_id (legacy/first login):
      - Download profile data
      - Download images to local storage
      - Save to local database with new device_id
      - Update Firebase with device_id
      - Register device in Realtime Database:
        device_sessions/{userId}/current_device: {
          device_id: "new_device_id",
          device_name: "[Device Model]",
          last_active: timestamp,
          force_logout: false
        }
      - Mark as synced
      - Continue to main app
   
   c. IF no Firebase profile (new user):
      - Create new profile
      - Set device_id for this device
      - Save to local database
      - Register device in Realtime Database:
        device_sessions/{userId}/current_device: {
          device_id: "new_device_id",
          device_name: "[Device Model]",
          last_active: timestamp,
          force_logout: false
        }
      - Mark needsProfileSync = true
      - Navigate to profile setup screen
      - Background sync when online

7. Set up device session listener:
   - Listen to Firebase Realtime Database for force_logout
   - Monitor device_sessions/{userId}/force_logout
   - If triggered, execute data deletion flow
   - Update last_active timestamp periodically (e.g., on app resume)
```

#### 5.3.2 Device Switching Flow
```
NEW DEVICE FLOW:
1. User logs in on new device
2. Check local database (empty on new device)
3. Fetch profile from Firebase
4. IF Firebase has different device_id:
   a. Show WARNING dialog:
      "⚠️ Active Session Detected
      
      You are already logged in on another device.
      Device: [Previous Device Name/ID]
      Last active: [Timestamp]
      
      Continuing will:
      • Log out the other device
      • DELETE all local data on that device
      • Any pending updates from that device will be lost
      • Transfer your account to this device
      
      This action cannot be undone."
      
      [Continue on This Device] [Cancel]
   
   b. IF Cancel:
      - Return to login screen
      - No changes made
   
   c. IF Continue:
      - Set 'force_logout' flag in Realtime Database for old device
      - Update device_id to new device in Firebase Firestore profile
      - Update Realtime Database with new device session:
        device_sessions/{userId}/current_device: {
          device_id: "new_device_id",
          device_name: "[New Device Model]",
          last_active: timestamp,
          force_logout: false
        }
      - Download all data from Firebase to new device
      - Save to local database
      - Clear all sync flags (data is now synced)

PREVIOUS DEVICE BEHAVIOR:

Two-Path Detection Approach:

PATH 1 - Real-time Detection (Device is Online):
1. Device has active listener on Realtime Database
2. Listener triggers immediately when force_logout = true
3. Execute data deletion flow

PATH 2 - Session Validation (Device was Offline):
1. On EVERY app launch/resume when online:
2. MANDATORY: Read Firestore profile to check currentDeviceId
3. Compare profile's device_id with local device_id
4. IF different device_id (device was replaced while offline):
   a. Show notification: "Your account is now active on another device"
   b. Clear ALL LOCAL data only:
      - Delete local database
      - Delete all locally cached images
      - Clear SharedPreferences
      - Clear any temporary files
      NOTE: Firebase Storage data remains intact as cloud backup
   c. Firebase Auth sign out
   d. Navigate to login screen
5. IF same device_id:
   a. Set up Realtime Database listener for future detection
   b. Continue normal operation

CRITICAL: Profile read is MANDATORY on every online session because:
- Device could have been replaced while offline
- Listener misses events during offline periods
- App kills terminate listeners
- Ensures 100% detection even after weeks offline

IMPLEMENTATION MECHANISM:
- Use Firebase Realtime Database for instant logout notification
- Store device_sessions/{userId}/current_device:
  {
    device_id: "device_unique_id",
    device_name: "iPhone 13 Pro",
    last_active: timestamp,
    force_logout: false
  }
- Previous device listens to this node for changes
- When force_logout = true, triggers data deletion
```

#### 5.3.3 Profile Editing Flow
```
1. User opens Profile screen
2. Load data from LOCAL database (instant)
3. Display immediately
4. Check sync status, show indicator
5. User edits field (e.g., name)
6. On save:
   a. Update local database immediately
   b. Set needs_profile_sync = true
   c. Update UI (instant feedback)
   d. IF online: Queue background sync
   e. IF offline: Keep flag, sync later
7. User continues working
```

#### 5.3.4 Profile Image Upload Flow (Updated 2025-01-15)

##### User Interaction Flow
```
When Logo Exists:
1. User taps existing logo → Shows "Remove Logo" button only
2. User confirms removal → Logo deleted locally → Shows placeholder
3. Database update (UPDATED 2025-01-20):
   - FOR EXISTING PROFILES: Update database immediately
     * imageLocalPath = null
     * imageMarkedForDeletion = true
     * needsImageSync = true
   - FOR NEW PROFILES: Clear image from UI state only
4. Sync to Firebase queued (delete remote image) - existing profiles only

When No Logo (Placeholder):
1. User taps placeholder → Shows bottom sheet:
   - Take Photo (camera)
   - Choose from Gallery
2. User selects source → Image picker opens
3. Image selected → Processing begins
```

##### Image Processing Pipeline
```
1. Accept Input (Any Format):
   - JPEG, PNG, HEIC, WebP, GIF accepted
   - Max input size: Device/picker limited

2. Auto-Crop to Square:
   - Automatically crop to center square
   - No manual crop interface
   - No preview screen

3. Resize to Fixed Dimensions:
   - Target: 1024x1024 pixels exactly
   - Maintain aspect ratio within square

4. Progressive Compression:
   - Convert to JPEG format
   - Start at 90% quality
   - IF size > 600KB:
     - Reduce quality by 10% steps
     - Minimum quality: 30%
   - IF still > 1MB at 30%:
     - Reject with error message

5. Show Progress:
   - "Resizing..." → "Compressing..." → "Saving..."
   - Step indicators, not percentage

6. Save to Local Storage:
   - Directory: /AppDocuments/SnagSnapper/{userId}/Profile/
   - Filename: profile.jpg (fixed name for auto-overwrite)
   - Previous file automatically overwritten
   - Store RELATIVE path in database

7. Update Database (UPDATED 2025-01-20):
   - FOR EXISTING PROFILES (database entry exists):
     * Update database IMMEDIATELY after image processing
     * imageLocalPath = "SnagSnapper/{userId}/Profile/profile.jpg"
     * needsImageSync = true
     * imageMarkedForDeletion = preserve if true, false otherwise
     * This prevents sync race conditions where background sync could clear the image
   - FOR NEW PROFILES (no database entry yet):
     * Store image path in UI state only
     * Database entry created when Save button is pressed
     * Image path saved as part of initial profile creation
     * Rationale: Cannot update non-existent database entry
   - Clear previous imageFirebasePath if exists

8. Display Immediately:
   - Load from local file path
   - Never use Firebase URL for display
```

##### Sync Behavior
```
1. Background Sync:
   - Triggered on network reconnect
   - Triggered on app foreground
   - Maximum 2 immediate retries per attempt
   - Keep needsImageSync flag on failure
   - Retry forever until successful

2. Upload Process:
   - Upload to Firebase Storage: users/{userId}/profile.jpg
   - Store path (not URL): "users/{userId}/profile.jpg"
  - **CRITICAL**: NO URLs should be stored anywhere in the system
  - Only store paths; URLs can be generated on-demand if needed
   - Update imageFirebasePath in database
   - Set needsProfileSync = true for Firestore update
   - Clear needsImageSync flag after successful upload
   - Clear imageMarkedForDeletion flag

3. Concurrent Changes:
   - IF user deletes/changes during upload:
     - Cancel in-progress upload
     - Process new action
```

##### Error Handling
```
1. Storage Full:
   - Clear app temp files first
   - IF still no space: Show "Not enough storage" error

2. Permission Denied:
   - Grey out camera option with message
   - Gallery remains active
   - Tap greyed camera → Show detailed help with settings link

3. Invalid Image:
   - Show "Invalid image format" error
   - Allow retry

4. Compression Failed (>1MB):
   - Show "Image too complex. Please choose a simpler image"
   - No save, allow retry
```

##### User Feedback
```
Size < 600KB (Optimal):
- Silent save, no size message
- Show generic success

Size 600KB-1MB (Acceptable):
- Silent save, no warning
- Show generic success

Size > 1MB (Rejected):
- "❌ Image too complex. Please choose a simpler image"
- Block save
```

##### Critical Implementation Rules
- NO preview screen after selection
- NO manual cropping interface
- NO original image storage
- NO recovery for deleted images
- NO size warnings if acceptable
- ALWAYS store relative paths
- ALWAYS display from local storage
- NEVER use Firebase URLs for display
- Logo is OPTIONAL field
- NO backward compatibility code (app is in development)
- ALWAYS use current data structures and field names
- NO legacy field name support or migration code

#### 5.3.5 Signature Capture Flow (Added 2025-01-15)

##### User Interaction Flow
```
When No Signature:
1. User sees "Add Signature" placeholder
2. User taps placeholder → Full screen capture opens
3. Canvas shows (portrait locked, white background)
4. User draws with finger/stylus (black ink, 3px)
5. User taps "Use Signature" → Saved to profile
6. User taps "Cancel" → Returns without saving

When Signature Exists:
1. User sees signature preview with 'X' button
2. User taps 'X' → Confirmation: "Delete signature?"
3. User confirms → Signature deleted locally
4. signatureMarkedForDeletion = true, needsSignatureSync = true
5. User taps signature → Opens new capture (fresh canvas)
```

##### Signature Processing
```
1. Canvas Setup:
   - Screen: Portrait locked orientation
   - Canvas: 16:9 landscape aspect ratio (640x360px) within portrait screen
   - If device width < 640px: Scale canvas proportionally to fit
   - White canvas on dark grey background
   - Fixed colors (not theme-dependent)

2. Drawing Specs:
   - Black ink (#000000)
   - Fixed 3px stroke width
   - No pressure sensitivity
   - No guides or helpers

3. Save Process:
   - Auto-crop all whitespace
   - Convert to JPEG (95% quality)
   - No compression needed (estimated 10-30KB file size)
   - No validation (any mark accepted)
   - Save to: SnagSnapper/{userId}/Profile/signature.jpg (fixed name, JPEG format)
   - Previous file automatically overwritten
   - Note: Canvas is 640x360px, black on white = highly compressible

4. Database Update:
   - signatureLocalPath = relative path
   - needsSignatureSync = true
   - signatureMarkedForDeletion = preserve if true, false otherwise
   - Previous signature file automatically overwritten
```

##### Sync Behavior
```
Same as profile image:
- Background sync when online
- Upload to: users/{userId}/signature.jpg (JPEG format)
- Store path (not URL): "users/{userId}/signature.jpg"
- Delete from Firebase if signatureMarkedForDeletion && signatureLocalPath == null
- Set needsProfileSync = true for Firestore update
- Retry forever until successful
```

#### 5.3.6 Critical Offline Scenarios

##### Delete-Then-Add Scenario (Key Design Decision)
```
When user deletes then adds an image while offline:

1. User has synced image
2. Deletes image (offline):
   - imageLocalPath = null
   - imageMarkedForDeletion = true (PERSISTS!)
   - needsImageSync = true
   - imageFirebasePath = "users/{userId}/profile.jpg" (kept for reference)

3. Adds new image (still offline):
   - imageLocalPath = "SnagSnapper/{userId}/Profile/profile.jpg"
   - imageMarkedForDeletion = true (STILL TRUE - this is critical!)
   - needsImageSync = true
   - imageFirebasePath = "users/{userId}/profile.jpg" (unchanged)

4. When sync runs:
   - Skip deletion (optimization - new image will overwrite)
   - Upload new image from imageLocalPath (auto-overwrites in Firebase)
   - Set needsProfileSync = true
   - Update Firestore with path "users/{userId}/profile.jpg"
   - Clear all flags after successful sync

Key Point: imageMarkedForDeletion persists through the add operation
until sync completes. This ensures proper cleanup in Firebase.
```

#### 5.3.7 Colleague Management Flow (✅ IMPLEMENTED - 2025-08-21)

##### Overview
Colleagues are sub-contractors or team members that can be added to the user's profile for future assignment to sites and snags. This feature is part of the Profile module but designed to support future Site and Snag modules.

##### Data Model
```dart
class Colleague {
  String name;      // Required
  String email;     // Required 
  String phone;     // Optional
  String company;   // Optional
  String trade;     // Optional (e.g., "Electrician", "Plumber")
}
```

##### User Flow
```
1. Profile Screen Display:
   - Section appears after signature capture
   - Shows "Colleagues" header with "Add" button
   - Lists all existing colleagues with name and email
   - Each colleague has "Edit" and "Delete" buttons

2. Adding a Colleague:
   - User taps "Add Colleague" button
   - Modal/dialog opens with form fields
   - User enters: Name (required), Email (required), Phone, Company, Trade
   - User taps "Save" → Colleague added to local list
   - UI updates immediately
   - Profile marked for sync

3. Editing a Colleague:
   - User taps edit icon on colleague
   - Same form opens pre-filled
   - User modifies fields
   - User taps "Save" → Updates locally
   - Profile marked for sync

4. Deleting a Colleague:
   - User taps delete icon
   - Confirmation dialog: "Delete colleague [Name]?"
   - User confirms → Removed from list
   - Profile marked for sync
```

##### Storage & Sync
```
1. Local Storage:
   - Colleagues stored as JSON array in profiles table
   - Field: listOfALLColleagues (JSON column)
   - Updates trigger needsProfileSync flag

2. Firebase Sync:
   - Stored in Firestore as 'colleagues' array field
   - Each colleague serialized as map
   - Entire array replaced on sync (not incremental)
   
3. Critical Implementation Detail:
   - MUST use List<Colleague>.from() when copying colleague lists
   - Avoid reference sharing between UI state and database models
   - This prevents the _hasColleaguesChanged() detection from failing
```

##### Known Issues Fixed (2025-08-21)
- Bug #016: Colleagues overwriting in Firebase - Fixed by avoiding reference sharing
- Bug #017: Colleagues not downloading after reinstall - Fixed copyWith method  
- Bug #018: Colleague changes not detected - Fixed with proper list copying

#### 5.3.8 Manual Sync Flow
```
1. User taps sync button
2. Check connectivity
3. IF online:
   a. Show sync progress
   b. Upload profile changes (including colleagues)
   c. Upload pending images
   d. Clear sync flags on success
   e. Update sync indicator
4. IF offline:
   a. Show "No connection" toast
   b. Keep changes local
```

### 5.4 UI Components

#### 5.4.1 Profile Screen
- **Header**: Company logo display
- **Form Fields**: Name, email, phone, job title, company, postcode
- **Image Upload**: Camera/gallery selection for logo
- **Signature Capture**: Full-screen drawing pad for digital signature
- **Date Format**: Toggle between UK/US formats
- **Sync Indicator**: Shows pending changes count

#### 5.4.2 Sync Indicator Design (Selected: Option C)
**Status Bar Implementation**
- Position: Below app bar
- Shows: "X changes pending sync" 
- Button: "SYNC NOW" when changes exist
- Colors:
  - Orange background when changes pending
  - Green background when fully synced
  - Red background when sync error
- Height: 40px
- Animation: Slide down when status changes
- Auto-hide: After 3 seconds when synced
- Persistent: When changes pending or error

### 5.5 Validation Rules

#### 🔴 CRITICAL REQUIREMENT: Validation Consistency
**Local validation MUST exactly match Firebase validation rules**
- This is MANDATORY for security and smooth operations
- Any mismatch will cause sync failures and poor user experience
- Update both local validators AND Firebase Security Rules together
- Test that validation is identical before deploying

#### 5.5.1 Field Validations
- **Name**: Required, 2-50 characters
- **Email**: Required, valid email format
- **Phone**: Optional, valid phone format
- **Job Title**: Required, 2-50 characters
- **Company Name**: Required, 2-100 characters
- **Postcode**: Optional, alphanumeric

#### 5.5.2 Image Validations
- **Profile Image**: Max 5MB input, converted to JPEG
- **Signature**: Max 2MB input, converted to JPEG
- **Format**: All images converted to JPEG
- **Max Dimensions**: Fixed at 1024x1024 pixels (required)
- **Two-Tier Size Validation**:
  - **Optimal Target**: < 600KB (preferred)
  - **Maximum Limit**: < 1MB (acceptable)
  - **Compression Strategy**:
    1. Start with 90% JPEG quality (better first-pass success)
    2. If size > 600KB, reduce quality iteratively (by 10% steps)
    3. Stop at 30% quality minimum (don't go lower)
    4. Final validation:
       - If ≤ 600KB → Save as "optimal"
       - If 600KB-1MB → Save as "acceptable" with warning
       - If > 1MB → Reject with error message
- **User Feedback**:
  - Optimal: "✅ Image optimized successfully (size: XXXkB)"
  - Acceptable: "⚠️ Image compressed to XXXkB (larger than optimal)"
  - Rejected: "❌ Image too complex. Please choose a simpler image"

### 5.6 Error Handling 

#### 5.6.1 Sync Errors
- Network timeout: Retry with exponential backoff
- Firebase quota: Show warning, disable auto-sync
- Conflict: Local version wins
- Corrupted data: Fallback to Firebase

#### 5.6.2 Storage Errors
- Disk full: Show warning to user
- Corrupted image: Clear and re-download
- Missing file: Fallback to placeholder

#### 5.6.3 Crash & Error Reporting
- **Firebase Crashlytics Integration**:
  - Automatic crash reports with stack traces
  - Non-fatal error logging for handled exceptions
  - User identification (anonymous user ID only)
  - Custom keys for debugging context
  
- **Breadcrumb Trail**:
  - Log user actions before crash (last 20 events)
  - Track navigation flow: "Profile → Camera → Image Selected"
  - Record sync events: "Sync Started → Network Error → Retry Queued"
  - Include device state: online/offline, battery level, storage space
  
- **Implementation Pattern**:
  ```dart
  // Before risky operations
  FirebaseCrashlytics.instance.log('Starting image upload');
  FirebaseCrashlytics.instance.setCustomKey('image_size', fileSize);
  
  // In catch blocks
  FirebaseCrashlytics.instance.recordError(
    error,
    stackTrace,
    reason: 'Image upload failed',
    fatal: false,
  );
  ```
  
- **Privacy Compliance**:
  - No PII in breadcrumbs (no names, emails, phones)
  - Use anonymous identifiers only
  - Clear logs on user logout
  - GDPR compliant data retention (30 days)

### 5.7 Performance Requirements
- Profile load: < 100ms from local DB
- Image display: < 200ms from local storage
- Sync operation: Non-blocking background
- UI response: Always immediate

### 5.8 Security Requirements
- **No sensitive data in logs**: Never log passwords, tokens, or user PII
  - Review all debug statements before commits
  - Use breadcrumbs instead of full data dumps
  - Zero runtime overhead, high security value
  
- **Platform encryption**: Automatic iOS/Android disk encryption
  - iOS: Automatic with device passcode (since iOS 8)
  - Android: File-based encryption (since Android 10)
  - No code required - OS handles transparently
  
- **Secure credential storage**: Use platform secure storage for sensitive data
  - Implementation: `flutter_secure_storage` package
  - Store: device_id, session tokens, sync credentials
  - Benefit: Protected from rooted device access
  - Marketing value: "Military-grade secure storage"

- **Firebase App Check**: Protect backend resources from abuse
  - Already implemented in the app
  - Validates requests are from legitimate app instances
  - Prevents API abuse, bot attacks, and billing fraud
  - Attestation providers:
    - iOS: DeviceCheck or App Attest
    - Android: Play Integrity API
    - Web: reCAPTCHA v3
  - Protects: Firestore, Storage, Functions, and Realtime Database
  - Marketing value: "Enterprise-grade API protection"

---

## 6. Implementation Plan

### Test-Driven Development (TDD) Approach
**CRITICAL: Every phase follows TDD methodology**
1. **Write Tests First**: Before implementing any functionality, write comprehensive tests
2. **Red Phase**: Tests fail initially (no implementation)
3. **Green Phase**: Implement minimum code to pass tests
4. **Refactor Phase**: Improve code quality while keeping tests green
5. **Phase Completion**: Phase is ONLY marked complete when ALL tests pass

### 6.1 Phase 1: Database Setup (Week 1)

#### Tests First (Day 1-2)
1. Write unit tests for database service initialization
2. Write tests for Profile table CRUD operations
3. Write tests for data validation and constraints
4. Write tests for migration scenarios

#### Implementation (Day 3-4)
1. Add Drift dependencies
2. Create database service
3. Implement Profile table
4. Create data access layer

#### Verification (Day 5)
- All database tests must pass
- Test coverage > 90% for database layer
- Performance benchmarks met (< 100ms for operations)

### 6.2 Phase 2: Profile UI Integration (Week 2)

#### Tests First (Day 1-2)
1. Write widget tests for Profile screen state management
2. Write tests for form validation and error handling
3. Write tests for image selection and display
4. Write integration tests for database-UI interaction

#### Implementation (Day 3-4)
1. Update Profile screen to use database
2. Implement image storage service
3. Add sync status indicators
4. Handle offline editing

#### Verification (Day 5)
- All UI tests must pass
- Widget tests cover all user interactions
- Integration tests verify data flow

### 6.3 Phase 3: Sync Service (Week 3)

#### Tests First (Day 1-2)
1. Write unit tests for sync logic
2. Write tests for conflict resolution
3. Write tests for retry mechanisms
4. Write tests for offline queue management

#### Implementation (Day 3-4)
1. Implement background sync
2. Add manual sync trigger
3. Handle conflict resolution
4. Implement retry logic

#### Verification (Day 5)
- All sync tests must pass
- Test various network conditions
- Verify data integrity after sync

### 6.4 Phase 4: Device Management (Week 4)

#### Tests First (Day 1-2)
1. Write tests for device ID generation and storage
2. Write tests for single device enforcement
3. Write tests for device switching flows
4. Write tests for data cleanup on device switch

#### Implementation (Day 3-4)
1. Add device ID tracking
2. Implement single device login
3. Handle device switching
4. Implement force logout mechanism

#### Verification (Day 5)
- All device management tests must pass
- Multi-device scenarios tested
- Data deletion verified

### 6.5 Phase 5: Integration & Polish (Week 5)

#### Tests First (Day 1-2)
1. Write end-to-end integration tests
2. Write performance tests
3. Write stress tests for sync
4. Write tests for error recovery

#### Implementation (Day 3-4)
1. Performance optimization
2. Error handling refinement
3. UI polish and animations
4. Memory leak fixes

#### Final Verification (Day 5)
- ALL tests must pass (100% success rate)
- Test coverage > 80% overall
- Performance benchmarks met
- No memory leaks detected
- Offline scenarios fully functional

---

## 7. Success Metrics

### 7.1 Technical Metrics
- 100% offline functionality
- < 200ms UI response time
- < 5% sync failure rate
- 90% reduction in Firebase reads

### 7.2 User Metrics
- Profile completion rate > 90%
- Sync success rate > 95%
- User satisfaction > 4.5/5
- Support tickets < 5% of users

---

## 8. Implementation Status

### 8.1 Profile Module - COMPLETED ✅

#### Core Features
- ✅ **Local Database (Drift/SQLite)** - Fully implemented with DAOs
- ✅ **Offline-First Architecture** - All features work offline
- ✅ **Profile Data Management** - Complete CRUD operations
- ✅ **Image Management** - Upload, display, delete with compression
- ✅ **Signature Management** - Capture, save, sync functionality
- ✅ **Deletion Flags** - `imageMarkedForDeletion` and `signatureMarkedForDeletion` implemented
- ✅ **Firebase Paths** - Using paths not URLs as per design
- ✅ **Sync Service** - Background sync with conflict resolution
- ✅ **Race Condition Prevention** - Fixed delete-then-add image scenario
- ✅ **Auto-Sync Triggers** - Sync automatically triggers after image operations

#### Technical Implementation
- ✅ **AppUser Model** - Complete with all fields including deletion flags
- ✅ **ProfileDao** - Full database operations
- ✅ **ProfileSyncHandler** - Handles images, signatures, and profile data sync
- ✅ **ImageCompressionService** - Two-tier validation (600KB/1MB)
- ✅ **ImageStorageService** - Local file management
- ✅ **SignatureService** - Signature capture and storage
- ✅ **ConflictResolver** - Handles sync conflicts

#### UI Components
- ✅ **ProfileScreen** - Complete UI implementation
- ✅ **Image Picker** - Camera and gallery selection
- ✅ **Signature Pad** - Drawing and capture
- ✅ **Sync Status Indicators** - Visual feedback for sync state
- ✅ **Error Handling** - User-friendly error messages

#### Test Coverage
- ✅ **Unit Tests** - DAOs, services, and utilities
- ✅ **Widget Tests** - UI components and interactions
- ✅ **Integration Tests** - End-to-end offline-first flows
- ✅ **Manual Testing** - Airplane mode verification

### 8.2 Known Issues - RESOLVED ✅
- ✅ **Race Condition Bug** - Fixed: Images no longer disappear when rapidly deleting and adding
- ✅ **Persistent Sync Icon** - Fixed: Auto-sync triggers ensure sync completes
- ✅ **Missing Documentation** - Fixed: PRD and implementation plans updated

### 8.3 Pending Improvements
- ⏳ **Memory Optimization** - Further optimize image caching
- ⏳ **Performance Monitoring** - Add metrics collection
- ⏳ **Additional Tests** - Expand edge case coverage

---

## 9. Future Modules (Not Yet in Scope)

### 9.1 Colleagues Module (✅ PARTIALLY IMPLEMENTED)
**Implemented (2025-08-21):**
- ✅ Add colleagues and sub-contractors to profile
- ✅ Manage team member details (name, email, phone, company, trade)
- ✅ Edit and delete colleagues
- ✅ Offline-first storage with Firebase sync
- ✅ JSON serialization for database storage

**Not Yet Implemented:**
- ⏳ Assign permissions and access levels
- ⏳ Share sites with specific colleagues  
- ⏳ Track colleague activity on sites
- ⏳ Assignment workflow for snags

### 9.2 Sites Module (See Section 4 for Full Requirements)
- Site creation and management
- Site images and details
- Archive functionality
- Colleague access management
- Follows same offline-first pattern

### 9.3 Snags Module
- Snag documentation with location and details
- Multiple images per snag (before/after)
- Assignment workflow:
  - Site manager assigns snag to contractor
  - Contractor receives notification
  - Contractor updates progress and adds photos
  - Two-way sync between manager and contractor
  - Manager reviews and closes completed snags
- Status tracking (Open, In Progress, Pending Review, Closed)
- Follows same offline-first pattern with conflict resolution

### 9.4 Reports Module
- PDF generation
- Custom branding
- Email distribution
- Offline report generation

---

## 10. Appendix

### 10.1 Dependencies
```yaml
dependencies:
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.0.0
  path: ^1.8.0
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.5.0
  firebase_database: ^10.3.0  # For Realtime Database device management
  firebase_crashlytics: ^3.4.0  # For crash reporting and breadcrumbs
  connectivity_plus: ^5.0.0
  image_picker: ^1.0.0
  image: ^4.0.0
  flutter_secure_storage: ^9.0.0  # For secure credential storage
```

### 10.2 File Structure
```
/lib
  /data
    /database
      - app_database.dart
      - profile_dao.dart
    /models
      - app_user.dart
  /services
    - sync_service.dart
    - image_service.dart
    - device_service.dart
  /screens
    /profile
      - profile_screen.dart
      - profile_viewmodel.dart
```

---

## Document History
- **2025-01-10**: Initial PRD with Profile module requirements
- **2025-01-18**: Updated image handling specifications:
  - Changed compression start from 85% to 90% for better first-pass success
  - Changed from storing Firebase URLs to storing paths
  - Added imageMarkedForDeletion and signatureMarkedForDeletion fields
  - Documented critical delete-then-add offline scenario
  - Fixed file naming to use static names (profile.jpg, signature.jpg) for auto-overwrite
- **Next Update**: Sites module requirements (when in scope)

---

## Marketing Copy Consolidation

### App Store Short Description (80 chars)
"Professional construction snagging that works offline. Capture, assign, report."

### App Store Keywords
construction, snagging, defects, site management, offline, contractor, builder, inspection, snag list, punch list, quality control, field service

### Play Store Short Description (80 chars)
"Offline construction site management. Document snags, assign tasks, generate PDFs"

### Full Marketing Description (For Both Stores)
**SnagSnapper - Professional Site Management That Works Everywhere™**

Finally, a construction management app that works perfectly without internet! Designed by contractors for contractors, SnagSnapper delivers professional site management that never lets you down.

**Why Construction Professionals Choose SnagSnapper:**

✅ **100% Offline Reliability**
Never lose work due to poor signal. Complete full site inspections, document every snag, and generate reports - all without internet.

🔒 **Enterprise-Grade Security**
• Military-grade secure storage with encryption
• Firebase App Check API protection
• Single-device login prevents data breaches
• GDPR compliant with privacy-first design
• Automatic crash reporting for reliability

⚡ **Lightning-Fast Performance**
• Instant photo capture and annotation
• Immediate snag documentation
• Zero waiting for network operations
• Smooth, responsive interface

🤝 **Seamless Team Collaboration**
• Assign snags to contractors instantly
• Two-way sync between site and office
• Real-time updates when connected
• Track progress with photo evidence

📊 **Professional Reporting**
• Generate branded PDF reports on-site
• Include your company logo
• Comprehensive snag documentation
• Photo evidence included
• Client-ready presentation

🔄 **Smart Sync Technology**
• Automatic background sync when connected
• Never lose data when switching devices
• Seamless device switching for field teams
• Intelligent conflict resolution

**Perfect For:**
• Site Managers & Supervisors
• Main Contractors
• Subcontractors
• Property Developers
• Building Inspectors
• Facility Managers
• Quality Control Teams

**Key Features:**
• Complete offline functionality
• Photo documentation with annotations
• Custom company branding
• Digital signature capture
• Snag assignment workflow
• Progress tracking
• PDF report generation
• Secure cloud backup
• Multi-site management
• Date format options (UK/US)

**No Hidden Costs:**
• No monthly subscriptions
• No per-user fees
• No data limits
• Enterprise features at small business pricing

**Built for Real Construction Sites:**
SnagSnapper understands that construction sites have poor connectivity. That's why every feature works perfectly offline. Document snags in basements, capture photos in remote locations, and manage your entire site without worrying about signal strength.

**Get Started in Minutes:**
1. Download SnagSnapper
2. Create your profile with company branding
3. Start documenting snags immediately
4. Sync when convenient

Join thousands of construction professionals who trust SnagSnapper for reliable, professional site management that works everywhere.

Download now and experience the difference of truly offline-first construction management.

---

### Premium Security Features Badge Text:
🛡️ **Security You Can Trust**
• Bank-grade encryption
• Military-grade secure storage  
• Enterprise API protection
• GDPR compliant
• Privacy-first design

### Performance Badge Text:
⚡ **Unmatched Performance**
• Works 100% offline
• Instant operations
• No network delays
• Lightning-fast UI
• Background sync

### Collaboration Badge Text:
🤝 **Team Collaboration Made Simple**
• Real-time assignments
• Two-way sync
• Progress tracking
• Photo evidence
• Instant updates

---

*This document serves as the single source of truth for SnagSnapper requirements and will be updated as development progresses.*
