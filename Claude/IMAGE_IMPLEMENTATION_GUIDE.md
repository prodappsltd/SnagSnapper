# Image Implementation Guide - Phase 1: Profile Images

## Overview
This document provides a comprehensive implementation guide for the enhanced image handling system, focusing on Phase 1 (Profile Images). It covers the complete flow from image selection to display, with robust edge case handling and offline support.

## Key Design Decisions

### 1. Relative Path Storage
- **Decision**: Store only relative paths in Firestore (e.g., `userUID/profile.jpg`)
- **Benefits**:
  - Single source of truth
  - Easy switching between local cache and Firebase Storage
  - Simplified state management
  - Future flexibility (CDN, different storage providers)

### 2. Offline-First Architecture
- **Decision**: Always save locally first, sync when possible
- **Benefits**:
  - Works without internet
  - Instant image display from cache
  - Better user experience
  - Reduced Firebase Storage costs

### 3. UI Flow for Profile Images
- **When image exists**: Show image with delete button only
- **When no image**: Show "Add Company Logo" button
- **No direct replacement**: Must delete first, then add new

## Complete Flow Documentation

### Step 1: Image Selection
User taps "Add Company Logo" → Camera/Gallery dialog

**Edge Cases:**
- ❌ **No permissions**: Show permission dialog
- ❌ **User cancels**: Return to profile, no changes
- ❌ **Camera/Gallery fails**: Show appropriate error

### Step 2: Image Processing
```dart
// Process captured image
1. Decode image
2. Resize to 1200x1200 max (maintain aspect ratio)
3. Convert to JPEG
4. Compress to under 400KB (iterative quality reduction)
```

**Edge Cases:**
- ❌ **Corrupt file**: Show "Invalid image format"
- ❌ **Too large**: Show "Image too large"
- ❌ **Out of memory**: Show "Unable to process image"
- ✅ **HEIC format**: Auto-convert to JPEG

### Step 3: Upload Process

**Scenario A: First Time Upload (No existing image)**
```dart
1. Generate path: "userUID/profile.jpg"
2. Save locally: /cache/userUID/profile.jpg
3. Upload to Firebase Storage
4. Update Firestore: profileImage = "userUID/profile.jpg"
5. Update UI
```

**Scenario B: After Deletion (Same as first time)**
```dart
// Identical to Scenario A
// No image replacement logic needed
```

**Edge Cases:**
- ❌ **No internet**: 
  - Save to pending queue
  - Show with sync indicator
  - Auto-retry when online
- ❌ **Upload fails**: 
  - Keep local copy
  - Allow manual retry
- ❌ **Firestore fails**: 
  - Delete uploaded image
  - Rollback to previous state

### Step 4: Display Process
```dart
// Profile screen loads with imagePath from Firestore
1. Check local cache first
2. If cached: Display immediately
3. Validate cache in background (ETag check)
4. Download if needed
```

**Edge Cases:**
- ✅ **Cache valid**: No network call needed
- ❌ **No cache**: Download from Firebase
- ❌ **Corrupted cache**: Delete and re-download
- ❌ **No internet + no cache**: Show error placeholder
- ❌ **Storage file deleted**: Clear Firestore reference

### Step 5: Delete Process
```dart
1. Show confirmation dialog
2. Clear Firestore reference first
3. Delete from Firebase Storage
4. Clear local cache
5. Update UI to show "Add Company Logo"
```

**Edge Cases:**
- ✅ **Firestore fails**: Nothing deleted, show error
- ⚠️ **Storage delete fails**: Already cleared from Firestore, log error

## State Management

```dart
class ImageState {
  final String? relativePath;      // "userUID/profile.jpg"
  final ImageStatus status;        
  final File? localFile;          
  final bool hasPendingUpload;    
  final DateTime? lastSyncTime;   
  final String? error;            
  final double? uploadProgress;   
}

enum ImageStatus {
  none,           // No image
  loading,        // Downloading
  cached,         // Available locally
  uploading,      // Upload in progress
  pendingSync,    // Offline, waiting to sync
  error,          // Operation failed
}
```

## Offline Support

### Upload Queue
```dart
class UploadQueueItem {
  final String relativePath;
  final String localTempPath;
  final DateTime timestamp;
  final int retryCount;
}

// Persist queue to SharedPreferences
// Process on app start or connection change
```

### Background Sync
```dart
// On app start or foreground
syncPendingUploads() async {
  final queue = await loadUploadQueue();
  for (final item in queue) {
    try {
      await uploadToFirebase(item);
      await updateFirestore(item);
      await removeFromQueue(item);
    } catch (e) {
      incrementRetryCount(item);
    }
  }
}
```

## Implementation Checklist

### Phase 1.1: Core Enhancements
- [ ] Update ImageService to use relative paths
- [ ] Implement ImagePathResolver for URL/path resolution
- [ ] Add upload queue with persistence
- [ ] Enhance error handling with proper messages

### Phase 1.2: UI Improvements
- [ ] Create SmartImage widget with state management
- [ ] Add loading/sync indicators
- [ ] Implement retry UI for failed uploads
- [ ] Show appropriate error placeholders

### Phase 1.3: Testing
- [ ] Unit tests for ImageService methods
- [ ] Widget tests for image display states
- [ ] Integration tests for complete flow
- [ ] Test offline scenarios

### Phase 1.4: Monitoring
- [ ] Add Crashlytics logging for errors
- [ ] Track cache hit rates
- [ ] Monitor upload success/failure rates
- [ ] Log image operation metrics

## Code Examples

### Enhanced ImageService Usage
```dart
// Simple API for profile screen
final imagePath = await ImageService().uploadProfileImage(
  imageData: processedImage.data,
  userId: currentUser.uid,
);

// Smart display widget
ImageService().smartImage(
  relativePath: appUser.imagePath,
  placeholder: AddPhotoButton(onTap: _selectImage),
)
```

### Profile Screen Integration
```dart
// Minimal changes to existing code
Future<void> _handleImageSelection(ImageSource source) async {
  try {
    setState(() => busy = true);
    
    final image = await ImageService().captureImage(
      source: source,
      type: ImageType.profile,
    );
    
    if (image != null) {
      final path = await ImageService().uploadProfileImage(
        image.data,
        FirebaseAuth.instance.currentUser!.uid,
      );
      
      appUser.imagePath = path;
      await contentProvider.updateProfileImage();
    }
  } catch (e) {
    // Show error to user
  } finally {
    setState(() => busy = false);
  }
}
```

## Cost & Performance Benefits

1. **Bandwidth Reduction**: ~95% through local caching
2. **Instant Display**: 0ms for cached images
3. **Offline Support**: Full functionality without internet
4. **User Experience**: Clear feedback for all states

## Next Steps

After Phase 1 completion:
- Phase 2: Site Images (with thumbnails)
- Phase 3: Snag Images (multiple per snag)
- Phase 4: Batch operations optimization

## References
- [IMAGE_SERVICE_PLAN.md](./IMAGE_SERVICE_PLAN.md) - Original architecture plan
- [PROJECT_RULES.md](./PROJECT_RULES.md) - Development guidelines
- [validation_rules.dart](../lib/Constants/validation_rules.dart) - Session context