# Snag Image Handling Plan

## Overview

This document defines the image handling architecture for Snags in SnagSnapper. The approach follows the same patterns established in Site image handling, with adaptations for multiple image slots (6 per snag).

**Last Updated:** 2026-06-06

---

## Core Principles

### 1. Offline-First Architecture
- All image operations save locally FIRST
- Firebase sync happens in background when online
- App works fully offline

### 2. Instant Operations
- Image Pick and Remove are INSTANT
- Do NOT wait for Save button
- Database updated immediately on each action
- **Exception:** NEW snag (not yet saved) - images stored in UI state, saved with snag on first Save

### 3. Save Button Independence
- Save button handles TEXT fields only (location, title, description, etc.)
- Image operations are completely independent
- User can press Back after image change - it's already saved

### 4. No Direct Replace
- User CANNOT replace an existing image directly
- Must REMOVE first, then PICK new
- Ensures clean state transitions

### 5. Fixed Path Naming (Index-Based)
- Each slot has ONE fixed image path based on index
- `0.jpg`, `1.jpg`, `2.jpg`, `3.jpg`, `4.jpg`, `5.jpg`
- New images OVERWRITE old ones (no accumulation)
- No orphan cleanup needed in Firebase

### 6. Fixed 6 Slots
- Problem photos: 6 slots maximum
- Fix photos: 6 slots maximum
- UI adapts to show filled slots + add option

---

## ImageSlot Class

Encapsulates per-slot state, matching Site's single-image fields:

```dart
@immutable
class ImageSlot {
  final String? localPath;           // Relative path to local file (null = empty)
  final String? firebasePath;        // Firebase path (kept for deletion reference)
  final bool needsSync;              // This slot needs upload/delete
  final bool markedForDeletion;      // Pending Firebase deletion
  final int version;                 // Incremented on every Pick/Remove (for race condition detection)

  const ImageSlot({
    this.localPath,
    this.firebasePath,
    this.needsSync = false,
    this.markedForDeletion = false,
    this.version = 0,
  });

  /// Slot has a local image
  bool get hasImage => localPath != null;

  /// Slot is completely empty (no image, no pending actions)
  bool get isEmpty => localPath == null && !markedForDeletion;

  /// Slot needs attention during sync
  bool get needsAttention => needsSync || markedForDeletion;

  /// Create copy with updated fields
  /// Use clearLocalPath() or clearFirebasePath() to set paths to null
  ImageSlot copyWith({
    String? localPath,
    String? firebasePath,
    bool? needsSync,
    bool? markedForDeletion,
    int? version,
    bool clearLocal = false,      // Set true to clear localPath to null
    bool clearFirebase = false,   // Set true to clear firebasePath to null
  }) {
    return ImageSlot(
      localPath: clearLocal ? null : (localPath ?? this.localPath),
      firebasePath: clearFirebase ? null : (firebasePath ?? this.firebasePath),
      needsSync: needsSync ?? this.needsSync,
      markedForDeletion: markedForDeletion ?? this.markedForDeletion,
      version: version ?? this.version,
    );
  }

  /// Clear local path (for removal)
  ImageSlot clearLocalPath() {
    return ImageSlot(
      localPath: null,
      firebasePath: firebasePath, // KEEP for deletion reference
      needsSync: true,
      markedForDeletion: true,
      version: version + 1,       // INCREMENT for race condition detection
    );
  }

  /// Set new image
  ImageSlot setImage(String localPath, String firebasePath) {
    return ImageSlot(
      localPath: localPath,
      firebasePath: firebasePath,
      needsSync: true,
      markedForDeletion: markedForDeletion, // PRESERVE if was true
      version: version + 1,                 // INCREMENT for race condition detection
    );
  }

  /// Clear after successful sync
  ImageSlot markSynced() {
    return ImageSlot(
      localPath: localPath,
      firebasePath: hasImage ? firebasePath : null, // Clear if deleted
      needsSync: false,
      markedForDeletion: false,
      version: version,                             // PRESERVE (don't reset)
    );
  }

  /// Create empty slot
  static const ImageSlot empty = ImageSlot();

  /// Create list of 6 empty slots
  static List<ImageSlot> emptyList() => List.filled(6, empty);
}
```

