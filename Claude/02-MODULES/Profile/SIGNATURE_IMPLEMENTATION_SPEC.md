# Signature Capture Implementation Specification

## Overview
Digital signature capture for user profiles using drawing pad interface.

## User Experience Flow

### When No Signature Exists
1. User sees placeholder with "Add Signature" text
2. User taps placeholder → Full screen signature capture opens
3. User draws signature with finger/stylus
4. User taps "Use Signature" → Signature saved and displayed
5. User taps "Cancel" → Returns without saving

### When Signature Exists  
1. User sees signature preview in form with 'X' button
2. User taps 'X' → Confirmation dialog: "Delete signature?"
3. User confirms → Signature deleted, returns to "Add Signature" state
4. User taps signature → Opens capture screen with existing signature cleared

## Technical Specifications

### Canvas Configuration
- **Aspect Ratio**: 16:9 (widescreen)
- **Dimensions**: 
  - Default: 640x360 pixels
  - If device width < 640px: Use device width, maintain 360px height
- **Orientation**: Locked to portrait mode
- **Background**: White canvas

### Drawing Specifications
- **Stroke Color**: Black (#000000)
- **Stroke Width**: Fixed 3px
- **Stroke Style**: Solid line, no pressure sensitivity
- **Canvas Guides**: None (blank white canvas)

### UI Design
- **Screen Background**: Dark grey (#424242)
- **Canvas Background**: White (#FFFFFF)
- **Buttons**: Construction orange (#FF6E00) with white text
- **Button Text Color**: White (#FFFFFF)
- **Fixed Colors**: Not affected by app theme

### Controls
- **Clear Button**: Clears all strokes from canvas
- **Cancel Button**: Returns without saving
- **Use Signature Button**: Saves and returns to profile

### Storage Specifications

#### File Format
- **Format**: JPEG
- **Quality**: 95%
- **Compression**: Progressive JPEG
- **Color Mode**: RGB

#### File Processing
1. **Auto-crop**: Remove all whitespace around signature
2. **No padding**: Crop tight to signature bounds
3. **No validation**: Any mark is acceptable
4. **No minimum requirements**: Single dot is valid

#### Storage Locations
- **Local Storage**: `/AppDocuments/SnagSnapper/{userId}/Profile/signature.jpg`
- **Database Field**: `signatureLocalPath` (relative path)
- **Firebase Storage**: `users/{userId}/signature.jpg`
- **Firebase URL Field**: `signatureFirebaseUrl`

#### Storage Behavior
- **Single Signature**: Only one signature at a time
- **Replacement**: New signature deletes old file before saving
- **Deletion**: 
  - Delete file from local storage
  - Set `signatureLocalPath` to null
  - Set `needsSignatureSync` to true
  - Sync deletion to Firebase

### Database Updates

#### On Save
```sql
UPDATE profiles SET
  signature_local_path = 'SnagSnapper/{userId}/Profile/signature.jpg',
  needs_signature_sync = true,
  updated_at = CURRENT_TIMESTAMP
WHERE id = {userId}
```

#### On Delete
```sql
UPDATE profiles SET
  signature_local_path = NULL,
  signature_firebase_url = NULL,
  needs_signature_sync = true,
  updated_at = CURRENT_TIMESTAMP
WHERE id = {userId}
```

### Sync Behavior

#### Upload Process
1. Check `needsSignatureSync` flag
2. If true and signature exists:
   - Upload to Firebase Storage
   - Get download URL
   - Update `signatureFirebaseUrl`
   - Clear `needsSignatureSync` flag
3. If true and signature null:
   - Delete from Firebase Storage
   - Clear `signatureFirebaseUrl`
   - Clear `needsSignatureSync` flag

#### Sync Triggers
- Background sync on network reconnect
- On app foreground
- Manual sync button
- After signature save/delete

### Error Handling

#### Storage Errors
- **Disk Full**: Show "Not enough storage space" message
- **Write Failed**: Show "Failed to save signature" with retry

#### Drawing Errors
- **Canvas Not Ready**: Wait for initialization
- **Touch Events Lost**: Continue with partial signature

### Implementation Classes

#### SignatureCaptureScreen
```dart
class SignatureCaptureScreen extends StatefulWidget {
  final String userId;
  
  // Returns the saved signature path or null if cancelled
  static Future<String?> show(BuildContext context, String userId);
}
```

#### SignaturePainter
```dart
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  
  // Handles drawing logic
  void paint(Canvas canvas, Size size);
}
```

#### Integration with ProfileScreen
- Signature section in form shows preview or placeholder
- Tap to open SignatureCaptureScreen
- On return, update UI and database
- Handle deletion with confirmation

### Testing Requirements

#### Unit Tests
- Signature cropping algorithm
- File path generation
- Database updates

#### Widget Tests
- Drawing interaction
- Button states
- Navigation flow

#### Integration Tests
- Full capture flow
- Save and display
- Delete with confirmation
- Sync behavior

### Performance Considerations
- Keep stroke points in memory during drawing
- Convert to image only on save
- Dispose of canvas resources properly
- Clear image cache after deletion

### Accessibility
- Minimum touch target: 44x44 points
- Clear button labels
- Confirmation dialogs for destructive actions

### Future Enhancements (Not in Current Scope)
- Undo/Redo functionality
- Multiple pen widths
- Color options
- SVG format for scalability
- Signature templates

## Implementation Priority
1. Create SignatureCaptureScreen widget
2. Implement drawing canvas with CustomPainter
3. Add save/cancel functionality
4. Integrate with ProfileScreen
5. Add deletion with confirmation
6. Test offline behavior
7. Verify sync functionality

## Definition of Done
- [ ] Drawing works smoothly on all devices
- [ ] Signature saves to local storage
- [ ] Database updates correctly
- [ ] Preview shows in profile form
- [ ] Deletion works with confirmation
- [ ] Sync flags set appropriately
- [ ] Works completely offline
- [ ] Tests pass (unit, widget, integration)
- [ ] Manual testing completed
- [ ] Documentation updated