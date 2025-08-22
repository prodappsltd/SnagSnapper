# Profile Module Implementation Checklist
**Last Updated**: 2025-08-21
**Status**: ✅ COMPLETE
**Target**: Complete offline-first profile with image, signature, and colleague management

## 🎯 Critical Requirements
- ✅ Two-tier validation: 600KB optimal, 1MB maximum
- ✅ Fixed dimensions: 1024x1024 pixels for images
- ✅ Delete-then-add workflow (no direct replacement)
- ✅ Offline-first with background sync
- ✅ Fixed file naming for auto-overwrite
- ✅ Colleague management with JSON storage
- ✅ Reference sharing bugs fixed

---

## Phase 1: Database & Model Updates

### 1.1 Update AppUser Model
**File**: `/lib/Data/models/app_user.dart`
- [x] ✅ Add `bool imageMarkedForDeletion` field (default: false)
- [x] ✅ Add `bool signatureMarkedForDeletion` field (default: false)
- [x] ✅ Rename `imageFirebaseUrl` → `imageFirebasePath`
- [x] ✅ Rename `signatureFirebaseUrl` → `signatureFirebasePath`
- [x] ✅ Update constructor with new fields
- [x] ✅ Update copyWith method with new fields (CRITICAL FIX: preserves listOfALLColleagues)
- [x] ✅ Update toDatabase method with new fields
- [x] ✅ Update fromDatabase factory with new fields
- [x] ✅ Update validation method if needed
- [x] ✅ Update equality operator and hashCode
- [x] ✅ Add List<Colleague>? listOfALLColleagues field

### 1.2 Update Database Schema
**File**: `/lib/Data/database/app_database.dart`
- [x] ✅ Add column `image_marked_for_deletion` (BOOLEAN DEFAULT FALSE)
- [x] ✅ Add column `signature_marked_for_deletion` (BOOLEAN DEFAULT FALSE)
- [x] ✅ Rename column `image_firebase_url` → `image_firebase_path`
- [x] ✅ Rename column `signature_firebase_url` → `signature_firebase_path`
- [x] ✅ Keep database version 1 (fresh install approach)
- [x] ✅ Update table creation SQL
- [x] ✅ Add `list_of_all_colleagues` JSON column

### 1.3 Update ProfileDao
**File**: `/lib/Data/database/daos/profile_dao.dart`
- [x] ✅ Update insert query with new columns
- [x] ✅ Update update query with new columns
- [x] ✅ Add method `setImageMarkedForDeletion(String userId, bool value)`
- [x] ✅ Add method `setSignatureMarkedForDeletion(String userId, bool value)`
- [x] ✅ Update getProfile to map new fields
- [x] ✅ Add clearProfileSyncFlag method (sync flags only)
- [x] ✅ Add clearImageSyncFlag method (sync flags only)
- [x] ✅ Add clearSignatureSyncFlag method (sync flags only)

---

## Phase 2: Service Layer Updates

### 2.1 Update Image Compression Service
**File**: `/lib/services/image_compression_service.dart`
- [x] ✅ Change START_QUALITY from 85 to 90 (line 53)
- [x] ✅ Verify two-tier validation logic (600KB optimal, 1MB max)
- [x] ✅ Verify progressive compression (90% → 30% in 10% steps)
- [x] ✅ Implement auto-crop to center square (no manual interface)
- [x] ✅ Ensure all formats converted to JPEG
- [x] ✅ Test compression with various image sizes
- [x] ✅ Verify isolate usage for performance

### 2.2 Update Image Storage Service  
**File**: `/lib/services/image_storage_service.dart`
- [x] ✅ Remove timestamp from filename (line 50)
- [x] ✅ Change from `profile_${timestamp}.jpg` to `profile.jpg`
- [x] ✅ Change from `signature_${timestamp}.jpg` to `signature.jpg`
- [x] ✅ Verify auto-overwrite behavior with fixed names
- [x] ✅ Update method documentation