---

## Storage Paths

### Problem Photos (Documenting the defect)

| Slot | Local Path | Firebase Path |
|------|------------|---------------|
| 0 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/0.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/0.jpg` |
| 1 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/1.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/1.jpg` |
| 2 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/2.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/2.jpg` |
| 3 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/3.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/3.jpg` |
| 4 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/4.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/4.jpg` |
| 5 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/5.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/5.jpg` |

### Fix Photos (Documenting the repair)

| Slot | Local Path | Firebase Path |
|------|------------|---------------|
| 0 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/fix/0.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/fix/0.jpg` |
| 1 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/fix/1.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/fix/1.jpg` |
| ... | ... | ... |
| 5 | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/fix/5.jpg` | `sites/{ownerUID}/{siteId}/snags/{snagId}/fix/5.jpg` |

### Path Helper Functions

```dart
class SnagImagePaths {
  static String localPath({
    required String userId,
    required String siteId,
    required String snagId,
    required int index,
    bool isFix = false,
  }) {
    final fixSegment = isFix ? '/fix' : '';
    return 'SnagSnapper/$userId/Sites/$siteId/Snags/$snagId$fixSegment/$index.jpg';
  }

  static String firebasePath({
    required String ownerUID,
    required String siteId,
    required String snagId,
    required int index,
    bool isFix = false,
  }) {
    final fixSegment = isFix ? '/fix' : '';
    return 'sites/$ownerUID/$siteId/snags/$snagId$fixSegment/$index.jpg';
  }
}
```

---

## Snag Model Fields

```dart
@immutable
class Snag {
  // ... existing fields ...

  // Problem documentation (6 slots)
  final List<ImageSlot> images;       // Length always 6

  // Fix documentation (6 slots)
  final List<ImageSlot> fixImages;    // Length always 6

  // Helper getters
  bool get hasAnyImages => images.any((s) => s.hasImage);
  bool get hasAnyFixImages => fixImages.any((s) => s.hasImage);
  bool get needsImageSync => images.any((s) => s.needsAttention);  // includes markedForDeletion
  bool get needsFixImageSync => fixImages.any((s) => s.needsAttention);
  int get imageCount => images.where((s) => s.hasImage).length;
  int get fixImageCount => fixImages.where((s) => s.hasImage).length;

  // Get first empty slot index (-1 if all full)
  int get firstEmptyImageSlot => images.indexWhere((s) => s.isEmpty);
  int get firstEmptyFixImageSlot => fixImages.indexWhere((s) => s.isEmpty);
}
```

---

## User Actions

| Action | Description | Who Can Do It |
|--------|-------------|---------------|
| **PICK** | Add image to empty slot | Owner (problem), Fixer (fix) |
| **REMOVE** | Delete image from slot | Owner (problem), Fixer (fix) |
| **SAVE** | Save text/form fields | Owner/Fixer |
| **BACK** | Navigate away | Anyone |

---

## State Transitions

### Action: PICK (Add Image to Slot)

**Precondition:** Slot is empty OR slot was just removed (isEmpty or markedForDeletion)

```
Before: LP=null, FP=null, NS=false, MD=false/true
After:  LP=path, FP=path, NS=true,  MD=preserved

