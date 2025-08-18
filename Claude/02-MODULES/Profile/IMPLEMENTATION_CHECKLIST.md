# Profile Image & Signature Implementation Checklist
**Based on PRD v2025-01-18 and Updated Implementation Plan**
**Target**: Complete offline-first image handling with delete-then-add support

## 🎯 Critical Requirements
- Two-tier validation: 600KB optimal, 1MB maximum
- Fixed dimensions: 1024x1024 pixels for images
- Delete-then-add workflow (no direct replacement)
- Offline-first with background sync
- Fixed file naming for auto-overwrite

---

## Phase 1: Database & Model Updates

### 1.1 Update AppUser Model
**File**: `/lib/Data/models/app_user.dart`
- [ ] Add `bool imageMarkedForDeletion` field (default: false)
- [ ] Add `bool signatureMarkedForDeletion` field (default: false)
- [ ] Rename `imageFirebaseUrl` → `imageFirebasePath`
- [ ] Rename `signatureFirebaseUrl` → `signatureFirebasePath`
- [ ] Update constructor with new fields
- [ ] Update copyWith method with new fields
- [ ] Update toDatabase method with new fields
- [ ] Update fromDatabase factory with new fields
- [ ] Update validation method if needed
- [ ] Update equality operator and hashCode

### 1.2 Update Database Schema
**File**: `/lib/Data/database/app_database.dart`
- [ ] Add column `image_marked_for_deletion` (BOOLEAN DEFAULT FALSE)
- [ ] Add column `signature_marked_for_deletion` (BOOLEAN DEFAULT FALSE)
- [ ] Rename column `image_firebase_url` → `image_firebase_path`
- [ ] Rename column `signature_firebase_url` → `signature_firebase_path`
- [ ] Keep database version 1 (fresh install approach)
- [ ] Update table creation SQL

### 1.3 Update ProfileDao
**File**: `/lib/Data/database/daos/profile_dao.dart`
- [ ] Update insert query with new columns
- [ ] Update update query with new columns
- [ ] Add method `setImageMarkedForDeletion(String userId, bool value)`
- [ ] Add method `setSignatureMarkedForDeletion(String userId, bool value)`
- [ ] Update getProfile to map new fields

---

## Phase 2: Service Layer Updates

### 2.1 Update Image Compression Service
**File**: `/lib/services/image_compression_service.dart`
- [ ] Change START_QUALITY from 85 to 90 (line 53)
- [ ] Verify two-tier validation logic (600KB optimal, 1MB max)
- [ ] Verify progressive compression (90% → 30% in 10% steps)
- [ ] Implement auto-crop to center square (no manual interface)
- [ ] Ensure all formats converted to JPEG
- [ ] Test compression with various image sizes
- [ ] Verify isolate usage for performance

### 2.2 Update Image Storage Service  
**File**: `/lib/services/image_storage_service.dart`
- [ ] Remove timestamp from filename (line 50)
- [ ] Change from `profile_${timestamp}.jpg` to `profile.jpg`
- [ ] Change from `signature_${timestamp}.jpg` to `signature.jpg`
- [ ] Verify auto-overwrite behavior with fixed names
- [ ] Update method documentation

### 2.3 Update Profile Sync Handler
**File**: `/lib/services/sync/handlers/profile_sync_handler.dart`
- [ ] Implement delete-then-add logic in `syncProfileImage()`
- [ ] Check `imageMarkedForDeletion && imageLocalPath == null` for deletion
- [ ] Delete from Firebase Storage at fixed path `users/{userId}/profile.jpg`
- [ ] Update Firestore to remove imagePath field after deletion
- [ ] Skip deletion if new image exists (optimization)
- [ ] Upload to fixed Firebase path `users/{userId}/profile.jpg`
- [ ] Store Firebase path (not URL) in local database
- [ ] Set `needsProfileSync = true` before Firestore update
- [ ] Update Firestore with imagePath after Storage upload
- [ ] Clear `needsImageSync` after successful Storage operation
- [ ] Clear `needsProfileSync` after successful Firestore update
- [ ] Clear `imageMarkedForDeletion` after successful sync
- [ ] Implement same logic for `syncSignatureImage()`
- [ ] Handle edge case: file deleted but path exists in DB
- [ ] Ensure idempotent operations (safe to retry)

---

## Phase 3: UI Implementation

### 3.1 Profile Screen Image Display
**File**: `/lib/Screens/profile/profile_screen_ui_matched.dart`

#### 3.1.1 Fix Image Display Method (Line 1170-1179)
- [ ] Replace TODO placeholder with actual implementation
- [ ] Load image from local file path
- [ ] Handle relative vs absolute paths
- [ ] Show placeholder for null/empty path
- [ ] Add delete button overlay when image exists
- [ ] Handle file not found errors gracefully

#### 3.1.2 Add Image Selection Dialog (Line 448)
- [ ] Create `_showImageSelectionDialog()` method
- [ ] Show camera option (with permission check)
- [ ] Show gallery option
- [ ] Show delete option (only when image exists)
- [ ] Handle option selection
- [ ] Use Material 3 bottom sheet design

#### 3.1.3 Implement Image Picking Logic
- [ ] Add `_pickImage(ImageSource source)` method
- [ ] Set max input resolution to 2048x2048 for picker
- [ ] Call ImageCompressionService for processing
- [ ] No preview screen after selection (direct processing)
- [ ] Show processing indicators ("Resizing...", "Compressing...", "Saving...")
- [ ] Save to local storage using ImageStorageService
- [ ] Update database with new path
- [ ] Preserve `imageMarkedForDeletion` if true (for offline delete-then-add)
- [ ] Set `needsImageSync = true`
- [ ] Show appropriate success/error messages (silent for optimal/acceptable)
- [ ] Handle permissions properly (grey out if denied)

#### 3.1.4 Update Image Deletion
- [ ] Update `_handleImageDeletion()` method (Line 453)
- [ ] Delete physical file from local storage
- [ ] Set `imageLocalPath = null`
- [ ] Set `imageMarkedForDeletion = true`
- [ ] Set `needsImageSync = true`
- [ ] Update UI immediately
- [ ] Show confirmation dialog before deletion

#### 3.1.5 Add Required Imports
- [ ] Import dart:io for File
- [ ] Import image_picker package
- [ ] Import path_provider package
- [ ] Import image_compression_service
- [ ] Import image_storage_service

### 3.2 Migrate Working Code from Old Profile
**File**: `/lib/Screens/profile.dart` (old) → `profile_screen_ui_matched.dart`
- [ ] Copy working image methods from old file
- [ ] Adapt to new UI structure
- [ ] Ensure offline-first approach
- [ ] Test all functionality
- [ ] Delete old profile.dart after migration
- [ ] Rename profile_screen_ui_matched.dart to profile.dart

### 3.3 Update Main.dart Route
**File**: `/lib/main.dart`
- [ ] Update profile route to use renamed file (if needed)
- [ ] Ensure proper database and userId passing
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