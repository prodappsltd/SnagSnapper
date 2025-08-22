# Decision Log
**Purpose**: Track all key decisions and approvals
**Format**: Newest decisions at top

---

## Decision #009 ✅ APPROVED
**Date**: 2025-01-15
**Module**: Profile - Image Handling Lifecycle
**Decision Needed**: Complete image handling implementation details
**Discussion**: Interactive Q&A to define all edge cases and user flows

### Approved Decisions:
1. **Image Cropping**: Auto-crop to center square (no manual interface)
2. **Preview Screen**: No preview (immediate save)
3. **Original Storage**: Only keep compressed version
4. **Image Versions**: Single 1024x1024 (resize for PDFs dynamically)
5. **Replace Flow**: Must delete first, then add new (no direct replace)
6. **Sync Retry**: Keep trying forever (never give up)
7. **Storage Full**: Clear temp files first, then show error
8. **Permission Denied**: Grey out option with help text
9. **Concurrent Changes**: Cancel in-progress sync
10. **Compression UI**: Step indicators ("Resizing..." → "Compressing..." → "Saving...")
11. **Size Warning**: Silent save if acceptable (600KB-1MB)
12. **Deleted Recovery**: No recovery (permanent delete)
13. **Format Support**: Accept all formats, convert to JPEG
14. **Logo Required**: Optional field

**Implementation Flow**:
```
Has Logo → Tap → "Remove Logo" only → Delete → Show placeholder
No Logo → Tap → Camera/Gallery → Auto-crop → Compress → Save → Display
```

**PRD Updated**: Sections 4.3.4, 4.5.2
**Documents Updated**: PROFILE_IMAGE_IMPLEMENTATION_PLAN.md

---

## Decision #008 ✅ APPROVED
**Date**: 2025-01-14
**Module**: Profile - Image Validation
**Decision Needed**: Implement two-tier image size validation?
**Options**: 
1. Single limit (600KB only) - reject if larger
2. Two-tier (600KB optimal, 1MB max) - more flexible
3. No size limit - only dimension constraint
**Your Decision**: APPROVED - Option 2 (Two-tier system)
**Rationale**: Balances storage costs with user experience. Prevents unnecessary rejections while encouraging optimization
**Impact**: 
- Better user experience (fewer rejections)
- Slightly higher storage costs (some images 600KB-1MB)
- Clear feedback about optimization status
**Implementation**: 
- Start at 85% quality, reduce to 30% minimum
- Accept up to 1MB if can't achieve 600KB
- Always maintain 1024×1024 dimensions
**PRD Updated**: Section 4.5.2

---

## Decision #010 🔴 CRITICAL
**Date**: 2025-08-21
**Module**: Profile - Non-Blocking Sync Architecture
**Decision Needed**: How should we remove the blocking sync behavior when saving profile changes?

### Current Problem:
When user saves profile (text fields, image, or signature), the app:
1. Saves to local database (quick)
2. Calls `syncNow()` and WAITS for it to complete
3. Shows blocking "Syncing..." dialog during this wait
4. Only then shows success message and navigates

This violates offline-first principle where local operations should be instant.

### Proposed Solution Architecture:

**Option 1: Fire-and-Forget with Status Bar** (RECOMMENDED)
```
User saves → Save to DB → Show "Saved" → Navigate immediately
                ↓
          Background sync → Update status bar only
```
- Save to local DB with sync flags set
- Show immediate success message
- Navigate immediately  
- Trigger background sync (non-blocking)
- Update sync status indicator in real-time
- No blocking dialogs ever

**Option 2: Optimistic UI with Rollback**
- Save and navigate immediately
- If sync fails later, show notification
- Allow manual retry from notification
- More complex error handling

**Option 3: Queue-Based with Progress Tracking**
- Save to DB and sync queue
- Navigate immediately
- Show sync progress in persistent notification
- Process queue in background service

### Implementation Details for Option 1:

1. **Profile Save Flow**:
```dart
// Current (BLOCKING):
success = await database.save(user);
if (success) {
  showDialog("Syncing...");  // BLOCKS UI
  await syncService.syncNow();  // WAITS
  hideDialog();
  showSnackBar("Saved and synced");
  navigate();
}

// Proposed (NON-BLOCKING):
success = await database.save(user);
if (success) {
  showSnackBar("Profile saved");
  navigate();  // IMMEDIATE
  
  // Fire and forget
  syncService.syncInBackground().catchError((e) {
    // Log error, update status indicator
  });
}
```