Steps:
1. User selects image from camera/gallery
2. Image compressed (max 1MB, 1024x1024)
3. Saved to local storage at fixed path ({index}.jpg, overwrites)
4. ImageSlot updated INSTANTLY:
   - localPath = relative path
   - firebasePath = Firebase path (set immediately!)
   - needsSync = true
   - markedForDeletion = PRESERVED (don't clear if true)
5. Snag saved to database
6. UI updates to show new image
```

**Key Point:** `markedForDeletion` is PRESERVED, not cleared. This handles the Remove → Pick scenario correctly (old Firebase image will be overwritten by upload).

### Action: REMOVE (Delete Image from Slot)

**Precondition:** Slot has existing image

```
Before: LP=path, FP=path, NS=any,  MD=false
After:  LP=null, FP=path, NS=true, MD=true

Steps:
1. User confirms deletion
2. Local file deleted from storage
3. ImageSlot updated INSTANTLY:
   - localPath = null
   - firebasePath = KEPT (needed for Firebase deletion)
   - needsSync = true
   - markedForDeletion = true
4. Snag saved to database
5. UI updates to show empty slot
```

**Key Point:** `firebasePath` is KEPT so sync handler knows what to delete from Firebase.

---

## UI Behavior

### Initial State (New Snag)
- Show "Add photo" button/area
- No slots visible initially

### After First Photo Added
- Show photo in first slot (index 0)
- Show "Add more" option (if < 6 photos)

### Progressive Addition
| Photos | UI Layout |
|--------|-----------|
| 1 | 1 photo + "Add more" |
| 2 | Row of 2 + "Add more" |
| 3 | Row of 3 + "Add more" |
| 4 | Row of 3 + Row of 1 + "Add more" |
| 5 | Row of 3 + Row of 2 + "Add more" |
| 6 | Row of 3 + Row of 3 (full, no add option) |

### Layout Rules
- Always show photos in rows of 3 (for PDF consistency)
- Last row can have 1-3 photos
- "Add more" appears after last photo until 6 reached
- Each photo shows delete (X) button on tap/long-press

---

## Scenario Matrix

### NEW Snag (not yet in database)

| # | Action Sequence | Local Files | DB Record | Firebase | Notes |
|---|-----------------|-------------|-----------|----------|-------|
| N1 | Pick(0) → Save | 0.jpg saved | Created | Pending upload | Happy path |
| N2 | Pick(0) → Back | 0.jpg saved | NOT created | None | **Orphan! Needs cleanup** |
| N3 | Pick(0) → Remove(0) → Save | 0.jpg deleted | Created (no images) | None | Clean |
| N4 | Pick(0) → Pick(1) → Save | 0.jpg, 1.jpg | Created | Both pending | Multiple photos |
| N5 | Pick(0) → Remove(0) → Pick(0) → Save | 0.jpg (new) | Created | Pending upload | Slot reused |

**Rule:** For NEW snags, cleanup local image files on Back if snag not saved.

### EXISTING Snag - Empty Slot

| # | Action Sequence | Local File | Slot State | Firebase | Notes |
|---|-----------------|------------|------------|----------|-------|
| E1 | Pick(2) | 2.jpg saved | LP=✓ FP=✓ NS=✓ MD=✗ | Pending upload | Instant save |
| E2 | Pick(2) → Remove(2) | 2.jpg deleted | LP=✗ FP=✓(new) NS=✓ MD=✓ | Delete attempted (not-found=OK) | Clean |
| E3 | Pick(2) → Remove(2) → Pick(2) | 2.jpg (new) | LP=✓ FP=✓ NS=✓ MD=✓ | Pending upload | MD preserved |

### EXISTING Snag - Slot Has Image

| # | Action Sequence | Local File | Slot State | Firebase | Notes |
|---|-----------------|------------|------------|----------|-------|
| H1 | Remove(1) | 1.jpg deleted | LP=✗ FP=✓(old) NS=✓ MD=✓ | Pending delete | FP kept for ref |
| H2 | Remove(1) → Pick(1) | 1.jpg (new) | LP=✓ FP=✓(new) NS=✓ MD=✓ | Pending upload | Overwrites old |

**Note:** There is NO "Pick to replace" scenario. User MUST Remove first.

---

## Sync Handler Logic

```dart
Future<void> syncSnagImages(Snag snag) async {
  bool anyChanges = false;
  List<ImageSlot> updatedSlots = List.from(snag.images);

  for (int i = 0; i < 6; i++) {
    final slot = updatedSlots[i];

    if (!slot.needsSync && !slot.markedForDeletion) continue;

    // Scenario 1: Delete only (no local image, marked for deletion)
    if (slot.localPath == null && slot.markedForDeletion) {
      if (slot.firebasePath != null) {
        try {
          await deleteFromFirebase(slot.firebasePath!);
        } catch (e) {
          // Ignore "not found" errors, retry others
          if (!isNotFoundError(e)) continue;
        }
      }
      updatedSlots[i] = slot.markSynced();
      anyChanges = true;
      continue;
    }

    // Scenario 2: Upload (has local image)
    if (slot.localPath != null && slot.needsSync) {
      final firebasePath = SnagImagePaths.firebasePath(
        ownerUID: snag.ownerEmail,
        siteId: snag.siteUID,
        snagId: snag.id,
        index: i,
      );

      try {
        // Upload overwrites if exists (handles MD=true case)
        await uploadToFirebase(slot.localPath!, firebasePath);
      } catch (e) {
        // Upload failed - keep flags for retry
        continue;
      }

      updatedSlots[i] = slot.copyWith(
        firebasePath: firebasePath,
        needsSync: false,
        markedForDeletion: false,
      );
      anyChanges = true;
      continue;
    }

    // Scenario 3: Clear stale flags
    if (slot.needsSync || slot.markedForDeletion) {
      updatedSlots[i] = slot.markSynced();
      anyChanges = true;
    }
  }

  if (anyChanges) {
    // RACE CONDITION FIX: Re-fetch current state before DB update
    final currentSnag = await getSnagFromDb(snag.id);
    if (currentSnag == null) return; // Snag was deleted

    // Merge: only update slots that haven't changed since sync started
    // Uses VERSION COUNTER - guarantees detection even with same file paths
    final mergedSlots = List<ImageSlot>.from(currentSnag.images);
    for (int i = 0; i < 6; i++) {
      final originalVersion = snag.images[i].version;
      final currentVersion = currentSnag.images[i].version;

      // Only apply our update if version unchanged (no user activity during sync)
      if (currentVersion == originalVersion) {
        mergedSlots[i] = updatedSlots[i];
      }
      // Else: user changed this slot during sync (version incremented)
      // Keep their version - next sync cycle will handle it
    }

    final updatedSnag = currentSnag.copyWith(images: mergedSlots);
    await updateSnagInDb(updatedSnag);
  }
}
```

### Sync Decision Matrix (Per Slot)

| localPath | markedForDeletion | needsSync | Action |
|-----------|-------------------|-----------|--------|
| null | true | true | DELETE from Firebase |
| null | false | any | No-op (empty slot) |
| path | true | true | UPLOAD (overwrites, skip explicit delete) |
| path | false | true | UPLOAD |
| path | any | false | No-op (already synced) |

---

## Edge Cases

### 1. App Killed Mid-Operation

| Scenario | State | Recovery |
|----------|-------|----------|
| Pick started, app killed before DB update | File saved, DB not updated | Orphan file (acceptable, rare) |
| Pick complete, sync pending, app killed | File saved, DB updated | Sync resumes on next launch |
| Remove complete, sync pending, app killed | File deleted, DB updated | Sync resumes on next launch |

### 2. Offline Operations

All operations work offline:
- Pick: Saves locally, sets sync flag
- Remove: Deletes locally, sets sync flag
- Sync happens automatically when online

### 3. Slot Index Consistency

```
Problem: User picks slot 0, then slot 2 (skipping 1)
         Images array: [ImageSlot(0.jpg), empty, ImageSlot(2.jpg), ...]

Solution: UI always fills first empty slot, but model supports any slot
          PDF generation iterates all slots, skips empty ones
```

### 4. Race Condition: User Changes During Sync

```
Problem:
1. Sync starts uploading slot 2 (version = 5)
2. User removes image during upload (version becomes 6)
3. User picks new image (version becomes 7)
4. Sync finishes - must NOT clear needsSync flag for new image

Why path comparison fails:
- Paths are static (always "2.jpg" for slot 2)
- Old and new photos have same path name
- Cannot detect content change from path alone

Solution: VERSION COUNTER
- Each Pick and Remove increments the slot's version number
- Sync remembers version when it starts (e.g., version = 5)
- Before clearing flags, re-fetch and compare versions
- If version changed (now 7), user modified slot - don't clear flags
- If version same, safe to clear flags

Benefits:
- Zero risk of endless sync loops (unlike hash comparison)
- No file I/O overhead
- Deterministic - version only changes on explicit user action
```

### 5. Multiple Rapid Operations on Same Slot

```
User: Pick(2) → Remove(2) → Pick(2) → Remove(2) (rapidly)

Each operation is atomic and instant.
Final state is what matters.
Fixed path (2.jpg) means only one file exists at any time.
```

### 6. Deleting Snag with Images

```
When snag is deleted:
1. Delete all local image files (0-5.jpg)
2. Delete snag from local DB
3. Mark for Firebase deletion (snag + all images)
4. Sync deletes from Firebase Storage + Firestore
```

### 7. Reordering Images

```
User wants photo 3 to become photo 0

NOT SUPPORTED - Too complex:
- Would need to rename files
- Firebase paths would change
- Sync state becomes complicated

Alternative: User removes and re-adds in desired order
```

### 8. PDF Generation with Gaps

```
Images: [slot0, empty, slot2, slot3, empty, empty]

PDF should:
- Skip empty slots
- Show 3 photos in logical order
- NOT leave visual gaps
```

### 9. Fix Images Before Problem Images

```
Scenario: Fixer tries to add fix images before owner added problem images

Rule: Problem images are optional but typically added first
      Fix images are added by assigned fixer
      No dependency between them - both independent
```

---

## Sync Failure Handling

### Upload Failure

```dart
try {
  await uploadToFirebase(localPath, firebasePath);
  // Success: clear sync flags
  updatedSlots[i] = slot.copyWith(needsSync: false, markedForDeletion: false);
} catch (e) {
  // Failure: KEEP sync flags, will retry next sync cycle
  // Log error but don't crash
  debugPrint('Upload failed for slot $i: $e');
  // Slot state unchanged - will retry
}
```

### Delete Failure

```dart
try {
  await deleteFromFirebase(firebasePath);
} catch (e) {
  // Firebase delete of non-existent file may throw - ignore
  // Or network failure - will retry next sync
  if (e is FirebaseException && e.code == 'object-not-found') {
    // File doesn't exist - treat as success
  } else {
    // Real failure - keep flags for retry
    debugPrint('Delete failed for slot $i: $e');
    return; // Don't clear flags
  }
}
updatedSlots[i] = slot.markSynced();
```

### Retry Strategy

- Sync runs on app launch and when connectivity restored
- Failed slots keep their flags, will be retried
- No exponential backoff needed (sync is user-triggered or connectivity-triggered)

---

## Download Flow (Shared Users)

When a shared user views a snag, they need to download images from Firebase.

### When to Download

| Scenario | Action |
|----------|--------|
| Shared user opens snag | Download all images with firebasePath but no localPath |
| Owner views own snag | Images already local, no download needed |
| After sync | If firebasePath updated remotely, download new version |

### Download Logic

```dart
Future<void> downloadSnagImages(Snag snag, String currentUserId) async {
  // Only download if we're not the owner (shared user)
  if (snag.ownerEmail == currentUserEmail) return;

  List<ImageSlot> updatedSlots = List.from(snag.images);

  for (int i = 0; i < 6; i++) {
    final slot = updatedSlots[i];

    // Has Firebase image but no local copy
    if (slot.firebasePath != null && slot.localPath == null) {
      try {
        final localPath = SnagImagePaths.localPath(
          userId: currentUserId,
          siteId: snag.siteUID,
          snagId: snag.id,
          index: i,
        );

        await downloadFromFirebase(slot.firebasePath!, localPath);

        updatedSlots[i] = slot.copyWith(localPath: localPath);
      } catch (e) {
        debugPrint('Download failed for slot $i: $e');
        // Continue with other slots
      }
    }
  }

  // Update local DB with downloaded paths
  final updatedSnag = snag.copyWith(images: updatedSlots);
  await updateSnagInDb(updatedSnag);
}
```

### Download Triggers

1. **Snag detail screen opened** - Download missing images
2. **Pull to refresh** - Re-check for new images
3. **Background sync** - Download newly shared snags

---

## Permission Matrix

### Problem Photos (Documenting defect)

| Role | Add | Remove | View |
|------|-----|--------|------|
| Owner | Yes | Yes | Yes |
| Fixer (assigned) | No | No | Yes |
| Viewer (VIEW access) | No | No | Yes |

### Fix Photos (Documenting repair)

| Role | Add | Remove | View |
|------|-----|--------|------|
| Owner | Yes | Yes | Yes |
| Fixer (assigned) | Yes | Yes (own only) | Yes |
| Viewer (VIEW access) | No | No | Yes |

**Note:** Fixer can only modify fix photos they added. Owner has full control.

---

## Why Version Counter (Not Hash)

Since file paths are static (`0.jpg`, `1.jpg`, etc.), we cannot detect content changes by comparing paths. Two approaches were considered:

### Option A: Hash Comparison
- Compute MD5/SHA hash of file before and after sync
- Different hash = user changed the file

**Problems:**
- Risk of endless sync loops if hash computation is inconsistent
- Requires file I/O (reading file twice per sync)
- Edge cases with partial reads or concurrent access

### Option B: Version Counter ✓ (Chosen)
- Integer field incremented on every Pick and Remove
- Sync remembers version at start, compares at end
- Different version = user changed the slot

**Benefits:**
- Zero risk of endless loops (version only changes on explicit user action)
- No file I/O overhead
- Simple integer comparison
- Deterministic and reliable

---

## Comparison: Site vs Snag Images

| Aspect | Site | Snag |
|--------|------|------|
| Count | 1 image | 6 problem + 6 fix |
| Storage | Single fields | List<ImageSlot> |
| Path pattern | `site.jpg` | `{index}.jpg` |
| Local base | `Sites/{siteId}/` | `Sites/{siteId}/Snags/{snagId}/` |
| Firebase base | `sites/{uid}/{sid}/` | `sites/{uid}/{sid}/snags/{snagId}/` |
| Instant operations | Yes | Yes |
| Save independence | Yes | Yes |
| No direct replace | Yes | Yes |
| Cleanup NEW on Back | Yes | Yes |

---

## Implementation Tasks

### 1. Create ImageSlot Class ✅ DONE
- [x] Create `lib/Data/models/image_slot.dart`
- [x] Implement all methods and getters
- [x] Include `version` field (int, starts at 0, incremented on Pick/Remove)
- [x] Add JSON serialization (for Firestore List storage)

### 2. Update Snag Model ✅ DONE
- [x] Add `List<ImageSlot> images` field (length 6)
- [x] Add `List<ImageSlot> fixImages` field (length 6)
- [x] Add helper getters
- [x] Update `copyWith`, `toJson`, `fromJson`
- [x] Update `toFirestore`, `fromFirestore`
- [x] Replaced old individual image fields with ImageSlot lists

### 3. Create Snag Database Layer ✅ DONE
- [x] Create `lib/Data/database/tables/snags_table.dart`
- [x] Create `lib/Data/database/daos/snag_dao.dart`
- [x] Update `app_database.dart` (register table + DAO, migration v3)
- [x] Run build_runner to generate .g.dart files

### 4. Create SnagImagePaths Helper
- [ ] `localPath(userId, siteId, snagId, index, isFix)` - computes local path
- [ ] `firebasePath(ownerUID, siteId, snagId, index, isFix)` - computes Firebase path

### 5. Create SnagImageService
- [ ] `pickImage(snagId, slotIndex, isFix)` - handles pick flow
- [ ] `removeImage(snagId, slotIndex, isFix)` - handles remove flow
- [ ] `downloadImage(snagId, slotIndex, isFix)` - for shared users

### 6. Update Sync Handler
- [ ] Add `syncSnagImages(snag)` method
- [ ] Add `syncSnagFixImages(snag)` method
- [ ] Handle per-slot sync with error handling
- [ ] Use version comparison before clearing flags (race condition fix)

### 7. Add Download Handler
- [ ] `downloadSnagImages(snag)` - for shared users
- [ ] Trigger on snag detail screen open
- [ ] Handle download failures gracefully

### 8. Update UI (CreateSnagV2)
- [ ] Dynamic slot display based on filled count
- [ ] "Add more" button until 6 reached
- [ ] Per-slot delete functionality
- [ ] Instant operations for EXISTING snag
- [ ] State-based operations for NEW snag

### 9. Cleanup Logic
- [ ] Delete orphan files on Back for NEW snag
- [ ] Delete all images when snag deleted
- [ ] Handle partial cleanup on errors

### 10. Permission Enforcement
- [ ] Owner: full access to problem + fix photos
- [ ] Fixer: add/remove fix photos only
- [ ] Viewer: read-only

---

## Testing Checklist

### Functional Tests

- [ ] NEW snag: Pick(0) → Save → Image synced
- [ ] NEW snag: Pick(0) → Back → File cleaned up
- [ ] NEW snag: Pick(0,1,2) → Save → All synced
- [ ] EXISTING snag: Pick(3) → Image synced
- [ ] EXISTING snag: Remove(1) → Firebase deleted
- [ ] EXISTING snag: Remove(1) → Pick(1) → New image synced
- [ ] Offline: All operations work, sync when online
- [ ] 6 photos: Can add up to 6, no more
- [ ] Fix photos: Fixer can add fix images

### Sync & Download Tests

- [ ] Upload failure: Flags preserved, retries on next sync
- [ ] Delete failure (not found): Treated as success
- [ ] Shared user: Downloads images on snag view
- [ ] Race condition: User change during sync preserved (version incremented)
- [ ] Version counter: Increments on Pick, increments on Remove

### Permission Tests

- [ ] Owner: Can add/remove problem photos
- [ ] Owner: Can add/remove fix photos
- [ ] Fixer: Can add/remove fix photos (own only)
- [ ] Fixer: Cannot modify problem photos
- [ ] Viewer: Cannot modify any photos

### Edge Case Tests

- [ ] Skip slot: Pick(0), Pick(2) - works correctly
- [ ] Rapid operations: Pick → Remove → Pick on same slot
- [ ] Snag deletion: All images cleaned up

### UI Tests

- [ ] Layout adapts: 1 photo, 2 photos, 3 photos, etc.
- [ ] "Add more" disappears at 6 photos
- [ ] Delete button works on each photo
- [ ] PDF preview shows correct layout (3 per row)

---

## Summary

1. **ImageSlot Class**: Encapsulates per-slot state (matches Site's single-image fields)
2. **6 Fixed Slots**: Problem photos + Fix photos, index-based naming
3. **Instant & Independent**: Image operations don't wait for Save
4. **Remove Before Replace**: No direct image replacement
5. **Fixed Paths**: `{index}.jpg` - always overwrites
6. **Preserve markedForDeletion Flag**: Don't clear on Pick after Remove
7. **Cleanup NEW on Back**: Delete orphan files
8. **Sync Per-Slot**: Each slot synced independently
9. **Version Counter**: Detects user changes during sync (avoids race conditions)

This architecture ensures robust, offline-first image handling consistent with Site patterns, scaled for multiple images per snag.