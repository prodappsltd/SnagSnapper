# Image Validation Specification
**Module**: Profile  
**Date**: 2025-01-14  
**Status**: Approved for Implementation

## Overview
Two-tier image validation system ensuring optimal file sizes while maintaining fixed dimensions for consistent UI display.

## Requirements

### Dimension Constraints
- **Fixed Size**: 1024 × 1024 pixels (non-negotiable)
- **Purpose**: Ensures consistent display across all devices
- **Format**: JPEG (all images converted to JPEG)

### File Size Constraints (Two-Tier System)
1. **Optimal Target**: < 600KB (preferred)
2. **Maximum Acceptable**: < 1MB (fallback)
3. **Rejection Threshold**: > 1MB at minimum quality

## Implementation Strategy

### Compression Algorithm
```
START with image file
RESIZE to 1024×1024 pixels
SET quality = 85%

WHILE quality >= 30%:
    COMPRESS image at current quality
    
    IF file_size <= 600KB:
        RETURN (image, "optimal")
    
    IF quality == 30% AND file_size <= 1MB:
        RETURN (image, "acceptable")
    
    REDUCE quality by 10%

IF file_size > 1MB:
    REJECT image as "too complex"
```

### Quality Levels
- **85%**: Starting point (high quality)
- **75%**: Slight compression visible
- **65%**: Moderate compression
- **55%**: Noticeable compression
- **45%**: Heavy compression
- **35%**: Maximum acceptable compression
- **30%**: Minimum quality threshold

## User Experience

### Feedback Messages
1. **Optimal** (≤600KB):
   - Message: "✅ Image optimized successfully (XXXkB)"
   - Color: Green
   
2. **Acceptable** (600KB-1MB):
   - Message: "⚠️ Image compressed to XXXkB (larger than optimal)"
   - Color: Orange
   
3. **Rejected** (>1MB):
   - Message: "❌ Image too complex. Please choose a simpler image"
   - Color: Red

## Integration Points

### Profile Setup Screen
- Called when user selects profile image
- Shows immediate feedback via SnackBar
- Saves to local storage after validation

### Profile Edit Screen
- Same validation when updating image
- Replaces existing image only if valid

### Future Modules
- Site images will use same validation
- Snag photos will use same validation
- Signature images use same approach (smaller limits)

## Testing Requirements

### Test Cases
1. **Simple Image** (logo, few colors)
   - Expected: < 600KB at 85% quality
   - Result: Optimal

2. **Normal Photo** (typical camera photo)
   - Expected: 400-600KB with some compression
   - Result: Optimal

3. **Complex Photo** (detailed construction site)
   - Expected: 600-900KB at 30% quality
   - Result: Acceptable

4. **Extremely Complex** (ultra-high detail)
   - Expected: > 1MB even at 30%
   - Result: Rejected

### Validation Tests
- Verify dimension is always 1024×1024
- Verify file size limits are enforced
- Verify quality never goes below 30%
- Verify user feedback is appropriate

## Performance Considerations

### Processing Time
- Target: < 2 seconds for average image
- Maximum: < 5 seconds for complex images

### Memory Usage
- Keep only one version in memory at a time
- Release original after processing
- Clear cache after saving

## Storage Impact

### Firebase Storage
- Optimal scenario: ~1,700 images per GB
- Realistic scenario: ~1,400 images per GB
- Worst case: ~1,000 images per GB

### Local Storage
- Same as Firebase (identical files)
- Implement cleanup for old images

## Implementation Checklist

- [ ] Create ImageCompressionService class
- [ ] Add two-tier validation logic
- [ ] Implement in ProfileSetupScreen
- [ ] Implement in Profile edit screen
- [ ] Add user feedback (SnackBar)
- [ ] Write unit tests
- [ ] Test with various image types
- [ ] Update documentation
- [ ] Performance testing
- [ ] Memory leak testing

## Notes
- This approach balances quality, file size, and user experience
- Two-tier system prevents unnecessary rejections
- Fixed dimensions ensure UI consistency
- Compression is automatic and transparent to user

---
**Approved By**: Development Team  
**Implementation Priority**: High  
**Estimated Effort**: 4 hours