2. **Sync Status Indicator Updates**:
- Already implemented and working
- Shows orange when pending
- Shows green when synced
- Shows red on error
- User can tap to retry

3. **Background Sync Method**:
```dart
Future<void> syncInBackground() async {
  // Don't await, just fire
  unawaited(syncNow().catchError((e) {
    // Update status to error
    updateStatus(SyncStatus.error);
  }));
}
```

### Decision Points Needed:

**Q1: Should we show ANY indication that sync is happening?**
- A) No indication at all (pure fire-and-forget)
- B) Update status bar only (recommended)
- C) Show non-blocking toast briefly
- D) Show progress in notification tray

**Q2: How to handle sync failures?**
- A) Silent failure (just update status indicator)
- B) Show error toast after failure
- C) Show persistent notification
- D) Combination of A + manual sync button appears

**Q3: Should image/signature uploads block?**
- A) No, same as text fields (fire-and-forget)
- B) Yes, show non-blocking progress indicator
- C) Show progress but allow navigation
- D) Queue for background upload

**Q4: What about first-time profile creation?**
- A) Same behavior (save locally, sync later)
- B) Wait for first sync to establish cloud backup
- C) Show one-time setup progress
- D) Educate user about offline-first in onboarding

**Your Decision**: ✅ APPROVED - Implement Fire-and-Forget with Custom Modifications

### Final Approved Architecture:

**Profile Screen Changes:**
1. ✅ Remove SyncStatusIndicator from app bar
2. ✅ Remove manual sync button
3. ✅ Remove ALL sync calls (`syncNow()`)
4. ✅ Remove ALL profile reloads after sync
5. ✅ Save to DB with flags → Show "Profile saved" → Navigate immediately

**Sync Architecture:**
```
Profile Save → DB Update → Navigate → Main Screen → Background Sync
Sites Save → DB Update → Navigate → MySites Screen → Background Sync  
Snags Save → DB Update → Navigate → SiteDetail Screen → Background Sync
```

**Approved Decisions:**

**Q1: Sync Indication**
- ✅ NO sync indication on profile screen at all
- ✅ Remove SyncStatusIndicator widget from profile
- ✅ Sync happens silently from main screen

**Q2: First-Time Profile**
- ✅ Same behavior as existing profiles
- ✅ Save locally, navigate immediately
- ✅ Risk of no cloud backup if never online - ACCEPTED

**Q3: Image/Signature Uploads**
- ✅ Mix of B+C: Cancel previous upload + show progress
- ✅ Background upload with progress indicator
- ✅ Cancel previous if user changes image again

**Q4: Error Handling**
- ✅ Option C: Toast only for permanent failures
- ✅ Temporary failures retry silently
- ✅ Show specific error messages

**Edge Case Resolutions:**

**E1: Force Logout**
- ✅ Cancel sync immediately on force_logout detection
- ✅ Priority: Security over data preservation

**E2: Profile Reload**
- ✅ NEVER reload profile after sync
- ✅ SyncStatusIndicator reads from DB independently
- ✅ Profile screen loads data once on mount only

**E3: Image Operations**
- ✅ Already handled by `busy` flag
- ✅ No additional changes needed

**E4: Validation Mismatch**
- ✅ Added to PRD: Local MUST match Firebase validation
- ✅ Critical requirement for smooth operations

**E5: Debouncing**
- ✅ Keep 300ms debounce as-is
- ✅ Each screen syncs its own module (no conflicts)

**Rationale**: 
- True offline-first architecture
- Instant UI response
- Clean separation of concerns
- Each screen responsible for its module's sync

**Impact**: 
- Immediate navigation after save
- Better user experience
- No blocking dialogs ever
- Simpler code without reload logic

**Risk**: Users might not notice sync failures
**Mitigation**: Error toasts for permanent failures, retry mechanism for temporary issues

---

## Decision #007 🟢 FUTURE ENHANCEMENT
**Date**: 2025-01-12
**Module**: Profile - Authentication Security
**Decision Needed**: Should we implement MFA to prevent unauthorized account access?
**Options**: 
1. Implement MFA with SMS/Email verification
2. Implement MFA with Authenticator app (TOTP)
3. Implement biometric authentication
4. Defer for future release
**Your Decision**: [PENDING - LOW PRIORITY]
**Rationale**: Would prevent account hijacking when someone tries to login on a different device
**Impact**: Enhanced security for device switching scenarios
**Recommendation**: Consider for Phase 2 of security enhancements
**Note**: Current device switch warning provides basic protection

