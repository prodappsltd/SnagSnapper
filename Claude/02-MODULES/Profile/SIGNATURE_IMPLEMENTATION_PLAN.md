# Signature Capture Implementation Plan

## Overview
Implement digital signature capture following TDD approach and project rules.

## Phase 1: Test Setup and Core Logic (TDD)

### 1.1 Write Unit Tests First
**File**: `test/unit/services/signature_service_test.dart`
- [ ] Test signature point collection
- [ ] Test stroke management (add, clear)
- [ ] Test canvas boundary validation
- [ ] Test image generation from strokes
- [ ] Test auto-crop algorithm
- [ ] Test JPEG conversion with quality

### 1.2 Implement SignatureService
**File**: `lib/services/signature_service.dart`
```dart
class SignatureService {
  // Manage signature strokes
  List<List<Offset>> strokes = [];
  
  // Add stroke point
  void addPoint(Offset point);
  
  // Start new stroke
  void startNewStroke();
  
  // Clear all strokes
  void clear();
  
  // Convert strokes to image
  Future<Uint8List> generateImage(Size canvasSize);
  
  // Auto-crop whitespace
  Uint8List cropImage(Uint8List imageData);
  
  // Save as JPEG
  Future<String> saveSignature(String userId, Uint8List imageData);
}
```

## Phase 2: Widget Tests

### 2.1 Write Widget Tests First
**File**: `test/widget/signature_capture_screen_test.dart`
- [ ] Test screen initialization
- [ ] Test drawing gestures (pan start, update, end)
- [ ] Test clear button functionality
- [ ] Test cancel button (returns null)
- [ ] Test save button (returns path)
- [ ] Test portrait lock
- [ ] Test responsive canvas sizing

### 2.2 Implement SignatureCaptureScreen
**File**: `lib/Screens/profile/signature_capture_screen.dart`
```dart
class SignatureCaptureScreen extends StatefulWidget {
  final String userId;
  
  const SignatureCaptureScreen({required this.userId});
  
  // Show as full screen, return path or null
  static Future<String?> show(BuildContext context, String userId);
}
```

### 2.3 Implement SignaturePainter
**File**: `lib/widgets/signature_painter.dart`
```dart
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw strokes with 3px black lines
  }
}
```

## Phase 3: Integration with Profile

### 3.1 Write Integration Tests
**File**: `test/integration/signature_integration_test.dart`
- [ ] Test signature capture from profile screen
- [ ] Test signature preview display
- [ ] Test signature deletion flow
- [ ] Test database updates
- [ ] Test sync flag management
- [ ] Test offline behavior

### 3.2 Update ProfileScreen
**File**: `lib/Screens/profile/profile_screen_ui_matched.dart`
- [ ] Add signature preview widget
- [ ] Add tap handler to open capture
- [ ] Add delete button with confirmation
- [ ] Handle return from capture screen
- [ ] Update database on changes

### 3.3 Database Integration
- [ ] Update ProfileDao for signature operations
- [ ] Ensure sync flags set correctly
- [ ] Handle file storage paths

## Phase 4: File Management

### 4.1 Storage Tests
**File**: `test/unit/services/signature_storage_test.dart`
- [ ] Test file save to correct path
- [ ] Test file deletion
- [ ] Test path generation
- [ ] Test old file cleanup

### 4.2 Implement Storage Logic
- [ ] Save to `SnagSnapper/{userId}/Profile/signature.jpg`
- [ ] Delete old signature on replacement
- [ ] Handle storage errors
- [ ] Clean up on deletion

## Phase 5: Sync Integration

### 5.1 Sync Tests
**File**: `test/unit/services/signature_sync_test.dart`
- [ ] Test upload to Firebase
- [ ] Test deletion sync
- [ ] Test sync flag clearing
- [ ] Test error handling

### 5.2 Update Sync Service
- [ ] Handle signature in ProfileSyncHandler
- [ ] Upload to `users/{userId}/signature.jpg`
- [ ] Delete from Firebase when null
- [ ] Update sync flags

## Phase 6: UI Polish and Error Handling

### 6.1 Visual Design
- [ ] Dark grey background (#424242)
- [ ] White canvas (#FFFFFF)
- [ ] Orange buttons (#FF6E00)
- [ ] Fixed colors (not theme-dependent)

### 6.2 Error States
- [ ] Storage full handling
- [ ] Permission errors
- [ ] Canvas initialization errors
- [ ] Save failures with retry

## Phase 7: Performance and Memory

### 7.1 Performance Tests
- [ ] Test smooth drawing performance
- [ ] Test memory usage during drawing
- [ ] Test large signature handling

### 7.2 Optimizations
- [ ] Efficient stroke storage
- [ ] Proper resource disposal
- [ ] Image cache management
- [ ] Canvas optimization

## Phase 8: Manual Testing

### 8.1 Device Testing
- [ ] Test on small phones (< 640px width)
- [ ] Test on tablets
- [ ] Test on iOS devices
- [ ] Test on Android devices

### 8.2 Offline Testing
- [ ] Works in airplane mode
- [ ] Saves locally without network
- [ ] Syncs when reconnected
- [ ] No data loss

### 8.3 User Flow Testing
- [ ] Complete signature addition
- [ ] Signature replacement
- [ ] Signature deletion
- [ ] Cancel without saving
- [ ] Multiple signatures in session

## Validation Checklist (Per PROJECT_RULES.md)

### Architecture Compliance
- [ ] Works 100% offline
- [ ] Local database checked first
- [ ] Firebase only for sync
- [ ] No blocking network operations
- [ ] Sync flags managed correctly

### Code Quality
- [ ] TDD - Tests written first
- [ ] Comments on all complex logic
- [ ] Debug statements in dev mode
- [ ] Error logging in catch blocks
- [ ] SOLID principles followed

### Testing Coverage
- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Integration tests pass
- [ ] Manual testing in airplane mode
- [ ] Architecture compliance verified

### Documentation
- [ ] PRD updated
- [ ] Technical spec created
- [ ] Implementation plan documented
- [ ] Code comments added
- [ ] Test documentation complete

## Implementation Order

1. **Day 1: Core Logic (TDD)**
   - Write SignatureService tests
   - Implement SignatureService
   - Write storage tests
   - Implement storage logic

2. **Day 2: UI Components (TDD)**
   - Write widget tests
   - Implement SignatureCaptureScreen
   - Implement SignaturePainter
   - Test drawing functionality

3. **Day 3: Integration**
   - Write integration tests
   - Update ProfileScreen
   - Test full flow
   - Handle edge cases

4. **Day 4: Polish & Testing**
   - Visual design implementation
   - Error handling
   - Performance optimization
   - Manual testing

## Definition of Done
- All tests pass (unit, widget, integration)
- Works completely offline
- Smooth drawing performance
- Proper error handling
- Sync works when online
- Manual testing completed
- Documentation updated
- Code reviewed and approved