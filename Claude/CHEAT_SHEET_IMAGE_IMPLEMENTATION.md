# Profile Image Implementation - Quick Reference

## 🎯 What to Implement
Fix 2 methods in `/lib/Screens/profile/profile_screen_ui_matched.dart`:
1. `_buildImageDisplay()` - Line 1170
2. `_showImageSelectionDialog()` - Line 448

## 📁 Files to Modify
```
/lib/Screens/profile/profile_screen_ui_matched.dart
```

## 📦 Add Imports
```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
```

## 🔧 Existing Services (Already Available)
- `ImageStorageService` - Local storage handling
- `ImageCompressionService` - PRD-compliant compression
- `ProfileImagePicker` - Widget (optional use)

## ✅ PRD Requirements
- **Optimal**: < 600KB ✅
- **Maximum**: < 1MB ✅
- **Dimensions**: 1024x1024 ✅
- **Format**: JPEG ✅
- **Quality**: 85% → 30% ✅

## 🔄 Data Flow
```
Pick → Compress → Save Local → Update DB → Display → Sync Later
```

## 💾 Storage Paths
- **Local**: `/AppDocuments/SnagSnapper/{userId}/Profile/profile_{timestamp}.jpg`
- **Database**: `imageLocalPath = "SnagSnapper/{userId}/Profile/profile_123.jpg"`
- **Sync Flag**: `needsImageSync = true`

## 🎨 User Messages (PRD Required)
```dart
// Optimal
"✅ Image optimized successfully (size: XXXkB)"

// Acceptable  
"⚠️ Image compressed to XXXkB (larger than optimal)"

// Rejected
"❌ Image too complex. Please choose a simpler image"
```

## 🔑 Key Methods to Add
```dart
// 1. Image picker
Future<void> _pickImage(ImageSource source)

// 2. File helper
Future<File> _getImageFile(String path)

// 3. Updated deletion
void _handleImageDeletion()
```

## ⚠️ Critical Rules
1. **NEVER** use Firebase URLs for display
2. **ALWAYS** display from local file path
3. **ALWAYS** save locally first
4. Set `needsImageSync = true` after changes
5. Use `kDebugMode` for all debug prints

## 🧪 Test Scenarios
1. Pick from camera
2. Pick from gallery
3. Delete image
4. Image < 600KB (optimal)
5. Image 600KB-1MB (acceptable)
6. Image > 1MB (rejected)
7. Offline mode
8. Invalid image format

## 📝 Implementation Steps
1. Copy code from `PROFILE_IMAGE_IMPLEMENTATION_PLAN.md`
2. Add imports
3. Replace `_buildImageDisplay()`
4. Implement `_showImageSelectionDialog()`
5. Add `_pickImage()` method
6. Add `_getImageFile()` helper
7. Update `_handleImageDeletion()`
8. Test all scenarios

## 🚀 Quick Start
```bash
# Full implementation details
open Claude/02-MODULES/Profile/PROFILE_IMAGE_IMPLEMENTATION_PLAN.md
```

## 🐛 Common Issues
- **Image not showing**: Check file path is relative/absolute
- **Compression fails**: Ensure image package imported
- **Permission denied**: Add camera/gallery permissions
- **Sync not triggered**: Verify `needsImageSync` flag set

## 📊 Success Metrics
- [ ] Images display from local storage
- [ ] Two-tier validation works
- [ ] Sync flags set correctly
- [ ] Works offline
- [ ] PRD messages shown
- [ ] No Firebase dependency for display