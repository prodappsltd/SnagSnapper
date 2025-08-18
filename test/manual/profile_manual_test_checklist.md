# Profile Module - Manual Testing Checklist
**Date**: 2025-01-12
**Tester**: _________________
**Device**: _________________
**OS Version**: _________________

---

## 📱 Test Environment Setup

- [ ] Fresh app install
- [ ] No existing user data
- [ ] Device has internet connection
- [ ] Firebase backend is accessible

---

## ✅ Test Scenarios

### 1. New User Profile Creation

#### 1.1 Basic Profile Creation
- [ ] Launch app for first time
- [ ] Navigate to profile setup
- [ ] Enter name: "Test User"
- [ ] Enter email: "test@example.com"
- [ ] Enter company: "Test Company"
- [ ] Select role: "Inspector"
- [ ] Enter phone: "+1234567890"
- [ ] Select date format: "dd-MM-yyyy"
- [ ] Tap Save
- [ ] **Expected**: Profile saved successfully message
- [ ] **Expected**: Navigation to main screen
- [ ] **Pass/Fail**: _______

#### 1.2 Profile Image Addition
- [ ] Tap on profile image placeholder
- [ ] Select "Take Photo" or "Choose from Gallery"
- [ ] Select/capture an image
- [ ] **Expected**: "Processing image..." message appears
- [ ] **Expected**: Image appears in profile
- [ ] **Expected**: No UI freezing during compression
- [ ] **Pass/Fail**: _______

#### 1.3 Signature Addition
- [ ] Tap on signature area
- [ ] Draw signature
- [ ] Tap "Save"
- [ ] **Expected**: Signature saved and displayed
- [ ] **Pass/Fail**: _______

### 2. Offline Functionality

#### 2.1 Airplane Mode Test
- [ ] Enable airplane mode
- [ ] Edit profile name
- [ ] Add/change profile image
- [ ] Save changes
- [ ] **Expected**: All changes save locally
- [ ] **Expected**: Sync status shows "pending sync"
- [ ] **Pass/Fail**: _______

#### 2.2 App Restart in Offline Mode
- [ ] Keep airplane mode enabled
- [ ] Force close app
- [ ] Reopen app
- [ ] **Expected**: All profile data persists
- [ ] **Expected**: Profile image and signature display correctly
- [ ] **Pass/Fail**: _______

### 3. Sync Functionality

#### 3.1 Manual Sync Trigger
- [ ] Disable airplane mode
- [ ] Tap sync button
- [ ] **Expected**: Sync animation starts immediately
- [ ] **Expected**: "Syncing..." status displays
- [ ] **Expected**: "Sync completed" message
- [ ] **Expected**: Sync status changes to "synced"
- [ ] **Pass/Fail**: _______

#### 3.2 Auto-Sync on Network Recovery
- [ ] Make changes in offline mode
- [ ] Re-enable internet connection
- [ ] Wait 5 seconds
- [ ] **Expected**: Auto-sync triggers
- [ ] **Expected**: Changes upload to Firebase
- [ ] **Pass/Fail**: _______

### 4. Profile Editing

#### 4.1 Edit All Fields
- [ ] Navigate to profile screen
- [ ] Edit each field:
  - [ ] Name
  - [ ] Email
  - [ ] Company
  - [ ] Role
  - [ ] Phone
  - [ ] Date format
- [ ] Save changes
- [ ] **Expected**: All changes persist
- [ ] **Expected**: needsProfileSync flag set
- [ ] **Pass/Fail**: _______

#### 4.2 Replace Profile Image
- [ ] Select existing profile with image
- [ ] Tap profile image
- [ ] Select new image
- [ ] **Expected**: Old image replaced
- [ ] **Expected**: No duplicate images in storage
- [ ] **Pass/Fail**: _______

### 5. Performance Tests

#### 5.1 Large Image Handling
- [ ] Select image >5MB
- [ ] **Expected**: Image processes without freezing UI
- [ ] **Expected**: Progress indicator shows during processing
- [ ] **Expected**: Compressed image saves successfully
- [ ] **Time taken**: _______ seconds
- [ ] **Pass/Fail**: _______

#### 5.2 Rapid Field Updates
- [ ] Quickly edit multiple fields
- [ ] Save after each edit
- [ ] **Expected**: No lag or freezing
- [ ] **Expected**: All changes saved
- [ ] **Pass/Fail**: _______

### 6. Error Handling

#### 6.1 Invalid Input
- [ ] Try to save with empty name
- [ ] **Expected**: Validation error message
- [ ] Try invalid email format
- [ ] **Expected**: Email validation error
- [ ] **Pass/Fail**: _______

#### 6.2 Network Error During Sync
- [ ] Start sync
- [ ] Quickly enable airplane mode
- [ ] **Expected**: Sync fails gracefully
- [ ] **Expected**: Error message displayed
- [ ] **Expected**: Data remains in local database
- [ ] **Pass/Fail**: _______

### 7. Edge Cases

#### 7.1 Multiple Rapid Syncs
- [ ] Tap sync button multiple times quickly
- [ ] **Expected**: Only one sync executes
- [ ] **Expected**: No duplicate uploads
- [ ] **Pass/Fail**: _______

#### 7.2 Background App State
- [ ] Make changes
- [ ] Background the app
- [ ] Wait 30 seconds
- [ ] Restore app
- [ ] **Expected**: All data intact
- [ ] **Expected**: Sync resumes if needed
- [ ] **Pass/Fail**: _______

### 8. UI/UX Validation

#### 8.1 Visual Consistency
- [ ] All buttons responsive to taps
- [ ] Loading indicators display properly
- [ ] Success/error messages clear
- [ ] No UI elements overlapping
- [ ] **Pass/Fail**: _______

#### 8.2 Accessibility
- [ ] Text readable at different font sizes
- [ ] Touch targets adequate size
- [ ] Error messages descriptive
- [ ] **Pass/Fail**: _______

---

## 📊 Test Summary

**Total Tests**: 30
**Passed**: _______
**Failed**: _______
**Pass Rate**: _______%

## 🐛 Issues Found

1. _________________________________
2. _________________________________
3. _________________________________
4. _________________________________
5. _________________________________

## 📝 Notes

_________________________________
_________________________________
_________________________________
_________________________________

## ✍️ Sign-off

**Tester Signature**: _________________
**Date**: _________________
**Approved for Production**: [ ] Yes [ ] No

---

## 🔄 Retest Required

If any tests failed, list items to retest after fixes:

1. _________________________________
2. _________________________________
3. _________________________________