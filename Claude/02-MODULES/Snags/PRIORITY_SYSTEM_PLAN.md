# Priority System Implementation Plan

## Status: Phase 1 Complete (Data Layer)

## Requirements
- 5 priority levels with 4-character codes and descriptions
- User-customizable (code + description)
- Profile-specific (applies to all snags across all sites owned by user)
- Default values provided, user can modify
- Collaborators see site owner's priority definitions

## Default Priority Values

| Code | Description |
|------|-------------|
| OK   | There is no defect and no action is required |
| OBS  | Observation and no immediate action is required |
| CAT3 | Improvement is required |
| CAT2 | Potentially dangerous and remedial action should be taken soon |
| CAT1 | There is a significant risk to persons or property and immediate action is required! |

## Architecture Decision: Option A (Profile)

Store priorities in Profile (AppUser model) as JSON array. Simple, works offline-first, syncs automatically.

**Key Points:**
- User defines priorities once in their profile
- Applies to ALL snags across all sites they own
- Collaborators viewing a site see the site owner's priority definitions
- Order is fixed (array index = display order, no sortOrder field needed)

## Constraints
- Code: max 4 characters
- Description: max 300 characters

## Implementation Status

### 1. Data Layer ✅ COMPLETE

| Task | Status | File |
|------|--------|------|
| Create `PriorityLevel` model class | ✅ | `lib/Data/models/priority_level.dart` |
| Add `priorities` field to AppUser model | ✅ | `lib/Data/models/app_user.dart` |
| Update Profile table schema (JSON column) | ✅ | `lib/Data/database/tables/profile_table.dart` |
| Update ProfileDao mappings | ✅ | `lib/Data/database/daos/profile_dao.dart` |
| Update ProfileSyncHandler for Firebase | ✅ | `lib/services/sync/handlers/profile_sync_handler.dart` |
| Defaults seeded when parsing null/empty | ✅ | `PriorityLevel.listFromJson()` |

### 2. Snag Model ✅ COMPLETE

| Task | Status | File |
|------|--------|------|
| Change `priority` from `int?` to `String?` | ✅ | `lib/Data/models/snag.dart` |
| Update Snag table column | ✅ | `lib/Data/database/tables/snags_table.dart` |
| Update DAO mappings | ✅ | Type-compatible, no changes needed |
| Regenerate database code | ✅ | `flutter pub run build_runner build` |

### 3. UI - Basic Fixes ✅ COMPLETE (Minimal for compilation)

| Task | Status | File |
|------|--------|------|
| create_snag_v2.dart - helper methods | ✅ | Added `_priorityCodeToIndex`, `_indexToPriorityCode` |
| snagDetailedView.dart - display methods | ✅ | Updated `_getPriorityLabel`, `_getPriorityColor` |
| snagCardView.dart - display methods | ✅ | Updated `_getPriorityLabel`, `_isHighSeverity` |
| site_status_v2.dart - display logic | ✅ | Updated priority color mapping |

### 4. UI - Settings Screen ❌ PENDING

| Task | Status |
|------|--------|
| Add "Priority Settings" section in app settings | ❌ |
| List editor for priorities (edit code + description) | ❌ |
| Validation: code max 4 chars, description max 300 chars | ❌ |
| Reset to defaults button | ❌ |

### 5. UI - Full Snag UI Update ❌ PENDING

| Task | Status |
|------|--------|
| Update `_buildPrioritySection` in create_snag_v2.dart to show actual priority codes | ❌ |
| Show 5 priority chips with dynamic codes from owner's profile | ❌ |
| Long-press or tap shows full description | ❌ |
| Fetch owner's priorities when viewing shared site | ❌ |

### 6. UI - PDF Generation ❌ PENDING

| Task | Status |
|------|--------|
| Update createPDF.dart for String priority | ❌ |

### 7. Migration ❌ NOT NEEDED

Development app with schema version 1. Reinstall app to apply database changes.
No migration code required.

---

## Files Modified (Phase 1)

```
lib/Data/models/priority_level.dart          NEW
lib/Data/models/app_user.dart                MODIFIED
lib/Data/models/snag.dart                    MODIFIED
lib/Data/database/tables/profile_table.dart  MODIFIED
lib/Data/database/tables/snags_table.dart    MODIFIED
lib/Data/database/daos/profile_dao.dart      MODIFIED
lib/services/sync/handlers/profile_sync_handler.dart  MODIFIED
lib/Screens/Snags/create_snag_v2.dart        MODIFIED
lib/Screens/Snags/snagDetailedView.dart      MODIFIED
lib/Widgets/snagCardView.dart                MODIFIED
lib/Screens/Sites/SiteInfo/site_status_v2.dart  MODIFIED
```

## Next Steps

1. **Phase 2: Priority Settings UI** - Add settings screen for users to customize priorities
2. **Phase 3: Snag UI Update** - Update snag creation/edit to use dynamic priorities from profile
3. **Phase 4: PDF Update** - Update PDF generation for String priority codes

---

**Phase 1 completed on 2026-06-06**
