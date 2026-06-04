# Site Creation Consolidation Plan

## Overview
Migrate Sites from direct Firebase writes to offline-first architecture, following the Profile module pattern.

## Approach
- Small, incremental features
- Debug statements for verification
- User tests each feature before moving to next
- Document progress for context switching

---

## Phase 1: Create SiteSyncHandler

### Feature 1.1: Basic SiteSyncHandler Structure
**Status**: COMPLETE
**File**: `lib/services/sync/handlers/site_sync_handler.dart`

Create empty class with:
- Constructor with dependencies (AppDatabase, FirebaseFirestore, FirebaseStorage, ImageStorageService)
- Debug print in constructor to verify instantiation

**Verification**: Instantiate in test, see debug output
**Completed**: 2026-06-03

---

### Feature 1.2: syncSiteData() - Upload Site Metadata
**Status**: COMPLETE
**Depends on**: 1.1
**Completed**: 2026-06-03

Implement method to:
1. Get site from local DB by ID
2. Check `needsSiteSync` flag
3. Validate site data
4. Upload to Firestore `Profile/{ownerUID}/Sites/{siteID}`
5. Clear `needsSiteSync` flag on success

**Debug prints**:
- "SiteSyncHandler: Starting syncSiteData for site {id}"
- "SiteSyncHandler: Site data validated"
- "SiteSyncHandler: Uploaded to Firestore successfully"
- "SiteSyncHandler: Cleared needsSiteSync flag"

**Verification**: Create site locally with flag, call sync, check Firebase ✅ VERIFIED

**Implementation notes**:
- Added helper methods to SiteDao: `clearSiteSyncFlag()`, `clearImageSyncFlag()`, `updateImageFirebasePath()`, `updateImageLocalPath()`
- Uses Site.toFirestore() for data conversion
- Validates: name, ownerUID, ownerEmail (with email regex)
- Includes 3-retry logic with exponential backoff
- Firestore's built-in offline persistence queues writes when offline

**Test Results (2026-06-03)**:
- TEST 1 Happy Path: ✅ PASSED - Upload + flag cleared
- TEST 2 Sync Not Needed: ✅ PASSED - Correctly skipped
- TEST 3 Offline: ✅ PASSED - Firestore queued, synced on reconnect

---

### Feature 1.3: syncSiteImage() - Upload Site Image
**Status**: VERIFIED
**Depends on**: 1.2
**Completed**: 2026-06-03

Implement method to:
1. Get site from local DB
2. Check `needsImageSync` flag
3. Handle scenarios: upload new, delete old, replace
4. Upload to Firebase Storage `sites/{ownerUID}/{siteID}/site.jpg`
5. Update `imageFirebasePath` in local DB
6. Clear `needsImageSync` flag

**Debug prints**:
- "SiteSyncHandler: Starting syncSiteImage for site {id}"
- "SiteSyncHandler: Image scenario - {upload/delete/replace}"
- "SiteSyncHandler: Uploaded to Storage: {path}"
- "SiteSyncHandler: Updated imageFirebasePath in local DB"

**Verification**: Create site with image locally, call sync, check Storage ✅ VERIFIED

**Implementation notes**:
- Added `imageMarkedForDeletion` field to Site model and Sites table for replace scenario
- Added `markImageForDeletion()` and `clearImageDeletionFlag()` to SiteDao
- Fixed `SiteDao.updateSite()` to preserve `needsImageSync` and `imageMarkedForDeletion` flags
- Fixed `Site.create()` to accept `imageLocalPath` and set `needsImageSync: true` when image provided
- Fixed `SiteService.createSite()` to pass `imagePath` to `Site.create()`
- Updated Firestore rules with security fixes (ownerUID validation, max string length)
- Updated Storage rules with correct path and 2MB limit

**Test Results (2026-06-03)**:
- TEST 1 Site Data Sync: ✅ PASSED
- TEST 2 Site Sync Not Needed: ✅ PASSED
- TEST 3 Image Upload: ✅ PASSED - Uploaded to Storage
- TEST 4 Image Sync Not Needed: ✅ PASSED

---

### Feature 1.35: MySites Screen - Display Sites from Local DB
**Status**: COMPLETE
**Depends on**: 1.3
**Completed**: 2026-06-04

Update MySites screen to:
1. Load sites from local SQLite database (SiteDao)
2. Display as Grid OR List view (user toggleable)
3. Memory efficient using `GridView.builder` / `ListView.builder`
4. IconButton in AppBar to switch between Grid/List views
5. Show site image, name, and basic info

