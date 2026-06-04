# Bug Tracker (Main)
**Last Updated**: 2026-06-03

---

## Module-Specific Bug Trackers

Bug tracking is now organized by module for better management:

| Module | Status | Bug Tracker Location |
|--------|--------|---------------------|
| **Profile** | Complete | `Claude/02-MODULES/Profile/PROFILE_BUG_TRACKER.md` |
| **Sites** | In Development | `Claude/02-MODULES/Sites/SITES_BUG_TRACKER.md` |
| **Snags** | Not Started | TBD |

This file now tracks only:
- Cross-module bugs
- Settings/Infrastructure bugs
- TODOs and placeholders

---

## Summary Statistics
**Cross-Module Bugs**: 0 Critical, 0 High, 5 Low Open
**Settings TODOs**: 11 pending
**Infrastructure TODOs**: 2 pending

---

## 🔴 Critical Bugs (0)
*None currently*

---

## 🟡 High Priority Bugs (0 - All Moved to Module Trackers)

*All high-priority module bugs moved to:*
- Profile bugs: `Claude/02-MODULES/Profile/PROFILE_BUG_TRACKER.md`
- Site bugs: `Claude/02-MODULES/Sites/SITES_BUG_TRACKER.md`

---

## 🟢 Low Priority Cross-Module Bugs (5 Open, 1 Fixed)

### Bug #009
**Severity**: Low
**Module**: Tests
**Description**: Import paths inconsistent (Data vs data)
**Status**: Fixed
**Fixed in**: Commit #abc123

### Bug #010
**Severity**: Low
**Module**: General/UI
**Description**: Success message disappears too quickly
**Status**: Open
**Note**: Affects multiple modules - Flushbar duration may need adjustment app-wide

### Bug #011
**Severity**: Low
**Module**: Sync/Infrastructure
**Description**: Retry count not incrementing properly
**Status**: Open

### Bug #012
**Severity**: Low
**Module**: Documentation
**Description**: Some README files outdated
**Status**: Open

### Bug #014
**Severity**: Low
**Module**: Tests
**Description**: Some test files missing proper tearDown
**Status**: Open

### Bug #015
**Severity**: Low
**Module**: Database/Infrastructure
**Description**: Migration strategy not tested
**Status**: Open

---

## 🟠 TODOs & Placeholders (Settings & Infrastructure)

### TODO #001
**Type**: Placeholder
**Module**: Settings/moreOptions
**File**: `lib/Screens/moreOptions.dart:295-301`
**Description**: Privacy Policy - Shows "TODO: Privacy Policy" snackbar instead of actual content
**Required**: Add actual Privacy Policy URL or in-app content
**Status**: Pending
**Priority**: Low

### TODO #002
**Type**: Placeholder
**Module**: Settings/moreOptions
**File**: `lib/Screens/moreOptions.dart:313-320`
**Description**: Terms of Service - Shows "TODO: Terms of Service" snackbar instead of actual content
**Required**: Add actual Terms of Service URL or in-app content
**Status**: Pending
**Priority**: Low

### TODO #003
**Type**: Placeholder
**Module**: Settings/moreOptions
**File**: `lib/Screens/moreOptions.dart:661-667`
**Description**: Share iOS - Shows "TODO: Share iOS App Store link" snackbar
**Required**: Add actual App Store link when app is published
**Status**: Pending
**Priority**: Low

### TODO #004
**Type**: Placeholder
**Module**: Settings/moreOptions
**File**: `lib/Screens/moreOptions.dart:676-682`
**Description**: Share Android - Shows "TODO: Share Play Store link" snackbar
**Required**: Add actual Play Store link when app is published
**Status**: Pending
**Priority**: Low

### TODO #005
**Type**: Incomplete Implementation
**Module**: Settings/SyncSettings
**File**: `lib/Screens/settings/sync_settings_screen.dart:147-148`
**Description**: `_clearSyncQueue()` only clears SharedPreferences key, doesn't clear actual database queue via SyncQueueManager
**Required**: Implement proper queue clearing through SyncQueueManager
**Status**: Pending
**Priority**: Medium

### TODO #006
**Type**: Not Implemented
**Module**: Settings/SyncSettings
**File**: `lib/Screens/settings/sync_settings_screen.dart:437-439`
**Description**: Error "Details" button has empty `onPressed: () {}` handler - does nothing when tapped
**Required**: Implement error details dialog showing sync error history
**Status**: Pending
**Priority**: Low

### TODO #007
**Type**: Orphaned Screen
**Module**: Settings/SyncSettings
**File**: `lib/Screens/settings/sync_settings_screen.dart`
**Description**: SyncSettingsScreen exists but has no navigation route - cannot be accessed by users
**Required**: Add navigation from moreOptions.dart or main settings
**Status**: Pending
**Priority**: Medium

### TODO #008
**Type**: Stub Implementation
**Module**: Services/BackgroundSync
**File**: `lib/services/background_sync_service.dart:119-127`
**Description**: `_checkBatteryLevel()` always returns true - battery check not implemented
**Required**: Implement actual battery level check using battery_plus package
**Status**: Pending
**Priority**: Low

### TODO #009
**Type**: Stub Implementation
**Module**: Services/BackgroundSync
**File**: `lib/services/background_sync_service.dart:129-138`
**Description**: `_checkStorageSpace()` always returns true - storage check not implemented
**Required**: Implement actual storage space check using disk_space package
**Status**: Pending
**Priority**: Low

### TODO #010
**Type**: Missing Feature
**Module**: Settings
**Description**: Data Management screen not implemented (per ROADMAP.md Module 6)
**Required**: Create data management screen with clear cache, export data options
**Status**: Planned
**Priority**: Medium

### TODO #011
**Type**: Missing Feature
**Module**: Settings
**Description**: Backup/Restore functionality not implemented (per ROADMAP.md Module 6)
**Required**: Implement backup to cloud and restore from cloud features
**Status**: Planned
**Priority**: Medium

### TODO #012
**Type**: Orphaned Component
**Module**: Infrastructure/Sync
**File**: `lib/Screens/profile/components/sync_status_indicator.dart`
**Description**: SyncStatusIndicator widget exists but is NOT integrated anywhere
**Required**: Consider integrating into MainMenu AppBar for visibility
**Status**: Pending
**Priority**: Low
**Note**: May be useful as general "sync all" indicator in MainMenu/Settings

---

## 📊 Statistics Summary

### Cross-Module Bugs
- Open: 5 Low priority
- Fixed: 1

### TODOs by Category
- Settings Placeholders: 4 (Privacy, Terms, App Store links)
- Settings Features: 4 (Sync settings, data management, backup)
- Infrastructure: 3 (Battery check, storage check, sync indicator)

### Module Bug Trackers
| Module | Location | Open Bugs | Fixed Bugs |
|--------|----------|-----------|------------|
| Profile | `02-MODULES/Profile/PROFILE_BUG_TRACKER.md` | 6 Low | 8 (7 High, 1 Low) |
| Sites | `02-MODULES/Sites/SITES_BUG_TRACKER.md` | 2 Medium | 1 |
| Snags | TBD | - | - |

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

### Bug Numbering Convention
- Cross-module: `Bug #XXX`
- Profile: `PROF-XXX`
- Sites: `SITE-XXX`
- Snags: `SNAG-XXX` (future)

---

## 📝 Report a New Bug

For module-specific bugs, use the module's bug tracker.

For cross-module bugs, use this template:
```
### Bug #XXX
**Severity**: Critical/High/Medium/Low
**Module**: Infrastructure/Settings/Tests/etc
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