### 2.3 Update Profile Sync Handler
**File**: `/lib/services/sync/handlers/profile_sync_handler.dart`
- [x] ✅ Implement delete-then-add logic in `syncProfileImage()`
- [x] ✅ Check `imageMarkedForDeletion && imageLocalPath == null` for deletion
- [x] ✅ Delete from Firebase Storage at fixed path `users/{userId}/profile.jpg`
- [x] ✅ Update Firestore to remove imagePath field after deletion
- [x] ✅ Skip deletion if new image exists (optimization)
- [x] ✅ Upload to fixed Firebase path `users/{userId}/profile.jpg`
- [x] ✅ Store Firebase path (not URL) in local database
- [x] ✅ Set `needsProfileSync = true` before Firestore update
- [x] ✅ Update Firestore with imagePath after Storage upload
- [x] ✅ Clear `needsImageSync` after successful Storage operation
- [x] ✅ Clear `needsProfileSync` after successful Firestore update
- [x] ✅ Clear `imageMarkedForDeletion` after successful sync
- [x] ✅ Implement same logic for `syncSignatureImage()`
- [x] ✅ Handle edge case: file deleted but path exists in DB
- [x] ✅ Ensure idempotent operations (safe to retry)
- [x] ✅ Add colleague sync support (upload/download)
- [x] ✅ Fix field names (imagePath, signaturePath)
- [x] ✅ Fix device ID handling (no UUID suffix)

---

## Phase 3: UI Implementation

### 3.1 Profile Screen Image Display
**File**: `/lib/Screens/profile/profile_screen_ui_matched.dart`

#### 3.1.1 Fix Image Display Method (Line 1170-1179)
- [x] ✅ Replace TODO placeholder with actual implementation
- [x] ✅ Load image from local file path
- [x] ✅ Handle relative vs absolute paths
- [x] ✅ Show placeholder for null/empty path
- [x] ✅ Add delete button overlay when image exists
- [x] ✅ Handle file not found errors gracefully

#### 3.1.2 Add Image Selection Dialog (Line 448)
- [x] ✅ Create `_showImageSelectionDialog()` method
- [x] ✅ Show camera option (with permission check)
- [x] ✅ Show gallery option
- [x] ✅ Show delete option (only when image exists)
- [x] ✅ Handle option selection
- [x] ✅ Use Material 3 bottom sheet design

#### 3.1.3 Implement Image Picking Logic
- [x] ✅ Add `_pickImage(ImageSource source)` method
- [x] ✅ Set max input resolution to 2048x2048 for picker
- [x] ✅ Call ImageCompressionService for processing
- [x] ✅ No preview screen after selection (direct processing)
- [x] ✅ Show processing indicators ("Resizing...", "Compressing...", "Saving...")
- [x] ✅ Save to local storage using ImageStorageService
- [x] ✅ Update database with new path
- [x] ✅ Preserve `imageMarkedForDeletion` if true (for offline delete-then-add)
- [x] ✅ Set `needsImageSync = true`
- [x] ✅ Show appropriate success/error messages (silent for optimal/acceptable)
- [x] ✅ Handle permissions properly (grey out if denied)

#### 3.1.4 Update Image Deletion
- [x] ✅ Update `_handleImageDeletion()` method (Line 453)
- [x] ✅ Delete physical file from local storage
- [x] ✅ Set `imageLocalPath = null`
- [x] ✅ Set `imageMarkedForDeletion = true`
- [x] ✅ Set `needsImageSync = true`
- [x] ✅ Update UI immediately
- [x] ✅ Show confirmation dialog before deletion

#### 3.1.5 Add Required Imports
- [x] ✅ Import dart:io for File
- [x] ✅ Import image_picker package
- [x] ✅ Import path_provider package
- [x] ✅ Import image_compression_service
- [x] ✅ Import image_storage_service

### 3.2 Migrate Working Code from Old Profile
**File**: `/lib/Screens/profile.dart` (old) → `profile_screen_ui_matched.dart`
- [x] ✅ Copy working image methods from old file
- [x] ✅ Adapt to new UI structure
- [x] ✅ Ensure offline-first approach
- [x] ✅ Test all functionality
- [x] ✅ Delete old profile.dart after migration
- [x] ✅ Rename profile_screen_ui_matched.dart to profile_screen_ui_matched.dart (kept name)

### 3.3 Update Main.dart Route
**File**: `/lib/main.dart`
- [x] ✅ Update profile route to use renamed file (if needed)
- [x] ✅ Ensure proper database and userId passing

