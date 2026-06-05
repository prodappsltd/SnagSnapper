# Site & Snag Image Handling Plan

## Overview

This document defines the image handling architecture for Sites and Snags in SnagSnapper. The approach follows the same patterns established in Profile image handling, ensuring consistency across the app.

**Last Updated:** 2026-06-05

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

### 3. Save Button Independence
- Save button handles TEXT fields only (name, address, etc.)
- Image operations are completely independent
- User can press Back after image change - it's already saved

### 4. No Direct Replace
- User CANNOT replace an existing image directly
- Must REMOVE first, then PICK new
- Ensures clean state transitions

### 5. Fixed Path Naming
- Each entity has ONE fixed image path
- New images OVERWRITE old ones (no accumulation)
- No orphan cleanup needed in Firebase

---

## Storage Paths

### Site Images

| Storage | Path Pattern | Example |
|---------|--------------|---------|
| Local | `SnagSnapper/{userId}/Sites/{siteId}/site.jpg` | `SnagSnapper/abc123/Sites/xyz789/site.jpg` |
| Firebase | `sites/{ownerUID}/{siteId}/site.jpg` | `sites/abc123/xyz789/site.jpg` |

### Snag Images (Future)

| Storage | Path Pattern | Example |
|---------|--------------|---------|
| Local | `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/snag.jpg` | `...Snags/snap001/snag.jpg` |
| Firebase | `sites/{ownerUID}/{siteId}/snags/{snagId}/snag.jpg` | `sites/.../snags/snap001/snag.jpg` |

---

## Database Fields

```dart
// Site model fields for image handling
class Site {
  String? imageLocalPath;           // Relative path to local file
  String? imageFirebasePath;        // Firebase Storage path
  bool needsImageSync;              // True when local != Firebase
  bool imageMarkedForDeletion;      // True when image should be deleted from Firebase
}
```

| Field | Purpose |
|-------|---------|
| `imageLocalPath` | Path to local image file. Null = no image |
| `imageFirebasePath` | Path in Firebase Storage. Set immediately on Pick for sync reference |
| `needsImageSync` | Sync flag. True when changes need to upload/delete |
| `imageMarkedForDeletion` | Deletion flag. True when Firebase image should be deleted |

---

## User Actions

| Action | Description | Trigger |
|--------|-------------|---------|
| **PICK** | Select new image from camera/gallery | User taps add/camera button |
| **REMOVE** | Delete existing image | User taps delete/remove button |
| **SAVE** | Save text/form fields | User taps Save button |
| **BACK** | Navigate away | User taps Back or system back |

---

## State Transitions

### Action: PICK (Add New Image)

**Precondition:** No existing image OR image was just removed

```
Before: LP=null, FP=null, NS=false, MD=false/true
After:  LP=path, FP=path, NS=true,  MD=preserved

Steps:
1. User selects image from camera/gallery
2. Image compressed (max 1MB, 1024x1024)
3. Saved to local storage (fixed path, overwrites)
4. Database updated INSTANTLY:
   - imageLocalPath = relative path
   - imageFirebasePath = Firebase path (set immediately!)
   - needsImageSync = true
   - imageMarkedForDeletion = PRESERVED (don't clear if true)
5. UI updates to show new image
```

**Key Point:** `imageMarkedForDeletion` is PRESERVED, not cleared. This handles the Remove → Pick scenario correctly.

### Action: REMOVE (Delete Image)

**Precondition:** Has existing image

```
Before: LP=path, FP=path, NS=any,  MD=false
After:  LP=null, FP=path, NS=true, MD=true

Steps:
1. User confirms deletion
2. Local file deleted from storage
3. Database updated INSTANTLY:
   - imageLocalPath = null
   - imageFirebasePath = KEPT (needed for Firebase deletion)
   - needsImageSync = true
   - imageMarkedForDeletion = true
4. UI updates to show placeholder
```

**Key Point:** `imageFirebasePath` is KEPT so sync handler knows what to delete from Firebase.

---

## Scenario Matrix

### NEW Site (not yet in database)

| # | Action Sequence | Local File | DB Record | Firebase | Notes |
|---|-----------------|------------|-----------|----------|-------|
| N1 | Pick → Save | Saved | Created | Pending upload | Happy path |
| N2 | Pick → Back | Saved | NOT created | None | **Orphan! Needs cleanup** |
| N3 | Pick → Remove → Save | Deleted | Created (no image) | None | Clean |
| N4 | Pick → Remove → Back | Deleted | NOT created | None | Clean |
| N5 | Pick → Remove → Pick → Save | Saved | Created | Pending upload | Latest wins |
| N6 | Pick → Remove → Pick → Back | Saved | NOT created | None | **Orphan! Needs cleanup** |