**UI Requirements**:
- Grid view: 2 columns, site image with name overlay
- List view: Site image thumbnail, name, company, snag counts
- Empty state when no sites
- Pull-to-refresh (optional)

**Debug prints**:
- "MySites: Loading sites from local DB"
- "MySites: Found {n} sites"
- "MySites: View switched to {grid/list}"

**Verification**: Create sites, see them in MySites screen in both views

**Implementation notes (2026-06-04)**:
- Created `lib/Widgets/site_grid_tile.dart` - grid tile using new Site model
- Created `lib/Widgets/site_list_tile.dart` - list tile using new Site model
- Updated `lib/Screens/Sites/mySites.dart` - added grid/list toggle in AppBar
- Updated `lib/Screens/Sites/Tabs/ownedSites.dart` - uses SiteDao stream, new Site model
- Updated `lib/Screens/Sites/Tabs/sharedSites.dart` - uses SiteDao stream, new Site model
- Images load from `imageLocalPath` (relative file path) instead of base64

---

### Feature 1.36: Download Owned Sites on Sign-In
**Status**: TESTED ✅ (Bug Fixed & Verified 2026-06-05)
**Depends on**: 1.35
**Completed**: 2026-06-04

Implements data integrity check and site download on sign-in per PRD Section 5.3.1.

