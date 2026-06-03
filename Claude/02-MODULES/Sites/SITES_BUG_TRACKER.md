# Sites Module Bug Tracker
**Last Updated**: 2026-06-03
**Module Status**: In Development (70% infrastructure, UI migration pending)
**Total Bugs**: 2 Open, 0 Fixed
**Total TODOs**: 5

---

## Bug Numbering
Sites bugs use prefix `SITE-XXX` to distinguish from other modules.

---

## Critical Bugs (0)
*None currently*

---

## High Priority Bugs (0)
*None currently*

---

## Medium Priority Bugs (2)

### SITE-001
**Severity**: Medium
**Component**: Architecture
**Description**: Dual model inconsistency - old `Site` model vs new `Site` model
**Details**:
- Old model: `lib/Data/site.dart` (simple, used by UI/ContentProvider)
- New model: `lib/Data/models/site.dart` (comprehensive, PRD-compliant)
**Impact**:
- UI uses old model properties (site.image, site.location, site.uID)
- SiteService uses new model
- Data inconsistency risk during create/update operations
**Status**: Open
**Priority**: Medium (blocking full migration)
**Proposed Fix**:
1. Migrate siteInfo.dart to use new Site model exclusively
2. Update ContentProvider site methods to use SiteDao
3. Remove old Site model after migration complete

### SITE-002
**Severity**: Medium
**Component**: Architecture
**Description**: ContentProvider bypasses offline-first architecture for Sites
**Details**:
- `CP.addSite()` writes directly to Firebase
- `CP.loadOwnedSites()` reads directly from Firebase
- `CP.updateSite()` writes directly to Firebase
- Violates offline-first requirement
**Impact**: Site operations fail without internet connection
**Status**: Open
**Priority**: Medium (core architecture issue)
**Proposed Fix**:
1. Update CP site methods to use SiteDao (like profile was migrated)
2. Create SiteSyncHandler for Firebase sync
3. Make Firebase operations background-only

---

## Low Priority Bugs (0)
*None currently*

---

## TODOs & Technical Debt

### SITE-TODO-001
**Type**: Missing Implementation
**Component**: Sync
**Description**: SiteSyncHandler not implemented
**Details**: Sites have sync flags (needsSiteSync, needsImageSync, needsSnagsSync) but no handler to process them
**Required**: Create SiteSyncHandler following ProfileSyncHandler pattern
**Status**: Pending
**Priority**: High (required for offline-first)

### SITE-TODO-002
**Type**: Incomplete Migration
**Component**: UI
**Description**: siteInfo.dart partially migrated to new architecture
**Details**:
- Create new site: Uses SiteService (correct)
- Update existing site: Uses old Site model + ContentProvider (incorrect)
- Load site: Uses old Site model properties
**Required**: Complete migration to use new Site model and SiteService for all operations
**Status**: Pending
**Priority**: High

### SITE-TODO-003
**Type**: Missing Fields
**Component**: UI/Model
**Description**: Old Site model missing fields that new model has
**Details**: Old model lacks: contactPerson, contactPhone, expectedCompletion, snagCategories, deletion management, update tracking
**Impact**: UI can't display/edit these fields when using old model
**Required**: Either add fields to old model or complete migration to new model
**Status**: Pending
**Priority**: Medium

### SITE-TODO-004
**Type**: Missing Feature
**Component**: UI
**Description**: Site list has no search/filter capability
**Details**: ownedSites.dart and sharedSites.dart show all sites without filtering
**Required**: Add search bar and filter options (by name, date, status)
**Status**: Pending
**Priority**: Low

### SITE-TODO-005
**Type**: Missing Feature
**Component**: Permissions
**Description**: Site sharing permissions not enforced in UI
**Details**: FIXER/CONTRIBUTOR/VIEW permissions defined in model but UI doesn't enforce restrictions
**Required**: Implement permission-based UI visibility and edit controls
**Status**: Pending
**Priority**: Medium

---

## Recently Fixed Bugs

### SITE-FIXED-001 (was Bug #020 in main tracker)
**Severity**: Low
**Component**: UI
**Description**: Missing info icons on form fields in Site creation screen
**Fix**: Created InfoTextField widget and replaced all form fields
**Fixed in**: 2026-06-03 (this session)

---

## Known Issues from Code Review

### Issue 1: Image Path Handling
**File**: `siteInfo.dart`
**Line**: ~660
**Description**: `_loadValuesFromSite` uses `site.image` (old model) which may be base64 or file path
**Risk**: Inconsistent image display depending on data source

### Issue 2: Date Field Not Editable
**File**: `siteInfo.dart`
**Description**: Site creation date is auto-set but not exposed in UI for editing
**Note**: PRD says date is "Auto-set, not UI visible" - may be intentional

### Issue 3: Archive Feature UI
**File**: Various
**Description**: Archive functionality exists in model but no UI to archive/unarchive sites from list view
**Required**: Add archive toggle to site options menu

---

## Test Coverage Status

| Component | Unit Tests | Integration Tests | Manual Tests |
|-----------|------------|-------------------|--------------|
| Site Model (new) | Partial | None | None |
| Site Model (old) | None | None | None |
| SiteDao | Yes | None | None |
| SiteService | Partial | None | None |
| siteInfo.dart | None | None | None |
| mySites.dart | None | None | None |

**Priority**: Need integration tests for site creation flow before consolidation

---

## Migration Checklist

Before marking Sites module as "architecture complete":

- [ ] Remove dependency on old Site model (`lib/Data/site.dart`)
- [ ] Update ContentProvider to use SiteDao internally
- [ ] Implement SiteSyncHandler
- [ ] All UI screens use new Site model
- [ ] Permissions enforced in UI
- [ ] Integration tests passing
- [ ] Manual testing: Create, Edit, Delete, Archive, Share
- [ ] Manual testing: Offline mode operations
- [ ] Manual testing: Sync after reconnection

---

## Report a New Bug

Template:
```markdown
### SITE-XXX
**Severity**: Critical/High/Medium/Low
**Component**: UI/Model/Service/Sync/Database
**Description**: What's wrong
**Steps to Reproduce**:
1. Step one
2. Step two
**Expected**: What should happen
**Actual**: What actually happens
**Status**: Open
**Assigned**: Who will fix
**Proposed Fix**: Solution approach
```

---

## Change Log

| Date | Change |
|------|--------|
| 2026-06-03 | Created Sites bug tracker, migrated relevant bugs from main tracker |
| 2026-06-03 | Fixed SITE-FIXED-001 (info icons on form fields) |
| 2026-06-03 | Added reportTitle field to Site models |