**Rule:** For NEW sites, cleanup local image file on Back if site not saved.

### EXISTING Site - No Image

| # | Action Sequence | Local File | DB Flags | Firebase | Notes |
|---|-----------------|------------|----------|----------|-------|
| E1 | Pick | Saved | LP=✓ FP=✓ NS=✓ MD=✗ | Pending upload | Instant save |
| E2 | Pick → Remove | Deleted | LP=✗ FP=✗ NS=✓ MD=✓ | Nothing to delete | Cancel out |
| E3 | Pick → Remove → Pick | Saved | LP=✓ FP=✓ NS=✓ MD=✓ | Pending upload | MD preserved |

### EXISTING Site - Has Image

| # | Action Sequence | Local File | DB Flags | Firebase | Notes |
|---|-----------------|------------|----------|----------|-------|
| H1 | Remove | Deleted | LP=✗ FP=✓(old) NS=✓ MD=✓ | Pending delete | FP kept for ref |
| H2 | Remove → Pick | Saved (new) | LP=✓ FP=✓(new) NS=✓ MD=✓ | Pending upload | Overwrites old |

**Note:** There is NO "Pick to replace" scenario. User MUST Remove first.

---

## Sync Handler Logic

```dart
Future<void> syncSiteImage(Site site) async {
  if (!site.needsImageSync) return;

  // Scenario 1: Delete only (no local image, has Firebase image)
  if (site.imageLocalPath == null && site.imageMarkedForDeletion) {
    // Delete from Firebase Storage using fixed path
    await deleteFromFirebase('sites/${site.ownerUID}/${site.id}/site.jpg');

    // Clear flags
    site = site.copyWith(
      imageFirebasePath: null,
      imageMarkedForDeletion: false,
      needsImageSync: false,
    );
    await updateSiteInDb(site);
    return;
  }

  // Scenario 2: Upload (has local image)
  if (site.imageLocalPath != null) {
    // Upload to Firebase (overwrites if exists)
    final storagePath = 'sites/${site.ownerUID}/${site.id}/site.jpg';
    await uploadToFirebase(site.imageLocalPath, storagePath);

    // Clear flags (MD cleared even if was true - upload overwrote)
    site = site.copyWith(
      imageFirebasePath: storagePath,
      imageMarkedForDeletion: false,
      needsImageSync: false,
    );
    await updateSiteInDb(site);
    return;
  }

  // Scenario 3: Nothing to do
  site = site.copyWith(needsImageSync: false);
  await updateSiteInDb(site);
}
```

### Sync Decision Matrix

| imageLocalPath | imageMarkedForDeletion | Action |
|----------------|------------------------|--------|
| null | true | DELETE from Firebase |
| null | false | No-op (nothing to sync) |
| path | true | UPLOAD (overwrites, skip explicit delete) |
| path | false | UPLOAD |

---

## Implementation Tasks

### For Site Images

| # | Task | Priority | Description |
|---|------|----------|-------------|
| 1 | Set `imageFirebasePath` on Pick | HIGH | Must set Firebase path immediately when picking |
| 2 | Preserve `imageMarkedForDeletion` on Pick | HIGH | Don't clear MD flag when picking after remove |
| 3 | Cleanup image on Back for NEW site | HIGH | Delete orphan file if site not saved |
| 4 | Remove `imageChanged` from Save logic | HIGH | Save button should not check image changes |
| 5 | Always `Navigator.pop` after Save | HIGH | User expects to go back after pressing Save |
| 6 | Add `newSite = false` explicitly | LOW | Safety in `_loadValuesFromSite()` |

### For Snag Images (Future)

Same patterns apply:
- Instant Pick/Remove operations
- Fixed path naming (`snag.jpg`)
- Same sync flag logic
- Cleanup on Back for NEW snags

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

### 3. Race Condition: User Changes During Sync

```
1. User removes image
2. Sync starts deleting from Firebase
3. User picks new image before sync completes
4. Sync must NOT overwrite new state with null

Solution: Re-fetch current state before DB update in sync handler
```

