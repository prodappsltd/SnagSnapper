# Manual Testing Checklist - Profile Module
**Date**: 2025-01-14  
**Version**: 1.0  
**Status**: Ready for Testing

## 🎯 Testing Goals
Verify that the Profile module works correctly with:
1. Offline-first architecture
2. Two-tier image validation
3. Device management
4. Background sync
5. User experience flows

---

## ✅ Test Cases

### 1. First-Time User Setup (Online)
- [ ] Launch app fresh install
- [ ] Complete signup/signin
- [ ] Fill profile form with all fields
- [ ] Save profile
- [ ] **Verify**: Profile saves instantly
- [ ] **Verify**: Navigation to main menu works
- [ ] **Verify**: Check Firebase Console - profile should be synced
- [ ] **Verify**: Device ID registered in Realtime Database

### 2. First-Time User Setup (Offline)
- [ ] Turn on Airplane Mode
- [ ] Launch app fresh install
- [ ] Complete signup/signin
- [ ] Fill profile form
- [ ] Save profile
- [ ] **Verify**: Profile saves locally
- [ ] **Verify**: App continues to main menu
- [ ] Turn off Airplane Mode
- [ ] **Verify**: Profile syncs automatically to Firebase
- [ ] **Verify**: Sync indicators appear/disappear

### 3. Profile Image Upload - Optimal Size
- [ ] Go to Profile screen
- [ ] Tap image placeholder
- [ ] Select a simple image (logo/graphic)
- [ ] **Verify**: Green success message "✅ Image optimized successfully"
- [ ] **Verify**: Image displays immediately
- [ ] **Verify**: Image size shown is < 600KB
- [ ] Force close and reopen app
- [ ] **Verify**: Image still displays

### 4. Profile Image Upload - Acceptable Size
- [ ] Go to Profile screen
- [ ] Select a complex photo (detailed landscape)
- [ ] **Verify**: Orange warning "⚠️ Image compressed to XXXkB (larger than optimal)"
- [ ] **Verify**: Image still saves and displays
- [ ] **Verify**: Size is between 600KB-1MB
- [ ] **Verify**: Image quality acceptable

### 5. Profile Image Upload - Rejection Test
- [ ] Create/find extremely complex image
- [ ] Try to upload
- [ ] **Verify**: Red error "❌ Image too complex"
- [ ] **Verify**: Image not saved
- [ ] **Verify**: Previous image (if any) unchanged

### 6. Profile Edit (Online)
- [ ] Edit name field
- [ ] Edit job title
- [ ] Edit company name
- [ ] Save changes
- [ ] **Verify**: Changes save instantly
- [ ] **Verify**: No loading delays
- [ ] Check Firebase Console
- [ ] **Verify**: Changes reflected in Firebase

### 7. Profile Edit (Offline)
- [ ] Turn on Airplane Mode
- [ ] Edit multiple fields
- [ ] Save changes
- [ ] **Verify**: Changes save locally
- [ ] **Verify**: Sync indicator shows
- [ ] Turn off Airplane Mode
- [ ] **Verify**: Auto-sync occurs
- [ ] **Verify**: Firebase updated

### 8. Device Switch Warning
- [ ] Login on Device A
- [ ] Note the profile data
- [ ] Login same account on Device B
- [ ] **Verify**: Warning dialog appears
- [ ] **Verify**: Dialog shows device info
- [ ] **Verify**: Lists consequences clearly
- [ ] Tap "Continue on This Device"
- [ ] **Verify**: Profile loads on Device B
- [ ] Check Device A
- [ ] **Verify**: Device A forced to logout

### 9. Device Switch Cancel
- [ ] Login on Device A
- [ ] Try login on Device B
- [ ] When warning appears, tap "Cancel"
- [ ] **Verify**: Returns to login screen
- [ ] **Verify**: Device A remains logged in
- [ ] **Verify**: No data changes

### 10. Image Dimension Verification
- [ ] Upload landscape image (3000x2000)
- [ ] **Verify**: Image resized to 1024x1024
- [ ] Upload portrait image (2000x3000)
- [ ] **Verify**: Image resized to 1024x1024
- [ ] Upload small image (500x500)
- [ ] **Verify**: Image upscaled to 1024x1024

### 11. Sync Service Testing
- [ ] Make profile changes offline
- [ ] **Verify**: needsProfileSync flag set (check logs)
- [ ] Go online
- [ ] **Verify**: Auto-sync triggers
- [ ] **Verify**: Sync completes successfully
- [ ] **Verify**: Flags cleared

### 12. Performance Testing
- [ ] Time profile save operation
- [ ] **Target**: < 100ms local save
- [ ] Time image processing
- [ ] **Target**: < 2 seconds for normal images
- [ ] Time sync operation
- [ ] **Target**: Non-blocking (UI responsive)

### 13. Error Recovery
- [ ] Interrupt sync (Airplane mode during sync)
- [ ] **Verify**: No data loss
- [ ] **Verify**: Retry occurs when online
- [ ] Force close during profile save
- [ ] **Verify**: Data integrity maintained

### 14. Cross-Platform Testing
- [ ] Test on iOS device
- [ ] Test on Android device
- [ ] **Verify**: Same behavior on both
- [ ] **Verify**: Images display correctly
- [ ] **Verify**: Paths work on both platforms

### 15. Memory/Storage Testing
- [ ] Upload multiple images
- [ ] Replace images several times
- [ ] **Verify**: Old images cleaned up
- [ ] **Verify**: No memory leaks
- [ ] Check device storage
- [ ] **Verify**: Reasonable space usage

---

## 📱 Device Test Matrix

| Test Case | iPhone 14 | iPhone SE | Pixel 6 | Samsung S21 | iPad |
|-----------|-----------|-----------|---------|-------------|------|
| Profile Setup | [ ] | [ ] | [ ] | [ ] | [ ] |
| Image Upload | [ ] | [ ] | [ ] | [ ] | [ ] |
| Offline Mode | [ ] | [ ] | [ ] | [ ] | [ ] |
| Device Switch | [ ] | [ ] | [ ] | [ ] | [ ] |
| Performance | [ ] | [ ] | [ ] | [ ] | [ ] |

---

## 🐛 Bug Report Template

**Bug #**: 
**Date**: 
**Device**: 
**OS Version**: 
**Test Case**: 
**Expected**: 
**Actual**: 
**Steps to Reproduce**:
1. 
2. 
3. 
**Screenshot/Video**: 
**Priority**: High/Medium/Low

---

## 📊 Test Summary

**Total Test Cases**: 15  
**Passed**: ___  
**Failed**: ___  
**Blocked**: ___  
**Pass Rate**: ___%

**Critical Issues Found**: 
1. 
2. 

**Non-Critical Issues**: 
1. 
2. 

---

## ✍️ Sign-off

**Tested By**: ________________  
**Date**: ________________  
**Approved By**: ________________  
**Ready for Production**: Yes [ ] No [ ]

---

## 📝 Notes
- Always test with realistic data
- Test both fast and slow network conditions
- Verify Firebase Console after online operations
- Check device logs for sync operations
- Test with various image types (PNG, JPEG, HEIC)
- Ensure no sensitive data in logs

---

**Next Module**: Site Creation (after Profile completion)