# Image Validation Test Plan
**Module**: Profile  
**Feature**: Two-Tier Image Validation  
**Date**: 2025-01-14

## Test Objectives
Verify that image validation correctly:
1. Enforces 1024×1024 dimension requirement
2. Optimizes images to < 600KB when possible
3. Accepts images up to 1MB as fallback
4. Rejects images > 1MB
5. Provides appropriate user feedback

## Test Data Preparation

### Create Test Images
1. **simple_logo.png** (100KB original)
   - Expected: < 600KB optimal
   
2. **normal_photo.jpg** (2MB original)
   - Expected: < 600KB with compression
   
3. **complex_photo.jpg** (5MB original)
   - Expected: 600KB-1MB acceptable
   
4. **ultra_complex.png** (10MB original)
   - Expected: Rejected (> 1MB)

## Unit Tests

### Test 1: Dimension Validation
```
TEST: Image resized to 1024×1024
INPUT: 2000×3000 image
VERIFY: Output is exactly 1024×1024 pixels
```

### Test 2: Optimal Compression
```
TEST: Simple image achieves optimal size
INPUT: Simple logo image
VERIFY: 
  - Size < 600KB
  - Message contains "✅"
  - Quality >= 30%
```

### Test 3: Acceptable Compression
```
TEST: Complex image falls back to acceptable
INPUT: Detailed construction photo
VERIFY:
  - Size between 600KB-1MB
  - Message contains "⚠️"
  - Quality = 30%
```

### Test 4: Image Rejection
```
TEST: Ultra-complex image rejected
INPUT: Extremely detailed image
VERIFY:
  - Exception thrown
  - Message contains "❌"
  - No file saved
```

### Test 5: Quality Stepping
```
TEST: Quality reduces correctly
INPUT: Image needing compression
VERIFY:
  - Quality starts at 85%
  - Reduces by 10% each iteration
  - Stops at 30% minimum
```

## Integration Tests

### Test 6: Profile Setup Flow
```
TEST: New user adds profile image
STEPS:
  1. Open ProfileSetupScreen
  2. Select image from gallery
  3. Verify compression applied
  4. Verify image saved locally
  5. Verify user feedback shown
```

### Test 7: Profile Edit Flow
```
TEST: User updates profile image
STEPS:
  1. Open Profile screen
  2. Replace existing image
  3. Verify old image replaced
  4. Verify new image validated
  5. Verify sync flag set
```

## Performance Tests

### Test 8: Processing Time
```
TEST: Compression completes quickly
VERIFY:
  - Simple image: < 1 second
  - Normal image: < 2 seconds
  - Complex image: < 5 seconds
```

### Test 9: Memory Usage
```
TEST: No memory leaks
VERIFY:
  - Original image released after processing
  - No accumulation over multiple compressions
  - Memory returns to baseline
```

## Edge Cases

### Test 10: Invalid Image
```
TEST: Corrupted file handled
INPUT: Corrupted image file
VERIFY: Appropriate error message
```

### Test 11: Unsupported Format
```
TEST: Non-image file rejected
INPUT: PDF or text file
VERIFY: Format error shown
```

### Test 12: Empty File
```
TEST: Empty file handled
INPUT: 0-byte file
VERIFY: Error message shown
```

## User Experience Tests

### Test 13: Feedback Messages
```
VERIFY each scenario shows correct:
  - Message text
  - SnackBar color
  - Icon (if applicable)
```

### Test 14: Loading State
```
VERIFY during compression:
  - Loading indicator shown
  - UI remains responsive
  - Can't trigger multiple compressions
```

## Regression Tests

### Test 15: Existing Features
```
VERIFY after implementation:
  - Profile save still works
  - Image display unchanged
  - Sync functionality intact
  - Firebase upload works
```

## Test Execution Checklist

### Unit Tests
- [ ] All compression logic tests pass
- [ ] Edge cases handled properly
- [ ] Error messages appropriate

### Integration Tests  
- [ ] Profile setup flow works
- [ ] Profile edit flow works
- [ ] Images display correctly

### Performance Tests
- [ ] Processing time acceptable
- [ ] No memory leaks
- [ ] App remains responsive

### User Acceptance
- [ ] Feedback messages clear
- [ ] Process feels smooth
- [ ] No unexpected rejections

## Success Criteria
- All tests pass
- No performance degradation
- User feedback is clear
- Images consistently 1024×1024
- File sizes within limits

---
**Test Owner**: QA Team  
**Execution Timeline**: Before implementation merge  
**Priority**: High