### 4. Physical File Deleted Externally

```
imageLocalPath = "path/to/image.jpg"
But file doesn't exist (user cleared cache, etc.)

Solution:
- Display shows placeholder
- Sync handler checks file.existsSync() before upload
- If file missing, clear imageLocalPath
```

### 5. Multiple Rapid Operations

```
User: Pick → Remove → Pick → Remove → Pick (rapidly)

Each operation is atomic and instant.
Final state is what matters.
Fixed path means only one file exists at any time.
```

---

## Comparison: Profile vs Site vs Snag

| Aspect | Profile | Site | Snag |
|--------|---------|------|------|
| Fixed local path | `profile.jpg` | `site.jpg` | `snag.jpg` |
| Fixed Firebase path | `users/{id}/profile.jpg` | `sites/{uid}/{sid}/site.jpg` | `sites/{uid}/{sid}/snags/{snid}/snag.jpg` |
| Instant operations | ✅ | ✅ | ✅ |
| Save button independent | ✅ | ✅ | ✅ |
| No direct replace | ✅ | ✅ | ✅ |
| MD flag preserved on Pick | ✅ | ✅ | ✅ |
| Cleanup NEW on Back | N/A (profile always exists) | ✅ | ✅ |

---

## Code Examples

### Pick Image (Site)

```dart
Future<void> _processImageFromSource(ImageSource source) async {
  // ... pick and compress image ...

  // Save to local storage
  final relativePath = await imageStorage.saveSiteImageFromBytes(
    imageBytes, _firebaseUser.uid, siteId);

  // Update UI state
  setState(() {
    _siteImagePath = relativePath;
  });

  // INSTANT DB update for existing sites
  if (!newSite && site != null) {
    site = site!.copyWith(
      imageLocalPath: relativePath,
      imageFirebasePath: 'sites/${site!.ownerUID}/$siteId/site.jpg', // SET IMMEDIATELY
      needsImageSync: true,
      // imageMarkedForDeletion: PRESERVED (don't set to false!)
      updatedAt: DateTime.now(),
    );
    await database.siteDao.updateSite(site!);
  }
}
```

### Remove Image (Site)

```dart
Future<void> _removeSiteImage() async {
  // Delete local file
  await imageStorage.deleteSiteImage(_firebaseUser.uid, siteId);

  // Update UI state
  setState(() {
    _siteImagePath = '';
  });

  // INSTANT DB update for existing sites
  if (!newSite && site != null) {
    site = site!.copyWith(
      imageLocalPath: null,
      // imageFirebasePath: KEEP for deletion reference
      imageMarkedForDeletion: true,
      needsImageSync: true,
      updatedAt: DateTime.now(),
    );
    await database.siteDao.updateSite(site!);
  }
}
```

### Cleanup on Dispose (NEW Site)

```dart
@override
void dispose() {
  // Cleanup orphan image if NEW site was never saved
  if (newSite && _siteImagePath.isNotEmpty) {
    ImageStorageService.instance.deleteSiteImage(_firebaseUser.uid, _siteId);
  }
  super.dispose();
}
```

---

## Testing Checklist

### Functional Tests

- [ ] NEW site: Pick → Save → Image synced to Firebase
- [ ] NEW site: Pick → Back → Local file cleaned up
- [ ] NEW site: Pick → Remove → Pick → Save → Image synced
- [ ] EXISTING site (no image): Pick → Image synced
- [ ] EXISTING site (has image): Remove → Firebase image deleted
- [ ] EXISTING site (has image): Remove → Pick → New image synced
- [ ] Offline: All operations work, sync when online
- [ ] Race condition: Change during sync handled correctly

### State Verification

- [ ] `imageFirebasePath` set immediately on Pick
- [ ] `imageMarkedForDeletion` preserved on Pick after Remove
- [ ] `needsImageSync` not overwritten by Save button
- [ ] Sync handler clears all flags after successful sync

---

## Summary

1. **Instant & Independent**: Image operations don't wait for Save
2. **Remove Before Replace**: No direct image replacement
3. **Fixed Paths**: `site.jpg` / `snag.jpg` - always overwrites
4. **Preserve MD Flag**: Don't clear on Pick after Remove
5. **Cleanup NEW on Back**: Delete orphan files
6. **Sync Handles All**: Upload/delete happens in background

This architecture ensures robust, offline-first image handling with consistent behavior across Profile, Site, and Snag entities.