---

## Phase 4: Colleague Management (🆕 Added 2025-08-21)

### 4.1 Add Colleague Model
**File**: `/lib/Data/colleague.dart`
- [x] ✅ Create Colleague class with JSON serialization
- [x] ✅ Add fields: name, email, phone, company, trade
- [x] ✅ Use lowercase field names in JSON (name, email, not NAME, EMAIL)

### 4.2 Update Profile UI for Colleagues
**File**: `/lib/Screens/profile/profile_screen_ui_matched.dart`
- [x] ✅ Add Colleagues section after signature
- [x] ✅ Implement Add Colleague dialog
- [x] ✅ Implement Edit Colleague functionality
- [x] ✅ Implement Delete Colleague with confirmation
- [x] ✅ Fix reference sharing bug (List<Colleague>.from())
- [x] ✅ Ensure _hasColleaguesChanged() detection works

### 4.3 Update Sync Handler for Colleagues
**File**: `/lib/services/sync/handlers/profile_sync_handler.dart`
- [x] ✅ Upload colleagues array to Firestore
- [x] ✅ Download colleagues from Firebase on reinstall
- [x] ✅ Parse colleagues JSON correctly
- [x] ✅ Ensure copyWith preserves colleagues
- [ ] Test navigation to profile screen

---

## Phase 4: Signature Implementation

### 4.1 Create Signature Service
**File**: `/lib/services/signature_service.dart`
- [ ] Create SignatureService class
- [ ] Implement stroke management
- [ ] Implement image generation from strokes
- [ ] Implement auto-crop whitespace
- [ ] Implement JPEG conversion (95% quality)
- [ ] Save to fixed path: `signature.jpg`

### 4.2 Create Signature Capture Screen
**File**: `/lib/Screens/SignUp_SignIn/signature_capture_screen.dart`
- [ ] Create full-screen capture UI
- [ ] Implement 640x360 canvas (16:9 ratio)
- [ ] White canvas on dark grey background
- [ ] Black ink, 3px stroke width
- [ ] Add Clear, Cancel, Use Signature buttons
- [ ] Lock to portrait orientation
- [ ] Return captured signature to profile

### 4.3 Integrate Signature in Profile
- [ ] Add signature display widget
- [ ] Show "Add Signature" placeholder when empty
- [ ] Show signature with delete button when exists
- [ ] Handle signature deletion (same as image)
- [ ] Set `signatureMarkedForDeletion` flag
- [ ] Implement offline-first sync logic

---

## Phase 5: Testing

### 5.1 Unit Tests
- [ ] Test AppUser model with new fields
- [ ] Test database operations with new columns
- [ ] Test image compression (90% start, two-tier validation)
- [ ] Test signature service
- [ ] Test sync logic with deletion flags

### 5.2 Widget Tests  
- [ ] Test image picker dialog
- [ ] Test image display states
- [ ] Test deletion confirmation
- [ ] Test signature capture screen
- [ ] Test error handling

### 5.3 Integration Tests
- [ ] Test complete image upload flow
- [ ] Test delete-then-add offline scenario
- [ ] Test sync after coming online
- [ ] Test signature capture and sync
- [ ] Test Firebase Storage operations

### 5.4 Manual Testing Scenarios
- [ ] Add image while online → verify immediate sync
- [ ] Add image while offline → verify sync when online
- [ ] Delete image offline → add new one → verify sync behavior

---

## Phase 6: Non-Blocking Sync Implementation (🆕 Added 2025-08-21)

### Overview
Remove blocking sync from ProfileScreen. Implement fire-and-forget architecture where saves are instant and sync happens in background from MainMenu.

### 6.1 ProfileScreen Cleanup (profile_screen_ui_matched.dart)

#### 6.1.1 Remove Sync-Related State Variables
- [x] Delete lines 76-82: Sync service and stream subscriptions
- [x] Keep line 70: `busy` flag (still needed for UI blocking during save)
- [x] Keep line 73: `_imageOperationInProgress` (used for image operations)

#### 6.1.2 Remove Sync Service Initialization
- [x] Delete lines 123-161: Entire `_initializeSyncService()` method
- [x] Delete line ~108 in initState: Call to `_initializeSyncService()`
- [x] Delete lines 134-140: Sync status listener in `_setupSyncListener()`

