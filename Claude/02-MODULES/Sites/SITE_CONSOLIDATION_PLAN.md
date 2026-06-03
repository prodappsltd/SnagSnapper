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
**Status**: NOT STARTED
**Depends on**: 1.3

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

---

### Feature 1.4: downloadSite() - Download Site from Firebase
**Status**: NOT STARTED
**Depends on**: 1.35

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
**Status**: NOT STARTED
**Depends on**: 1.4

Implement method to:
1. Download from Firebase Storage path
2. Save to local storage using ImageStorageService
3. Update `imageLocalPath` in local DB

**Debug prints**:
- "SiteSyncHandler: Downloading image from {firebasePath}"
- "SiteSyncHandler: Saved to local: {localPath}"
- "SiteSyncHandler: Updated imageLocalPath in DB"

**Verification**: Call with known image path, check file exists locally

---

### Feature 1.6: syncAll() - Batch Sync All Sites
**Status**: NOT STARTED
**Depends on**: 1.2, 1.3

Implement method to:
1. Query all sites needing sync via `SiteDao.getSitesNeedingSync()`
2. Loop through and call syncSiteData() and syncSiteImage() as needed
3. Return summary of results

**Debug prints**:
- "SiteSyncHandler: syncAll found {n} sites needing sync"
- "SiteSyncHandler: Syncing site {i}/{n}: {siteId}"
- "SiteSyncHandler: syncAll complete - {success}/{total} succeeded"

**Verification**: Create multiple sites with flags, call syncAll, verify all synced

---

## Phase 1 Completion Criteria
- [x] Feature 1.1 complete and verified
- [x] Feature 1.2 complete and verified
- [x] Feature 1.3 complete and verified
- [ ] Feature 1.4 complete and verified
- [ ] Feature 1.5 complete and verified
- [ ] Feature 1.6 complete and verified

---

## Phase 2: Update SyncService (After Phase 1)

### Feature 2.1: Add SiteSyncHandler Instance
### Feature 2.2: Add syncSites() Method
### Feature 2.3: Integrate into syncNow()

---

## Phase 3: Update MainMenu (After Phase 2)

### Feature 3.1: Add Site Sync State Variables
### Feature 3.2: Add Site Sync Listener
### Feature 3.3: Add Pending Sync Check

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

---

## Context Recovery Notes

**Current working feature**: 1.3 VERIFIED - Ready for 1.35 (MySites UI)

**Key files**:
- SiteSyncHandler: `lib/services/sync/handlers/site_sync_handler.dart`
- Reference (ProfileSyncHandler): `lib/services/sync/handlers/profile_sync_handler.dart`
- SiteDao: `lib/Data/database/daos/site_dao.dart`
- Site model: `lib/Data/models/site.dart`

**Firebase paths**:
- Site data: `Profile/{ownerUID}/Sites/{siteID}`
- Site image: `sites/{ownerUID}/{siteID}/site.jpg`

---

## Architecture Reference

### Profile Pattern (to follow)
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

### Site Pattern (target)
```
UI Screen (siteInfo.dart)
    ↓ saves locally, sets sync flags
SiteDao (site_dao.dart)
    ↓ stores in SQLite
MainMenu detects via watchAllSites() stream
    ↓ triggers
SyncService.syncSites()
    ↓ calls
SiteSyncHandler
    ↓ uploads to
Firebase (Firestore + Storage)
```