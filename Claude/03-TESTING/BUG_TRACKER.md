# Bug Tracker
**Last Updated**: 2025-08-29
**Total Bugs**: 21 (0 Critical, 4 High, 14 Low)

---

## 🔴 Critical Bugs (0)
*None currently*

---

## 🟡 High Priority Bugs (4)

### Bug #001
**Severity**: High
**Module**: Profile/Sync
**Description**: Firebase unit tests failing due to missing initialization
**Steps to Reproduce**: 
1. Run `flutter test test/unit/services/sync/`
2. Tests fail with "No Firebase App" error
**Expected**: Tests should run with mocked Firebase
**Actual**: Tests fail due to Firebase.initializeApp() not called
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Created firebase_test_helper.dart with proper mock initialization
**Fixed in**: 2025-01-12

### Bug #002  
**Severity**: High
**Module**: Profile/Images
**Description**: Large images (>5MB) cause app to freeze
**Steps to Reproduce**:
1. Select a high-res photo from gallery
2. App freezes for 3-5 seconds
**Expected**: Smooth image selection with progress indicator
**Actual**: UI freezes during compression
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Created ImageCompressionService using isolates for background processing
**Fixed in**: 2025-01-12

### Bug #003
**Severity**: High
**Module**: Profile/Sync
**Description**: Sync status indicator not updating in real-time
**Steps to Reproduce**:
1. Make profile changes
2. Trigger sync
3. Status indicator doesn't update
**Expected**: Real-time status updates
**Actual**: Status stays on "pending"
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Updated SyncStatusIndicator to immediately update UI state, added initial status broadcast
**Fixed in**: 2025-01-12

### Bug #016
**Severity**: High
**Module**: Profile/Colleagues
**Description**: Colleagues being overwritten in Firebase instead of appended
**Steps to Reproduce**:
1. Add a colleague and save
2. Add another colleague and save
3. Check Firebase - only the second colleague is present
**Expected**: Both colleagues should be in Firebase as an array
**Actual**: Only the most recent colleague is saved, previous ones are lost
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Fixed reference sharing bug - _colleagues list was sharing reference with _currentUser.listOfALLColleagues
**Fixed in**: 2025-08-21

### Bug #017
**Severity**: High  
**Module**: Profile/Colleagues
**Description**: Colleagues not downloaded after app reinstall (copyWith bug)
**Steps to Reproduce**:
1. Add colleagues to profile
2. Reinstall app
3. Login again
4. Colleagues are not shown despite being in Firebase
**Expected**: Colleagues should be downloaded and displayed
**Actual**: Colleagues are downloaded from Firebase but lost when copyWith is called
**Status**: Fixed ✅
**Fix**: Added `listOfALLColleagues: this.listOfALLColleagues` to copyWith method in AppUser
**Fixed in**: 2025-08-21

### Bug #018
**Severity**: High
**Module**: Profile/Colleagues  
**Description**: Colleague changes not detected, preventing sync to Firebase
**Steps to Reproduce**:
1. Load profile with existing colleague
2. Add a new colleague
3. Press Save
4. Check logs - "Colleagues changed: false"
5. Firebase is not updated with new colleague
**Expected**: Colleague changes should be detected and trigger sync
**Actual**: _hasColleaguesChanged() returns false even when colleagues are added
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Used List<Colleague>.from() to create a copy instead of sharing reference
**Fixed in**: 2025-08-21

---

## 🟢 Low Priority Bugs (12)

### Bug #004
**Severity**: Low
**Module**: Profile/UI
**Description**: Keyboard covers input fields on small screens
**Status**: Open

### Bug #005
**Severity**: Low
**Module**: Profile/Validation
**Description**: Phone number validation too strict for international numbers
**Status**: Open

### Bug #006
**Severity**: Low
**Module**: Profile/UI
**Description**: Date format dropdown not saving preference
**Status**: Open

### Bug #007
**Severity**: Low  
**Module**: Profile/Images
**Description**: Image rotation incorrect on some Android devices
**Status**: Open

### Bug #008
**Severity**: Low
**Module**: Profile/Signature
**Description**: Signature pad too small on tablets
**Status**: Open