#### 6.1.3 Remove Sync UI Components from App Bar
- [x] Delete lines 1534-1542: SyncStatusIndicator widget
- [x] Delete lines 1543-1553: Manual sync button and its condition check
- [x] Delete import for SyncStatusIndicator if not used elsewhere

#### 6.1.4 Remove Manual Sync Method
- [x] Delete lines 653-681: Entire `_triggerManualSync()` method
- [x] Delete line 174: Reference to `_triggerManualSync` in error dialog retry button
- [x] Delete lines 170-177: Remove entire retry button from error dialog

#### 6.1.5 Simplify Save Method
- [x] Delete lines 573-586: Sync call and result handling
- [x] Delete line 577: `await _syncService.syncNow()`
- [x] Change lines 596-602: Simplify message to just "Profile saved"
- [x] Delete lines 582-585: Profile reload after sync

#### 6.1.6 Remove All Reload Calls
- [x] Delete lines 137-139: Reload on sync status change
- [x] Delete line 584: `await _loadProfile()` after sync
- [x] Delete line 663: `await _loadProfile()` after manual sync
- [x] Remove entire sync status listener setup

#### 6.1.7 Clean Up Imports
- [x] Remove unused import: `import 'package:snagsnapper/services/sync_service.dart';`
- [x] Remove unused import for SyncStatusIndicator
- [x] Keep all other imports

#### 6.1.8 Clean Up Dispose Method
- [x] Remove sync subscription cancellations from dispose()
- [x] Remove any sync service cleanup

#### 6.1.9 Check Other Method References
- [x] Search for any `_syncService` references in other methods
- [x] Remove sync status checks from `_isDirty` calculation
- [x] Verify no sync references in image/signature methods

### 6.2 MainMenu Enhancements (mainMenu.dart)

#### 6.2.1 Add Force Logout Handling
- [x] In `_initializeSyncService()` add force logout callback
- [x] Implement sync cancellation on force logout
- [x] Navigate to login screen after cleanup

#### 6.2.2 Enhanced Error Handling
- [x] In sync error handler (line 256-258), add permanent error detection
- [x] Show toast for authentication/permission errors
- [x] Silent retry for temporary network errors

#### 6.2.3 Add Image Upload Progress (Optional)
- [ ] Add progress listener in `_initializeSyncService()`
- [ ] Show subtle progress indicator for image uploads
- [ ] Auto-hide when complete

### 6.3 Integration Safety Checks

#### 6.3.1 Navigation Flow Verification
- [x] Verify line 614-620: Navigation for new/existing profiles unchanged
- [x] Ensure Navigator.pop() returns to MainMenu
- [x] Ensure pushNamedAndRemoveUntil works for new profiles

#### 6.3.2 Database Operations
- [x] Verify profile save still sets sync flags correctly
- [x] Ensure all copyWith operations preserve data
- [x] Check that sync flags are set on save

#### 6.3.3 Error Handling Paths
- [x] Remove sync error handling from ProfileScreen
- [x] Ensure database errors still show messages
- [x] Keep validation error messages

### 6.4 Cross-Screen Impact

#### 6.4.1 Sites Screen Integration
- [ ] Verify Sites screen navigation to profile still works
- [ ] Ensure Sites screen doesn't expect sync status from profile
- [ ] Check colleague list updates properly

#### 6.4.2 Sync Service Singleton
- [ ] Ensure SyncService.instance still works for MainMenu
- [ ] Verify no initialization conflicts
- [ ] Check memory cleanup

### 6.5 Testing Verification

#### 6.5.1 Core Flows
- [x] New profile: Save → Navigate → MainMenu syncs
- [x] Edit profile: Save → Navigate → MainMenu syncs
- [x] No internet: Save works, sync queues

#### 6.5.2 Edge Cases
- [x] Force logout: Cancels active sync
- [x] Rapid navigation: No duplicate syncs
- [x] Image upload: Continues after navigation
- [ ] Validation mismatch: Shows error toast

#### 6.5.3 Widget Test Updates
- [ ] Update profile_screen tests to remove sync expectations
- [ ] Remove mock sync service from test setup
- [ ] Update navigation test expectations

