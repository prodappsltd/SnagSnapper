# SnagSnapper Centralized Image Service Plan

## Overview
A centralized image service to handle all image operations in the app including capture, compression, storage, caching, and retrieval. This service will significantly reduce Firebase Storage costs and improve app performance.

## Architecture

### Core Components
```
┌─────────────────────────────────────────────────────────────┐
│                     ImageService                             │
├─────────────────────────────────────────────────────────────┤
│  • Image capture (camera/gallery)                           │
│  • JPEG/PNG conversion & compression                        │
│  • Size validation & optimization                           │
│  • Firebase Storage upload/download                         │
│  • Local caching with ETag validation                       │
│  • Thumbnail generation                                      │
└─────────────────────────────────────────────────────────────┘
```

### Storage Structure
```
Firebase Storage:
/{userUID}/profile.jpg          # User's company logo
/{userUID}/signature.png        # User's signature (PNG for transparency)
/{userUID}/{siteUID}/site.jpg   # Site main image
/{userUID}/{siteUID}/{snagUID}/snag1.jpg  # Snag images (up to 8)
/{userUID}/{siteUID}/{snagUID}/snag2.jpg
...
/{userUID}/{siteUID}/{snagUID}/snag8.jpg
```

### Local Cache Structure
```
Application Documents Directory (Permanent Storage):
/image_cache/{userUID}/profile.jpg
/image_cache/{userUID}/signature.png
/image_cache/{userUID}/{siteUID}/site.jpg
/image_cache/{userUID}/{siteUID}/{snagUID}/snag1.jpg
```

## Image Specifications

### Image Types and Limits
| Type | Dimensions | Max Size | Quality | Format | Usage |
|------|------------|----------|---------|--------|-------|
| Profile Photo | 1200x1200 | 400KB | 85% | JPEG | Company logo on profile |
| Signature | 600x300 | 200KB | N/A | PNG | User signature |
| Site Photo | 1200x1200 | 400KB | 85% | JPEG | Site main image |
| Snag Photo | 800x800 | 250KB | 85% | JPEG | Snag documentation |
| Thumbnail | 200x200 | 25KB | 80% | JPEG | List views |

### PDF Requirements
- PDF displays images at 180x180 points
- Minimum resolution needed: 360x360px (2x for quality)
- Current spec of 800x800 provides good quality with 4x resolution

## Implementation Details

### 1. Image Processing Pipeline
```dart
1. Capture/Select Image
2. Validate image size/format
3. Resize to target dimensions
4. Convert to JPEG (except signatures)
5. Compress with quality setting
6. If size > limit:
   - Reduce quality by 5%
   - Repeat until size <= limit or quality < 60%
7. Generate thumbnail (for list items)
8. Return processed image
```

### 2. Upload Process
```dart
1. Process image as above
2. Generate unique filename (or use fixed name)
3. Upload to Firebase Storage
4. Get download URL
5. Save URL to Firestore
6. Cache image locally with metadata
```

### 3. Download & Cache Strategy
```dart
1. Check local cache for image
2. If exists:
   - Get Firebase Storage metadata (lightweight call)
   - Compare ETag/updated timestamp
   - If unchanged, use cached version
   - If changed, download new version
3. If not exists:
   - Download from Firebase Storage
   - Save to local cache with metadata
4. Return image data
```

### 4. Cache Management
- **Storage**: Application Documents Directory (permanent)
- **Validation**: ETag comparison with Firebase Storage
- **Cleanup**: Automatic when parent entity deleted
- **Memory**: No memory cache (load from file as needed)

## Cost Analysis

### Without Optimization (Current)
- 100 users, 50 sites, 50 snags each
- Daily usage: 200GB
- Monthly cost: **$720**

### With Optimization
- Caching + Thumbnails + Compression
- Daily usage: ~10GB (95% reduction)
- Monthly cost: **$36**
- **Savings: $684/month per 100 users**

## API Design