---

## Decision #006 ✅ RESOLVED
**Date**: 2025-01-12
**Module**: Profile - Device Management
**Decision Needed**: Should we fix device switch warning dialog now or defer?
**Options**: 
1. Fix now - Implement proper warning dialog (2 hours)
2. Use temporary auto-confirm for development (current state)
3. Defer to production release prep
**Your Decision**: IMPLEMENTED - Fixed immediately per PRD 4.3.2
**Rationale**: Security/UX critical - users could lose data without warning
**Impact**: Full warning dialog now shows in production with user choice
**Risk**: MITIGATED - Users now see complete warning before device switch
**Implementation**: Device switch warning dialog fully implemented at contentProvider.dart:1215-1416

---

## Decision #005 ✅ RESOLVED
**Date**: 2025-01-12
**Module**: Profile - Database Operations
**Decision Needed**: How to handle duplicate profile insert attempts?
**Options**: 
1. Check exists → update if exists, insert if not (recommended)
2. Always upsert (replace existing)
3. Throw error on duplicate
**Your Decision**: IMPLEMENTED - Option 1 (check exists, then update or insert)
**Rationale**: Safest approach - prevents database errors while preserving existing data
**Impact**: No database errors in production
**Implementation**: Fixed at ProfileSetupScreen lines 633-646 with proper duplicate check

---

## Decision #004
**Date**: 2025-01-12
**Module**: Development Sequence
**Decision Needed**: What is the correct module sequence?
**Options**: 
1. Profile → Snag → Reports (original)
2. Profile → Site → Snag → Reports (corrected)
**Your Decision**: APPROVED - Add Site Creation before Snag
**Rationale**: Sites must exist before snags can be created (logical dependency)
**Impact**: Adds ~2 weeks but ensures proper data hierarchy

---

## Decision #003
**Date**: 2025-01-12
**Module**: Project Structure
**Decision Needed**: Should we reorganize documentation?
**Options**: 
1. Keep flat structure
2. Create hierarchical folders (recommended)
3. Minimal changes only
**Your Decision**: APPROVED - Keep hierarchical structure
**Rationale**: Better organization and clear approval gates
**Impact**: Already implemented, provides better control

---

## Decision #002
**Date**: 2025-01-11
**Module**: Profile
**Decision Needed**: Complete Profile 100% or move to Snag at 90%?
**Options**: 
1. Complete all testing (3-4 days)
2. Move to Snag, return later (faster progress)
**Your Decision**: APPROVED - Complete Profile to 100% first
**Rationale**: Better to have solid foundation, no technical debt
**Impact**: 3-4 days additional but ensures quality
**Additional Note**: Proceed with Site Creation after Profile, then Snag Creation

---

## Decision #001
**Date**: 2025-01-10
**Module**: Profile
**Decision Needed**: TDD approach for all development?
**Options**: 
1. Full TDD (slower but safer)
2. Tests after implementation
3. Minimal testing
**Your Decision**: Full TDD
**Rationale**: Higher quality, fewer bugs
**Impact**: 30% slower development, 70% fewer bugs

---

## Template for New Decisions

```
## Decision #XXX
**Date**: YYYY-MM-DD
**Module**: Profile/Snag/Reports/etc
**Decision Needed**: Clear question
**Options**: 
1. Option A (pros/cons)
2. Option B (pros/cons)
3. Option C (pros/cons)
**Your Decision**: [PENDING/APPROVED/REJECTED]
**Rationale**: Why this choice?
**Impact**: Time/cost/quality impact
```

---

## Decision Categories

### 🔴 Critical (Need Immediate Response)
- Architecture changes
- PRD deviations
- Security concerns
- Data model changes

### 🟡 Important (Need Within 24 Hours)
- Module priorities
- Feature additions/cuts
- Timeline changes
- Resource allocation

### 🟢 Standard (Need Within Week)
- UI/UX choices
- Library selections
- Testing strategies
- Documentation updates

---

## Escalation Process

1. **Document** the decision needed here
2. **Notify** you via agreed channel
3. **Wait** for response per category timeline
4. **Proceed** with fallback if no response
5. **Update** this log with decision

---

## Statistics

- Total Decisions: 7
- Approved: 4
- Resolved: 2
- Pending: 1 (Low Priority - MFA)
- Average Response Time: Same day
- Critical Pending: 0
- Important Pending: 0