### 6.6 Documentation Updates

#### 6.6.1 Code Comments
- [ ] Remove sync-related comments in ProfileScreen
- [ ] Update method documentation
- [ ] Add comment explaining MainMenu handles sync

#### 6.6.2 Bug Tracker Update
- [ ] Mark Bug #019 as "Fixed"
- [ ] Document fix approach and testing

#### 6.6.3 PRD Update  
- [ ] Update sync architecture section
- [ ] Document MainMenu as sync coordinator
- [ ] Update Section 4.3.3 Profile Editing Flow
- [ ] Delete image online → verify Firebase deletion
- [ ] Replace image multiple times offline → verify final state
- [ ] Test with images of various sizes
- [ ] Test permission denials
- [ ] Test storage full scenarios
- [ ] Verify fixed file naming (no duplicates)
- [ ] Check Firebase Storage for proper overwrites
- [ ] Verify Firestore imagePath field updates
- [ ] Test app kill and restart scenarios

---

## Phase 6: Error Handling & Polish

### 6.1 Error Messages
- [ ] Image too large (>1MB): "Image too complex. Please choose a simpler image"
- [ ] Invalid format: "Invalid image format"
- [ ] Storage full: "Not enough storage space"
- [ ] Permission denied: Grey out option with help text
- [ ] Network error during sync: Retry with exponential backoff

### 6.2 User Feedback
- [ ] Optimal size (<600KB): Silent save, generic success
- [ ] Acceptable size (600-1MB): Silent save, generic success
- [ ] Show step indicators not percentages
- [ ] Immediate UI updates (offline-first)
- [ ] Sync status indicators

### 6.3 Performance
- [ ] Image loads < 200ms from local storage
- [ ] Compression in background isolate
- [ ] Non-blocking sync operations
- [ ] Memory efficient image handling
- [ ] Clean up temp files

---

## Phase 7: Documentation & Cleanup

### 7.1 Code Documentation
- [ ] Document new database fields
- [ ] Document sync logic with deletion flags
- [ ] Document delete-then-add scenario
- [ ] Add inline comments for complex logic
- [ ] Update method documentation

### 7.2 User Documentation
- [ ] Update user guide with image requirements
- [ ] Document delete-then-add workflow
- [ ] Add troubleshooting section
- [ ] Create test image set

### 7.3 Cleanup
- [ ] Remove old profile.dart file
- [ ] Remove debug print statements
- [ ] Remove TODO comments
- [ ] Optimize imports
- [ ] Run code formatter

---

## Success Criteria
- [ ] Images compressed to <600KB (optimal) or <1MB (max)
- [ ] Fixed 1024x1024 dimensions
- [ ] Delete-then-add works offline
- [ ] imageMarkedForDeletion persists through add operation
- [ ] Sync completes successfully when online
- [ ] No duplicate files with fixed naming
- [ ] Sync flags properly managed (needsImageSync, needsProfileSync)
- [ ] Firebase paths stored (not URLs)
- [ ] All tests passing
- [ ] PRD requirements met 100%

---

## Estimated Timeline
- Phase 1 (Database): 2 hours
- Phase 2 (Services): 2 hours  
- Phase 3 (UI): 4 hours
- Phase 4 (Signature): 3 hours
- Phase 5 (Testing): 3 hours
- Phase 6 (Polish): 2 hours
- Phase 7 (Cleanup): 1 hour
- **Total**: ~17 hours

---

## Dependencies
```yaml
dependencies:
  image_picker: ^1.0.0
  path_provider: ^2.0.0
  image: ^4.0.0  # Already included
```

---

## Risk Mitigation
1. **Risk**: Users lose images during migration
   - **Mitigation**: Keep old implementation until new one tested
   
2. **Risk**: Sync conflicts with deletion flag
   - **Mitigation**: Idempotent operations, safe to retry

3. **Risk**: Storage accumulation with old files
   - **Mitigation**: Fixed naming auto-overwrites

4. **Risk**: Large images cause memory issues
   - **Mitigation**: Compression in isolate, size limits

---

## Notes
- Always test offline-first scenarios
- Verify deletion flag persistence
- Check Firebase Storage costs
- Monitor compression performance
- Consider progress indicators for slow devices