### Bug #009
**Severity**: Low
**Module**: Tests
**Description**: Import paths inconsistent (Data vs data)
**Status**: Fixed ✅
**Fixed in**: Commit #abc123

### Bug #010
**Severity**: Low
**Module**: Profile/UI
**Description**: Success message disappears too quickly
**Status**: Open

### Bug #011
**Severity**: Low
**Module**: Profile/Sync
**Description**: Retry count not incrementing properly
**Status**: Open

### Bug #012
**Severity**: Low
**Module**: Documentation
**Description**: Some README files outdated
**Status**: Open

### Bug #013
**Severity**: Low
**Module**: Profile/UI
**Description**: Profile image placeholder not centered
**Status**: Open

### Bug #014
**Severity**: Low
**Module**: Tests
**Description**: Some test files missing proper tearDown
**Status**: Open

### Bug #015
**Severity**: Low
**Module**: Profile/Database
**Description**: Migration strategy not tested
**Status**: Open

### Bug #019
**Severity**: High
**Module**: Profile/Sync
**Description**: Sync operation blocks UI when saving profile changes
**Steps to Reproduce**:
1. Edit any profile field (name, email, etc.)
2. Press Save button
3. UI shows blocking "Syncing..." dialog
4. User cannot interact with app until sync completes or fails
**Expected**: Save should be instant with background sync
**Actual**: User has to wait for sync operation to complete
**Impact**: Poor UX, especially on slow connections
**Status**: Fixed ✅
**Assigned**: Development Team
**Notes**: Violates offline-first principle - local save should be instant
**Fix**: Implemented fire-and-forget architecture - removed all sync calls from profile screen, sync now happens in background from MainMenu
**Fixed in**: 2025-08-21

### Bug #020
**Severity**: Low
**Module**: Site/UI
**Description**: Missing info icons on form fields in Site creation screen
**Steps to Reproduce**:
1. Navigate to Create Site screen
2. Observe form fields
3. No info icons present to explain field purposes
**Expected**: All form fields should have info icons with help text
**Actual**: Fields missing info icons
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Added info icons with dismissible popup dialogs to all form fields (Company Name, Site Name, Location, Contact Person, Contact Phone, Expected Completion). Popups can be dismissed by tapping outside or using the "Got it" button
**Fixed in**: 2025-08-29

### Bug #021
**Severity**: Low
**Module**: Site/UI
**Description**: "Add more colleagues" button navigates directly to Profile without warning
**Steps to Reproduce**:
1. Navigate to Create Site screen
2. Scroll to colleagues section
3. Click "Add more colleagues"
4. User is taken to Profile screen unexpectedly
**Expected**: User should be warned about navigation and potential data loss
**Actual**: Direct navigation to Profile without explanation
**Status**: Fixed ✅
**Assigned**: Development Team
**Fix**: Added confirmation dialog explaining that colleagues are managed in Profile settings and asking for confirmation before navigating
**Fixed in**: 2025-08-29

---

## 📊 Bug Statistics

### By Module
- Profile UI: 5 bugs
- Site UI: 2 bugs
- Sync Service: 3 bugs
- Images: 2 bugs
- Database: 1 bug
- Tests: 3 bugs
- Other: 1 bug

### By Status
- Open: 11
- In Progress: 0
- Fixed: 10
- Verified: 0

### Trend
- New this week: 0
- Fixed this week: 4
- Days since critical bug: 7

---

## 🔄 Process

### Bug Lifecycle
1. **Open** → Bug reported
2. **In Progress** → Developer assigned and working
3. **Fixed** → Code fix complete
4. **Verified** → QA confirmed fix works
5. **Closed** → Released to production

### Priority Levels
- **Critical**: App crashes, data loss, security issue (Fix immediately)
- **High**: Major feature broken (Fix within 24 hours)
- **Medium**: Feature partially broken (Fix within week)
- **Low**: Minor issue, cosmetic (Fix when convenient)

---

## 📝 Report a New Bug

Template:
```
### Bug #XXX
**Severity**: Critical/High/Medium/Low
**Module**: Profile/Snag/etc
**Description**: What's wrong
**Steps to Reproduce**: 
1. Step one
2. Step two
**Expected**: What should happen
**Actual**: What actually happens
**Status**: Open
**Assigned**: Who will fix
**Fix**: Proposed solution
```