### ImageService Class
```dart
class ImageService {
  // Singleton instance
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  
  // Image capture and processing
  Future<ProcessedImage> captureImage({
    required ImageSource source,
    required ImageType type,
  });
  
  // Upload to Firebase Storage
  Future<String> uploadImage({
    required Uint8List imageData,
    required String path,
    bool generateThumbnail = false,
  });
  
  // Download with caching
  Future<Uint8List?> getImage({
    required String url,
    bool thumbnail = false,
  });
  
  // Delete image
  Future<void> deleteImage(String url);
  
  // Cache management
  Future<void> clearCache({String? path});
}
```

### Supporting Classes
```dart
enum ImageType {
  profile(1200, 1200, 400000, 0.85, ImageFormat.jpeg),
  signature(600, 300, 200000, 1.0, ImageFormat.png),
  site(1200, 1200, 400000, 0.85, ImageFormat.jpeg),
  snag(800, 800, 250000, 0.85, ImageFormat.jpeg),
  thumbnail(200, 200, 25000, 0.80, ImageFormat.jpeg);
  
  final int maxWidth;
  final int maxHeight;
  final int maxSizeBytes;
  final double initialQuality;
  final ImageFormat format;
}

class ProcessedImage {
  final Uint8List data;
  final Uint8List? thumbnail;
  final ImageMetadata metadata;
}
```

## Implementation Phases

### Phase 1: Profile Images (Current Focus)
1. Create ImageService with core functionality
2. Implement image processing pipeline
3. Fix camera capture to return processed image
4. Update profile screens to use ImageService
5. Migrate from base64 to Firebase Storage URLs
6. Add caching with ETag validation
7. Test and refine

### Phase 2: Site Images
1. Extend ImageService for site images
2. Update site screens
3. Implement thumbnail generation
4. Migrate existing base64 images

### Phase 3: Snag Images
1. Handle multiple images per snag
2. Implement batch upload/download
3. Optimize for PDF generation
4. Complete migration

## Security Considerations

### Firebase Storage Rules
```javascript
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only access their own images
    match /{userId}/{allPaths=**} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId
        && request.auth.token.email_verified == true;
    }
  }
}
```

### Firestore Rules
- Store only Firebase Storage URLs (not base64)
- Validate URL format matches Firebase Storage
- Ensure URL belongs to user's storage path

## Migration Strategy

### From Base64 to Firebase Storage
1. On next image update:
   - Upload to Firebase Storage
   - Get URL
   - Replace base64 with URL
2. Gradual migration (no bulk conversion needed)
3. Backward compatibility during transition

## Testing Requirements

1. Unit tests for image processing
2. Integration tests for upload/download
3. Cache validation tests
4. Network failure handling
5. Large image handling
6. Quality degradation limits

## Performance Metrics

### Target Metrics
- Image processing: < 2 seconds
- Upload time: < 5 seconds (on 4G)
- Cache hit rate: > 90%
- Storage cost reduction: > 90%

### Monitoring
- Track cache hit/miss ratio
- Monitor processing times
- Log upload/download failures
- Track storage usage per user

## Error Handling

1. **Processing Errors**
   - Fall back to original image
   - Show user-friendly error
   - Log for debugging

2. **Network Errors**
   - Use cached version if available
   - Queue uploads for retry
   - Show offline indicator

3. **Storage Errors**
   - Validate quotas
   - Handle permission errors
   - Provide clear user feedback

## Future Enhancements

1. **Progressive Loading**
   - Show thumbnail immediately
   - Load full image in background

2. **Smart Compression**
   - Analyze image content
   - Adjust quality based on complexity

3. **Batch Operations**
   - Upload multiple images efficiently
   - Parallel processing

4. **Image CDN**
   - Use Firebase CDN features
   - Regional caching

## Dependencies

### Required Packages
```yaml
dependencies:
  image_picker: ^1.0.0
  image: ^4.0.0  # For image processing
  path_provider: ^2.0.0
  firebase_storage: ^11.0.0
  http: ^1.0.0  # For ETag checks
  uuid: ^4.0.0
```

## Notes

- All images stored in Firebase Storage (not Firestore)
- Local cache persists between sessions
- ETag validation ensures fresh images
- Thumbnails only for list views
- PNG only for signatures (transparency)
- JPEG for all other images (smaller size)