**Flow:**
1. On sign-in, ProfileSyncHandler.syncProfileData() checks if local profile exists
2. If no local profile for current user, check if ANY profile exists (different user's data)
3. If different user's data exists → AppDatabase.clearAllData()
4. Download profile from Firebase
5. MainMenu `_checkForPendingSync()` detects empty local sites
6. Triggers `syncNow()` which calls `SiteSyncHandler.downloadAllOwnedSites()`

**Bug Fix (2026-06-05):**
- **Problem**: `_checkForPendingSync()` only triggered `syncNow()` for upload needs (profileNeedsSync, sitesNeedUpload). After user switch/force logout, both flags were false, so download never triggered.
- **Root Cause**: Missing check for "sites need download" scenario in mainMenu.dart
- **Fix**: Added `sitesNeedDownload` check using `getOwnedSites(userId).isEmpty`
- **Cleanup**: Changed `getOwnedSites()` to use `ownerUID` instead of `ownerEmail` (consistent with Firebase path structure). Removed unused methods: `getAllSites`, `getSharedSites`, `getActiveSites` from site_dao.dart and site_service.dart.

**Files Modified:**
- `lib/Data/database/daos/profile_dao.dart` - Added `getSavedProfile()` method
- `lib/services/sync/handlers/profile_sync_handler.dart` - Added data integrity check
- `lib/Data/database/daos/site_dao.dart` - Added `upsertSite()`, changed `getOwnedSites()` to use UID
- `lib/services/sync/handlers/site_sync_handler.dart` - Added `downloadSiteImage()`, `downloadAllOwnedSites()`
- `lib/services/sync_service.dart` - Added SiteSyncHandler, simplified to use `_userId!`
- `lib/Screens/mainMenu.dart` - Added `sitesNeedDownload` check to trigger download

**Test Plan:**
1. Sign out from app
2. Sign in as user with sites in Firebase
3. Sites should auto-download (check debug logs for "Pending sync - download: true")
4. Open MySites screen
5. Verify sites appear with images

**Architecture Decisions:**
- Images stored as RELATIVE paths in DB (iOS absolute paths change on reinstall)
- SyncService orchestrates handlers (ProfileSyncHandler & SiteSyncHandler stay decoupled)
- Firestore rules: `Profile/{userId}/Sites/{siteId}` - owner read/write only
- Storage rules: `sites/{ownerUID}/{siteId}/site.jpg` - owner read/write, 2MB max
- `saveSiteImageFromBytes()` handles compression and returns relative path
- Site queries use `ownerUID` (consistent with Firebase path), not `ownerEmail`

**Scenarios Handled:**
- User switch (A→B): DB cleared by ProfileSyncHandler → download triggered
- Force logout: DB cleared by `_handleForceLogout()` → download triggered
- New device: No local data → download triggered
- Same user sign out/in: Data persists → no download needed (correct)

**Test Results (2026-06-05):**
- ✅ User A (rfsingh81) sign-in: 1 site downloaded with image
- ✅ User switch A→B (djsrajjo): Data cleared, 3 sites downloaded
- ✅ User switch B→A: Data cleared, 1 site re-downloaded
- ✅ Debug log shows: `MainMenu: Pending sync - profile: false, upload: 0, download: true`
- ✅ All site images downloaded and saved correctly

---

### Feature 1.4: downloadSite() - Download Single Site from Firebase
**Status**: NOT STARTED
**Depends on**: 1.36

Implement method to:
1. Fetch site document from Firestore
2. Convert to Site model using `Site.fromFirestore()`
3. Return Site object (caller decides whether to save)

**Debug prints**:
- "SiteSyncHandler: Downloading site {id} from owner {ownerUID}"
- "SiteSyncHandler: Fetched document, exists: {true/false}"
- "SiteSyncHandler: Converted to Site model"

**Verification**: Call with known Firebase site ID, verify data returned

---

### Feature 1.5: downloadSiteImage() - Download Site Image
**Status**: COMPLETE (implemented in Feature 1.36)
**Depends on**: 1.4

Implemented as `SiteSyncHandler.downloadSiteImage()` in Feature 1.36.
- Downloads from Firebase Storage
- Saves using `imageStorage.saveSiteImageFromBytes()`
- Stores RELATIVE path in DB (iOS absolute paths change)

---

### Feature 1.6: syncAll() - Batch Sync All Sites
**Status**: COMPLETE (integrated into SyncService.syncNow())
**Depends on**: 1.2, 1.3
**Completed**: 2026-06-04

Instead of a separate `syncAll()` method in SiteSyncHandler, batch upload was integrated directly into `SyncService.syncNow()`:

1. Query all sites needing sync via `SiteDao.getSitesNeedingSync()`
2. Loop through and call `syncSiteData()` and `syncSiteImage()` as needed
3. Includes cancellation checks between sites
4. Adds "sites:N" to syncedItems

**Debug prints** (in SyncService):
- "SyncService.syncNow: Found {n} sites needing sync"
- "SyncService.syncNow: Syncing site {id} - {name}"
- "SyncService.syncNow: Synced {n}/{total} sites"

**Verification**: Create site → auto-sync triggered → uploaded to Firebase ✅

---

## Phase 1 Completion Criteria
- [x] Feature 1.1 complete and verified
- [x] Feature 1.2 complete and verified
- [x] Feature 1.3 complete and verified
- [x] Feature 1.35 complete (MySites UI)
- [x] Feature 1.36 VERIFIED (download owned sites on sign-in)
- [ ] Feature 1.4 NOT STARTED (download single site - for shared sites)
- [x] Feature 1.5 complete (implemented in 1.36)
- [x] Feature 1.6 COMPLETE (batch upload integrated into syncNow via Phase 2.3)

---

## Phase 2: Update SyncService (After Phase 1)

### Feature 2.1: Add SiteSyncHandler Instance
**Status**: COMPLETE (done in Feature 1.36)

### Feature 2.2: Add syncSites() Method
**Status**: COMPLETE (integrated directly into syncNow())
**Completed**: 2026-06-04

### Feature 2.3: Integrate into syncNow()
**Status**: VERIFIED
**Completed**: 2026-06-04

Added site upload logic to `SyncService.syncNow()`:
- Queries `SiteDao.getSitesNeedingSync()` for sites with sync flags
- Loops through each site, calls `syncSiteData()` and `syncSiteImage()`
- Includes cancellation checks between sites
- Adds "sites:N" to syncedItems on success

**Test Results (2026-06-04)**:
- Site created → watcher detected → syncNow triggered → uploaded to Firebase ✅
- Debounce working: duplicate sync requests rejected with "Already syncing" ✅
- Flags cleared only after confirmed upload success ✅

---

## Phase 3: Update MainMenu (After Phase 2)

### Feature 3.1: Add Site Sync State Variables
**Status**: COMPLETE
**Completed**: 2026-06-04

Added to MainMenu:
- `bool _sitesNeedSync` - tracks if sites need syncing
- `StreamSubscription? _siteSyncSubscription` - holds the watcher subscription

### Feature 3.2: Add Site Sync Listener
**Status**: COMPLETE
**Completed**: 2026-06-04

Added `_setupSiteSyncListener()` method:
- Subscribes to `SiteDao.watchSitesNeedingSync()`
- Updates `_sitesNeedSync` state when sites need sync
- Triggers `_checkForPendingSync()` when sync needed

Also added `watchSitesNeedingSync()` to SiteDao:
- Efficient DB-level filter: `WHERE needsSiteSync=1 OR needsImageSync=1`
- ONE stream subscription for all sites (not per-site)
- Only re-queries when Sites table changes

### Feature 3.3: Add Pending Sync Check
**Status**: COMPLETE
**Completed**: 2026-06-04

Updated `_checkForPendingSync()`:
- Now checks both profile AND sites for pending sync
- Triggers `syncNow()` if either needs syncing
- Added site subscription cancel in `dispose()`

---

## Phase 4: Migrate ContentProvider (After Phase 3)

### Feature 4.1: Migrate addSite()
### Feature 4.2: Migrate updateSite()
### Feature 4.3: Migrate loadOwnedSites()
### Feature 4.4: Migrate loadSharedSites()

---

## Phase 5: Complete siteInfo.dart (After Phase 4)

### Feature 5.1: Remove Old Site Import
### Feature 5.2: Update _loadValuesFromSite()
### Feature 5.3: Update _saveSite() for Updates

---

## Progress Log

| Date | Feature | Status | Notes |
|------|---------|--------|-------|
| 2026-06-03 | 1.1 | COMPLETE | Basic structure with constructor, debug print |
| 2026-06-03 | 1.2 | VERIFIED | syncSiteData() - all 3 edge cases tested and passed |
| 2026-06-03 | 1.3 | VERIFIED | syncSiteImage() - all 4 tests passed, fixed flag preservation bugs |
| 2026-06-04 | 1.35 | COMPLETE | MySites loads from SiteDao, grid/list toggle, new Site model |
| 2026-06-04 | 1.36 | VERIFIED | Download owned sites on sign-in with data integrity check |
| 2026-06-04 | 2.1-2.3 | VERIFIED | Site upload integrated into syncNow(), tested end-to-end |
| 2026-06-04 | 3.1-3.3 | VERIFIED | MainMenu site sync watcher, auto-triggers upload on site create |
| 2026-06-05 | 1.36 | TESTED | Bug fix verified - user switch A→B→A, all sites download correctly |

---

## Context Recovery Notes

**Current state**: Phase 1, 2, 3 COMPLETE - Site sync fully operational (bug fixed)

**What's working now:**
1. Create site locally → saved to SQLite with sync flags
2. MainMenu's `watchSitesNeedingSync()` detects new site needing upload
3. MainMenu's `_checkForPendingSync()` detects empty local sites needing download
4. `syncNow()` automatically uploads/downloads site data + images
5. Flags cleared only after confirmed upload success
6. Download triggers on: user switch, force logout, new device, app reinstall

**Key files**:
- SiteSyncHandler: `lib/services/sync/handlers/site_sync_handler.dart`
- SyncService: `lib/services/sync_service.dart`
- SiteDao: `lib/Data/database/daos/site_dao.dart`
- MainMenu: `lib/Screens/mainMenu.dart`

**Firebase paths**:
- Site data: `Profile/{ownerUID}/Sites/{siteID}`
- Site image: `sites/{ownerUID}/{siteID}/site.jpg`

**Next steps**:
1. Feature 1.4: downloadSite() - single site download (needed for shared sites)
2. Phase 4: Migrate ContentProvider site methods
3. Phase 5: Complete siteInfo.dart with new Site model

---

## Architecture Reference

### Profile Pattern
```
UI Screen (profile_screen_ui_matched.dart)
    ↓ saves locally, sets sync flags
ProfileDao (profile_dao.dart)
    ↓ stores in SQLite
MainMenu detects via watchProfile() stream
    ↓ triggers
SyncService.syncNow()
    ↓ calls
ProfileSyncHandler
    ↓ uploads to
Firebase (Firestore + Storage)
```

### Site Pattern (NOW IMPLEMENTED ✅)
```
UI Screen (siteInfo.dart)
    ↓ saves locally, sets sync flags
SiteDao (site_dao.dart)
    ↓ stores in SQLite
MainMenu detects via watchSitesNeedingSync() stream
    ↓ triggers
SyncService.syncNow()
    ↓ loops through sites needing sync, calls
SiteSyncHandler.syncSiteData() + syncSiteImage()
    ↓ uploads to
Firebase (Firestore + Storage)
    ↓ on success
SiteDao clears sync flags
```

### Key Implementation Details
- `watchSitesNeedingSync()` - efficient DB-level filter for UPLOAD detection
- `getOwnedSites(ownerUID)` - uses UID (not email), checks if DOWNLOAD needed
- `_checkForPendingSync()` triggers `syncNow()` for both upload AND download
- Debounce prevents duplicate sync attempts
- Flags cleared ONLY after confirmed upload success
- Offline-first: no Firebase listeners for shared sites (manual refresh)