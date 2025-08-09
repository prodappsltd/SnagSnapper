# SnagSnapper Design Report
## Complete Functional and Design Lifecycle

---

## Executive Summary

SnagSnapper is an offline-first mobile application designed for construction site defect management. The app enables site managers to create sites, document defects (snags), assign them to workers, and track their resolution - all while working in areas with poor or no internet connectivity.

### System Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│ Firebase Auth    │────▶│ Google OAuth    │
│  (Offline-First)│     └──────────────────┘     └─────────────────┘
└────────┬────────┘              │
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│  Local SQLite   │     │    Firestore     │
│   Database      │◀───▶│    Database      │
└─────────────────┘ Sync └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│  Local Image    │     │ Firebase Storage │
│     Cache       │◀───▶│   (Images)       │
└─────────────────┘ Sync └──────────────────┘
```

## Table of Contents

1. [Authentication & Signup Flow](#1-authentication--signup-flow)
2. [Profile Module](#2-profile-module)
3. [Site Module](#3-site-module)
4. [Snag Module](#4-snag-module)
5. [Sync & Offline Behavior](#5-sync--offline-behavior)
6. [Firebase Security Rules](#6-firebase-security-rules)
7. [Image Management](#7-image-management)
8. [Edge Cases & Error Handling](#8-edge-cases--error-handling)
9. [Data Flow and Dependencies](#9-data-flow-and-dependencies)

---


## 1. Authentication & Signup Flow

### Authentication Flow Overview

```
┌─────────┐
│  Start  │
└────┬────┘
     │
     ├─────── Google Sign-In ─────────────┐
     │                                    │
     └─────── Email/Password ─────┐       │
                    │             │       │
                    ▼             │       │
              Email Verify? ──No──┘       │
                    │                     │
                   Yes                    │
                    │                     │
                    └─────┬───────────────┘
                          │
                    Profile Exists?
                    /            \
                  Yes             No
                   │               │
                   ▼               ▼
              Main Menu      Profile Setup
                                   │
                                   ▼
                              Main Menu
```

### 1.1 Google Sign-In Flow

**Process:**
1. User taps "Sign in with Google"
2. Google OAuth consent screen appears
3. User selects account and approves
4. App receives authentication token
5. Firebase Auth creates/updates user account (email automatically verified for Google)
6. App checks if profile exists in Firestore
   - If exists: Navigate to main menu
   - If not exists: Navigate to profile setup (can create immediately, no verification needed)

**Edge Cases:**
- User cancels Google sign-in → Show "Sign-in cancelled" message, stay on auth screen
- Google services unavailable → Show "Google services unavailable. Please try again later."
- Network timeout → Show "Connection timeout. Please check your internet connection."
- User's Google account is suspended → Firebase Auth will handle, show generic error
- No network on first launch → Authentication fails, show "Internet connection required for initial setup"
- User denies Google permissions → Show "Permissions required to sign in with Google"
- Multiple Google accounts on device → User selects wrong account, signs out and tries again
- Google Play Services outdated → Show "Please update Google Play Services to continue"
- OAuth token expired during sign-in → Retry silently once, then show "Sign-in failed. Please try again."
- Existing email/password account, user tries Google → Allow and link both providers to same account

### 1.2 Email/Password Signup Flow

**Process:**
1. User enters email and password
2. Local validation:
   - Email format: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
   - Password: Minimum 6 characters
3. Firebase Auth creates account
4. Email verification sent automatically
5. Show verification pending screen (profile creation blocked until verified)

**Edge Cases:**
- Email already in use → "An account already exists with this email"
- Weak password → "Password should be at least 6 characters"
- Invalid email format → "Please enter a valid email address"
- Network failure during signup → Save credentials locally, retry on next app launch
- Firebase Auth service down → "Service temporarily unavailable. Please try again later."
- Existing Google account, user tries email/password → Check providers first, show "An account already exists with Google Sign-In. Please use Google to sign in."
- User forgets password → Show "Forgot password?" link → Enter email → Send reset email → User clicks link → Set new password → Sign in with new password

### 1.3 Email Verification Process

**States:**
- Unverified: Limited functionality - can view auth screen only
- Verified: Can create profile and access full app functionality

**Process:**
1. Verification email sent on signup
2. Show popup: "Verification email sent! Please check your inbox and spam folder. The email may take a few minutes to arrive."
3. Display 120-second countdown timer before "Resend email" button becomes active
4. User clicks link in email
5. On next app launch/resume, check verification status
6. If verified, allow profile creation
7. Update UI to show full functionality

**Important**: Profile creation is blocked until email is verified (enforced by Firebase Security Rules)

**Edge Cases:**
- Email never arrives → "Resend verification email" button (active after 120 seconds)
- Verification link expired → Show "Link expired" with resend option
- User changes email → Must re-verify new email
- Check verification fails (network) → Assume last known state, check again later
- Too many resend attempts → Rate limit after 5 attempts, show "Too many attempts. Please try again in 1 hour."
- Token refresh fails → Continue with cached auth state for 24 hours, retry refresh in background every 30 minutes
- After 24 hours of failed refresh → Force re-authentication with "Session expired. Please sign in again."
- Account disabled by admin while user active → Next sync/operation fails with auth error → Show "Your account has been disabled. Please contact your administrator." → Force sign out

### 1.4 Profile Setup Flow

**Process:**
1. After authentication, check Profile collection
2. If no profile exists, show setup screens:
   - Screen 1: Name, Company Name
   - Screen 2: Phone, Job Title, Postcode (optional)
   - Screen 3: Photo (optional, can skip)
3. Create profile document in Firestore
4. Navigate to main menu

**Edge Cases:**
- User closes app during setup → On next launch, resume from last incomplete screen
- Network fails during profile creation → Save locally, sync when online
- Firestore write fails → Retry with exponential backoff
- Validation fails → Show specific field errors, prevent progression
- User navigates back → Save draft locally, allow resume later

---

## 2. Profile Module

### Data Structure Hierarchy

```
Profile Document
├── Required Fields
│   ├── NAME (2-100 chars)
│   ├── EMAIL (validated format)
│   ├── COMPANY_NAME (2-200 chars)
│   ├── PHONE (7-15 digits)
│   └── JOB_TITLE (1-100 chars)
├── Optional Fields
│   ├── POSTCODE_AREA (1-20 chars)
│   ├── DATE_FORMAT (3 options)
│   ├── IMAGE (relative path)
│   └── SIGNATURE (relative path)
├── System Fields
│   ├── LAST_UPDATED (timestamp)
│   └── LIST_OF_SITE_PATHS (map)
└── Arrays
    └── LIST_OF_COLLEAGUES[]
        └── email strings (max 100)
```

### 2.1 Initial Profile Creation

**Required Fields:**
- NAME: 2-100 characters, Unicode letters, numbers, spaces, hyphens, apostrophes
- EMAIL: Valid format, must match authenticated user
- COMPANY_NAME: 2-200 characters, Unicode letters, numbers, business punctuation (-&.,()+ /)
- PHONE: International format, 7-15 digits
- JOB_TITLE: 1-100 characters, Unicode letters, spaces, hyphens, slashes, commas (required)

**Optional Fields:**
- POSTCODE_AREA: 1-20 characters, alphanumeric
- DATE_FORMAT: 'dd-MM-yyyy', 'MM-dd-yyyy', or 'yyyy-MM-dd'
- IMAGE: Relative path format `{userId}/profile.jpg`
- SIGNATURE: Relative path format `{userId}/signature.png`

**Process:**
1. Collect data through UI forms
2. Validate all fields locally
3. Create document in `/Profile/{userId}`
4. Add LAST_UPDATED timestamp
5. If offline, queue for sync

### 2.2 Profile Image Upload/Delete Logic

#### Image Upload Flow Diagram

```
┌──────────────────┐
│ User Selects     │
│ Image            │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Compress Image   │
│ (1024x1024, 70%) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐      ┌──────────────────┐
│ Save to Cache    │─────▶│ Display in UI    │
│ (Local Storage)  │      │ (Instant)        │
└────────┬─────────┘      └──────────────────┘
         │
         ▼
    Check Network?
    /          \
  Yes           No
   │             │
   ▼             ▼
┌──────────┐  ┌──────────┐
│ Upload   │  │ Queue    │
│ Storage  │  │ Upload   │
└────┬─────┘  └─────┬────┘
     │              │
     └──────┬───────┘
            │
            ▼
     ┌──────────────┐
     │ Update State │
     │ & Sync Doc   │
     └──────────────┘
```

**Path Clarification:**
- Firebase Storage path: `{userId}/profile.jpg` (relative path stored in Firestore)
- Local cache path: `{app_documents}/image_cache/{userId}/profile.jpg` (full device path)

**Upload Process:**
1. User taps camera/gallery button
2. Image picker launches
3. User selects/captures image
4. Image compressed to max 1024x1024, JPEG quality 70%
5. Save to local cache immediately: `{app_documents}/image_cache/{userId}/profile.jpg`
6. Update UI instantly (image appears immediately)
7. Set image state to 'cached'
8. Store relative path in profile document: `{userId}/profile.jpg`
9. If online: Upload to Firebase Storage in background
10. If offline: Add to upload queue for later sync

**Delete Process:**
1. User taps delete button
2. Immediately remove from local cache
3. Update UI (image disappears)
4. Clear profile.image field locally
5. Queue profile update (with empty image field) in sync_queue
6. Queue image deletion in image_deletion_queue
7. If online: Process both queues immediately
8. If offline: Process when connection restored

**Edge Cases:**
- Camera permission denied → "Camera access required. Please enable in Settings."
- Image picker cancelled → No action, return to profile
- Compression fails → Show "Image processing failed. Please try another image."
- Local storage full → "Device storage full. Please free up space."
- Upload fails after 3 retries → Move to manual retry queue, show sync icon
- Firebase Storage quota exceeded → Queue for later, notify user about temporary issue
- Image corrupted → Validate image before processing, show error if invalid
- User switches images rapidly → Cancel previous upload, process latest only
- Image uploads but profile update fails → Image orphaned in Storage (cleanup job handles later)
- App killed during upload → Upload queue persists, resumes on next launch

### 2.3 Signature Functionality

**Process:**
1. User taps signature field
2. Signature pad appears (white canvas, black ink)
3. User draws signature
4. On save: Convert to PNG, compress
5. Save as `{userId}/signature.png`
6. Follow same upload/sync logic as profile image

**Edge Cases:**
- Empty signature → Prompt "Please sign before saving"
- Signature too simple (few points) → Accept but warn about security
- Device rotation during signing → Lock orientation while signing
- Memory pressure → Clear canvas data after save

### 2.4 Colleague Management

**Efficient Design:**
1. Store colleagues as simple array in Profile document:
   ```
   LIST_OF_COLLEAGUES: ["email1@example.com", "email2@example.com"]
   ```
2. When sharing sites, validate against this list
3. No separate colleague profiles needed
4. Maximum 100 colleagues per user

**Process:**
1. Add colleague: Enter email, validate format, add to array
2. Remove colleague: Remove from array, update document
3. Sync entire profile document when changed

**Important Dependency**: For manual sharing, colleagues must be added to profile BEFORE they can be selected for site sharing. For share code joining, colleagues are added automatically to the site's sharedWith map without being in the owner's colleague list

**Edge Cases:**
- Duplicate email → Prevent addition, show "Colleague already added"
- Invalid email format → Show validation error
- Colleague limit reached → "Maximum 100 colleagues allowed"
- Colleague has no SnagSnapper account → Allow addition (they can join later)
- Remove colleague who has site access → Their access remains until explicitly removed from each site

### 2.5 Date Format Preferences

**Options:**
- dd-MM-yyyy (European)
- MM-dd-yyyy (American)  
- yyyy-MM-dd (ISO)

**Application:**
- All date displays throughout app
- Date pickers default format
- Export/report generation

**Edge Cases:**
- Not set → Default to device locale
- Invalid format in database → Default to 'dd-MM-yyyy'
- Format change → Update all cached date displays

### 2.6 Offline Profile Updates

**Process:**
1. User edits any profile field while offline
2. Save complete profile document to SQLite
3. Add to sync queue: `entity_type: 'profile', entity_id: {userId}`
4. Show sync pending icon in profile screen
5. When online: Upload entire document
6. On success: Remove from queue, update icon

**Conflict Resolution:**
- Last write wins (entire document replaced)
- No field-level tracking needed
- Timestamp ensures ordering

### 2.7 Profile Deletion

**Note**: Profile deletion is NOT allowed through the app (Firebase rules prevent it)
- Enforced for data retention and audit trail
- Manual deletion only through support request
- See Section 8.4 for manual deletion process

---

## 3. Site Module

### Site Data Hierarchy

```
Site Document
├── Metadata
│   ├── uID (UUID v4)
│   ├── date (creation)
│   ├── ownerEmail
│   └── ownerName
├── Core Fields
│   ├── name (2-100 chars)
│   ├── companyName (snapshot)
│   └── location (2-500 chars)
├── Settings
│   ├── pictureQuality (0-2)
│   ├── archive (boolean)
│   └── image (optional path)
├── Permissions
│   ├── sharedWith (map)
│   │   ├── owner@email.com: "OWNER"
│   │   └── user@email.com: "VIEW"
│   └── shareCode (8-char string)
└── Subcollections
    └── Snags[]
```

### Permission Matrix

```
┌─────────────────┬────────┬────────┬──────────┐
│ Action          │ Owner  │ Viewer │ No Access│
├─────────────────┼────────┼────────┼──────────┤
│ View Site       │   ✓    │   ✓    │    ✗     │
│ Edit Site       │   ✓    │   ✗    │    ✗     │
│ Delete Site     │   ✓    │   ✗    │    ✗     │
│ Share Site      │   ✓    │   ✗    │    ✗     │
│ Archive Site    │   ✓    │   ✗    │    ✗     │
│ Create Snag     │   ✓    │   ✗    │    ✗     │
│ View Snags      │   ✓    │   ✓    │    ✗     │
└─────────────────┴────────┴────────┴──────────┘
```

### 3.1 Site Creation Process

**Required Fields:**
- name: Site name (2-100 characters)
- companyName: Prefilled from profile (snapshot at creation time, doesn't auto-update)
- location: Site address/description (2-500 characters)
- date: Creation date (auto-set)
- ownerEmail: Creator's email (auto-set)
- ownerName: Creator's name (auto-set)
- uID: Generated UUID

**Optional Fields:**
- image: One site image `{userId}/sites/{siteId}/site.jpg`
- pictureQuality: 0 (low), 1 (medium), 2 (high)

**Process:**
1. User fills site creation form
2. Generate unique site ID (UUID v4)
3. Generate unique 8-character share code (e.g., "SITE-A2B4") - must be unique across all sites
4. Set owner permissions in sharedWith map: `{ownerEmail: 'OWNER'}`
5. Create document in `/Profile/{userId}/Sites/{siteId}`
6. If offline: Queue for sync with operation='create'

**Storage Path**: Sites are stored at `/Profile/{userId}/Sites/{siteId}`

### 3.2 Site Sharing Mechanism

**Efficient Permission System:**
```
sharedWith: {
  "owner@email.com": "OWNER",
  "colleague1@email.com": "VIEW",
  "colleague2@email.com": "VIEW"
}
```

**Permissions:**
- OWNER: Full control (edit, delete, share, create snags)
- VIEW: Read-only access to site and snags

**Sharing Process (Manual):**
1. Owner selects colleagues from their LIST_OF_COLLEAGUES (requires colleagues added in profile first)
2. Adds email with VIEW permission
3. Update site document with new sharedWith map

**Sharing Process (Share Code):**
1. Owner retrieves site's share code (generated at site creation)
2. Owner shares code via WhatsApp/Email/SMS: "Join my site on SnagSnapper with code: SITE-A2B4"
3. Colleague enters code in app (must be authenticated with profile)
4. App validates code by searching across all sites using collectionGroup query on shareCode field
5. If valid, adds colleague's email to site's sharedWith map with VIEW permission
6. Site appears in colleague's site list immediately

**Removing Access:**
1. Owner removes email from sharedWith
2. On next sync, site disappears from shared user's view
3. Any offline edits from removed user are rejected
4. Assigned snags remain assigned but user loses access (owner should reassign)

**Edge Cases:**
- Share with non-existent user → Allow (they can join later)
- Owner shares with themselves → Ignore (already OWNER)
- User removed while editing offline → Sync fails with permission error
- Maximum shares → Limit to 50 users per site
- Invalid share code entered → "Invalid code. Please check and try again."
- Share code for archived site → "This site has been archived. Contact the owner."
- User already has access to site → "You already have access to this site."
- Share codes are permanent (no expiration) - regeneration not implemented in v1
- Share code entered while offline → "Internet connection required to join sites"

### 3.3 Permission Inheritance for Snags

**Rules:**
- If user has site access, they can view all snags
- Only site OWNER can create/edit/delete snags
- Only assigned user can edit snag fix fields
- Snag visibility follows site permissions automatically

**Implementation:**
- No separate permission checking for snags
- Snag query: Get all snags where siteUID matches accessible sites
- UI enforces edit restrictions based on user role

### 3.4 Site Archiving

**Process:**
1. Owner sets `archive: true`
2. Site moves to archived section in UI
3. All snags remain accessible but read-only
4. Shared users see archived status
5. Can be unarchived anytime

**Edge Cases:**
- Archive with open snags → Allow, but warn user
- Shared user tries to archive → Prevent (owner only)
- Offline archive → Queue sync, show archived locally

### 3.5 Site Deletion

**Process:**
1. Owner confirms deletion (require double confirmation)
2. Delete all snags for the site (from `/Profile/{userId}/Sites/{siteId}/Snags/`)
3. Delete all snag images from Storage
4. Delete site image from Storage
5. Delete site document (share code becomes invalid)
6. Add delete operation to sync queue with operation='delete'
7. Remove from all users' caches

**Offline Deletion:**
- Queue deletion with operation='delete' in sync_queue
- Remove from local cache immediately
- Process Firebase deletion when online

**Edge Cases:**
- Delete while users offline → Their sync attempts fail gracefully
- Partial deletion (network fails) → Retry entire deletion
- Storage deletion fails → Queue for cleanup task
- Active snags → Warn about data loss
- Snags in upload queue → Remove from queue before deletion
- Related items in sync queue → Clear all related sync items

### 3.6 Site Image Handling

**Process:**
1. One image per site allowed
2. Stored as `{userId}/sites/{siteId}/site.jpg`
3. Same upload/cache/sync logic as profile images
4. Compressed based on pictureQuality setting:
   - Low (0): 640x640, 60% quality
   - Medium (1): 1024x1024, 70% quality  
   - High (2): 2048x2048, 80% quality

---

## 4. Snag Module

### Snag Lifecycle Diagram

```
┌──────────────┐
│   Created    │ (by Site Owner)
│ Status: Open │
└──────┬───────┘
       │ Assign
       ▼
┌──────────────┐
│  Assigned    │ (to Worker)
│ Status: Open │
└──────┬───────┘
       │ Worker adds fix
       ▼
┌──────────────┐
│   Pending    │ (Review by Owner)
│   Review     │
└──────┬───────┘
       │ Owner approves
       ▼
┌──────────────┐
│   Closed     │ (Resolved)
│  Complete    │
└──────────────┘
```

### Snag Permission Matrix

```
┌─────────────────┬────────┬──────────┬────────┐
│ Action          │ Owner  │ Assignee │ Viewer │
├─────────────────┼────────┼──────────┼────────┤
│ Create Snag     │   ✓    │    ✗     │   ✗    │
│ View Snag       │   ✓    │    ✓     │   ✓    │
│ Edit Details    │   ✓    │    ✗     │   ✗    │
│ Assign/Reassign │   ✓    │    ✗     │   ✗    │
│ Add Fix Photos  │   ✗    │    ✓     │   ✗    │
│ Add Fix Desc    │   ✗    │    ✓     │   ✗    │
│ Close Snag      │   ✓    │    ✗     │   ✗    │
│ Delete Snag     │   ✓    │    ✗     │   ✗    │
└─────────────────┴────────┴──────────┴────────┘
```

### 4.1 Snag Creation Workflow

**Creator:** Only site OWNER can create snags

**Required Fields:**
- location: Where in the site (2-200 characters)
- title: Brief description (2-200 characters)
- priority: 0 (low), 1 (medium), 2 (high)
- description: Detailed explanation (2-1000 characters)
- creatorEmail: Auto-set to owner
- siteUID: Parent site ID
- ownerEmail: Site owner email

**Optional Fields:**
- assignedEmail/Name: Who should fix it
- dueDate: When it should be completed
- Images: Up to 4 'before' photos

**Process:**
1. Owner navigates to site's snag list
2. Fills snag creation form
3. Captures up to 4 photos
4. Assigns to colleague (optional)
5. Creates document at `/Profile/{ownerId}/Sites/{siteId}/Snags/{snagId}`
6. If offline: Queues for sync with operation='create'

**Storage Path**: Snags are stored at `/Profile/{ownerId}/Sites/{siteId}/Snags/{snagId}`

### 4.2 Assignment Logic

**Who Can Assign:**
- Only site OWNER

**Assignment Options:**
- Any email from site's sharedWith list
- Or manually entered email (for future users)
- Can reassign anytime
- Can unassign (set to null)

**Assignment Validation:**
- At assignment time, validate against current site's sharedWith map
- Prevents assigning to users who no longer have access

**Assignee Notifications:**
- Assignee sees snag in their "Assigned to Me" list
- Badge count updates
- No push notifications (out of scope)

**Edge Cases:**
- Assign to non-user → Allow (they'll see when they join)
- Assign to removed user → Validation against sharedWith map prevents this
- Change assignment → Update assignedEmail/Name
- Self-assignment → Allow (owner can assign to self)

### 4.3 Status Transitions

**Status Flow:**
```
Open/Active (snagStatus: true, snagConfirmedStatus: true)
  ↓ (assignee adds fix photos/description)
Pending Review (snagStatus: true, snagConfirmedStatus: false)  
  ↓ (owner reviews and approves)
Closed/Resolved (snagStatus: false, snagConfirmedStatus: false)
```

**Note**: The field names are legacy - `snagStatus: true` means "open/active", `snagConfirmedStatus: false` means "pending owner confirmation"

**Who Can Change:**
- snagStatus: Only owner (close/reopen snag)
- snagConfirmedStatus: Automatically set when assignee adds fix
- Fix fields: Only assignedEmail user
  - snagFixDescription: 2-1000 characters (required)
  - snagFixMainImage, snagFixImage1-3: Up to 4 fix photos (optional)

**Edge Cases:**
- Complete without assignment → Not possible (UI prevents, must assign first)
- Unassigned snag → Remains open until assigned
- Owner completes own snag → Acts as both owner and assignee
- Reopen closed snag → Reset to Open state
- Complete without photos → Allow (only description required)

### 4.4 Image Naming Conventions

**Before Images (Owner):**
- `{userId}/sites/{siteId}/snags/{snagId}/before_main.jpg`
- `{userId}/sites/{siteId}/snags/{snagId}/before_2.jpg`
- `{userId}/sites/{siteId}/snags/{snagId}/before_3.jpg`
- `{userId}/sites/{siteId}/snags/{snagId}/before_4.jpg`

**After Images (Assignee):**
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_main.jpg`
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_2.jpg`
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_3.jpg`
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_4.jpg`

**Storage Strategy:**
- Each user stores their own images
- Prevents permission conflicts
- Easy cleanup when user deleted

### 4.5 Due Date Handling

**Setting:**
- Optional field during creation
- Owner can update anytime
- Stored as UTC, displayed in user's local timezone
- Shows in snag list with color coding:
  - Green: >7 days remaining
  - Yellow: 1-7 days remaining
  - Red: Overdue

**Edge Cases:**
- Past date selected → Allow with warning
- No date → Show as "No due date"
- Change date after overdue → Update status color

### 4.6 Notification Strategy

**In-App Indicators Only:**
- Badge on "Assigned to Me" tab
- Count of open assigned snags
- Sync icon when updates pending
- No push notifications (cost/complexity)

**Update Detection:**
- Check on app launch
- Check on navigation to snag list
- Background sync while app active

### 4.7 Snag Deletion

**Who Can Delete:**
- Only site OWNER can delete snags

**Process:**
1. Owner confirms deletion
2. Delete all snag images (before and after) from Storage
3. Delete snag document from Firestore
4. If offline: Queue deletion with operation='delete'
5. Remove from local cache immediately

**Edge Cases:**
- Delete while assignee working offline → Their updates fail on sync
- Partial deletion (network fails) → Retry entire deletion
- Images fail to delete → Queue for cleanup task

---

## 5. Sync & Offline Behavior

### Sync State Machine

```
                    ┌─────────────┐
                    │   Offline   │
                    │   (Queued)  │
                    └──────┬──────┘
                           │ Network Available
                           ▼
                    ┌─────────────┐
                    │   Syncing   │◀─────┐
                    │ (Uploading) │      │
                    └──────┬──────┘      │
                           │             │ Retry
                    Success│      Fail   │
                           ▼             │
                    ┌─────────────┐      │
                    │   Synced    │      │
                    │  (Complete)  │      │
                    └─────────────┘      │
                           │             │
                           └─────────────┘
                          Network Lost
```

### Sync Architecture

```
┌─────────────────────────────────────┐
│         Sync Service                │
├─────────────────────────────────────┤
│ Priority Queue:                     │
│  1. Snags (Most Critical)          │
│  2. Sites (Context)                │
│  3. Profile (Least Urgent)         │
├─────────────────────────────────────┤
│ Triggers:                           │
│  • App Launch/Resume               │
│  • Network State Change            │
│  • Navigation Events               │
│  • Timer (30s intervals)           │
├─────────────────────────────────────┤
│ Queues:                             │
│  • Document Sync Queue             │
│  • Image Upload Queue              │
│  • Image Deletion Queue            │
└─────────────────────────────────────┘
```

### 5.1 Queue Priority

**Order:** Snags → Sites → Profile

**Rationale:**
- Snags are most critical (active work)
- Sites needed for context
- Profile changes least urgent

**Implementation:**
```sql
SELECT * FROM sync_queue 
ORDER BY 
  CASE entity_type 
    WHEN 'snag' THEN 1
    WHEN 'site' THEN 2  
    WHEN 'profile' THEN 3
  END,
  created_at ASC
```

**Image Queue Priority:**
- Images have separate queue but follow same entity priority:
  - Snag images → Site images → Profile images
- Image uploads process in parallel with document sync

### 5.2 Retry Strategies

**Automatic Retries:**
- Attempt 1: Immediate
- Attempt 2: After 2 seconds
- Attempt 3: After 5 seconds
- After 3 total attempts: Move to manual retry queue

**Manual Retry Queue:**
- Shows in UI with sync error icon
- User can tap to retry
- Or wait for next auto-sync cycle
- Items remain until successfully synced or user signs out

**Exponential Backoff:**
```
retryDelay = baseDelay * (2 ^ attemptNumber)
maxDelay = 60 seconds
```

### 5.3 Conflict Scenarios

**Approved Edge Cases:**

1. **Site Deleted While Assignee Offline:**
   - Assignee's snag updates fail
   - Show error: "Site no longer exists"
   - Remove from local cache
   - Clear from sync queue

2. **Permissions Removed While Offline:**
   - Sync fails with permission error
   - Show: "You no longer have access"
   - Remove site/snags from local cache
   - Clear related sync items

3. **Database Corruption:**
   - Detect via integrity check on app start
   - Attempt repair with SQLite VACUUM
   - If fails: Clear cache, force full resync
   - Show: "Resyncing your data..."

### 5.4 Network Detection Logic

**Methods:**
1. Connectivity Plus plugin for initial status
2. Enhanced image service's isOnline() method (already implements caching)
3. Cache result for 5 seconds to avoid redundant checks

**States:**
- Online: Full sync enabled
- Offline: Queue all changes
- Uncertain: Attempt sync with quick timeout

**Background Behavior:**
- Check every 30 seconds while app active
- Check on app resume
- Check on navigation events
- Listen for connectivity changes

### 5.5 Shared Sites Discovery

**Process:**
1. On sync trigger, query Firestore using collectionGroup:
   ```
   collectionGroup('Sites')
   .where('sharedWith.{userEmail}', 'in', ['VIEW', 'OWNER'])
   ```
   Note: Replace {userEmail} with actual user's email address
2. For each discovered site:
   - Download site document
   - Store in sites_cache with is_owner=0
   - Download associated snags
3. Remove sites no longer shared

**Frequency:**
- On app launch
- On navigation to sites list
- Every 5 minutes while app active

### 5.6 SQLite Database Schema

```sql
-- Sync queue for all entities
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL CHECK(entity_type IN ('profile', 'site', 'snag')),
  entity_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  operation TEXT NOT NULL CHECK(operation IN ('create', 'update', 'delete')),
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  UNIQUE(entity_type, entity_id, operation)
);

-- Profile cache (stores complete JSON document including LIST_OF_COLLEAGUES)
CREATE TABLE profile_cache (
  user_id TEXT PRIMARY KEY,
  data TEXT NOT NULL,  -- JSON with all fields including LIST_OF_COLLEAGUES array
  last_modified INTEGER NOT NULL
);

-- Sites cache (stores complete JSON document including sharedWith map)
CREATE TABLE sites_cache (
  site_id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  data TEXT NOT NULL,  -- JSON with all fields including sharedWith permissions
  last_modified INTEGER NOT NULL,
  is_owner INTEGER NOT NULL DEFAULT 0
);

-- Snags cache (stores complete JSON document including assignment status)
CREATE TABLE snags_cache (
  snag_id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  data TEXT NOT NULL,  -- JSON with all fields including assignedEmail/Name
  last_modified INTEGER NOT NULL
);

-- Image upload queue
CREATE TABLE image_upload_queue (
  id TEXT PRIMARY KEY,
  relative_path TEXT NOT NULL,
  local_temp_path TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0
);

-- Image deletion queue
CREATE TABLE image_deletion_queue (
  id TEXT PRIMARY KEY,
  relative_path TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0
);
```

---

## 6. Firebase Security Rules

### 6.1 Profile Collection Rules

**Read Permission:**
- User must be authenticated
- Email must be verified
- Can only read own profile (userId matches)

**Write Permission:**
- Create: Email in document must match auth email
- Update: Cannot change email field
- Delete: Not allowed (data retention)

**Rate Limiting:**
- Minimum 5 seconds between updates
- Prevents rapid writes (cost control)

### 6.2 Sites Collection Rules

**Collection Path**: `/Profile/{userId}/Sites/{siteId}`

**Read Permission:**
- Must be in site's sharedWith map
- Email verification required
- Includes all permission levels

**Write Permission:**
- Create: User becomes OWNER automatically
- Update: Only if user is OWNER
- Delete: Only if user is OWNER

**Field Validation:**
- Site name: 2-100 characters
- Location: Required, 2-500 characters
- Image path: Must match pattern `{userId}/sites/{siteId}/site.jpg`
- Share code: Must be exactly 8 characters, alphanumeric with hyphens

### 6.3 Snags Collection Rules

**Collection Path**: `/Profile/{ownerId}/Sites/{siteId}/Snags/{snagId}`

**Read Permission:**
- User must have access to parent site
- Inherited from site permissions

**Write Permission:**
- Create: Only site OWNER
- Update Owner Fields: Only site OWNER
- Update Fix Fields: Only assignedEmail user
- Delete: Only site OWNER

**Field Validation:**
- Title: Required, 2-200 characters
- Priority: Must be 0, 1, or 2
- Image paths: Must match naming convention

### 6.4 Validation Rules

**Synchronization with UI:**
All validation rules match exactly with UI validation

**Email Validation:**
```
^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
```

**Phone Validation:**
```
^\+?[0-9]{7,15}$
```

**Name Validation (supports international):**
```
^[\p{L}\p{M}0-9\s\-']+$
```

**Script Injection Prevention:**
- Check for `<script`, `javascript:`, event handlers
- Block common XSS patterns
- Sanitize all text inputs

### 6.5 Size Limits

**Document Limits:**
- Profile: Max 20 fields
- Site: Max 15 fields
- Snag: Max 25 fields
- Arrays: Max 100 items (colleagues)
- Maps: Max 500 entries (site paths)

**String Limits:**
- Names: 2-100 characters
- Company: 2-200 characters
- Descriptions: 2-1000 characters
- Image paths: 1-100 characters

---

## 7. Image Management

### Image Storage Strategy

```
┌─────────────────────────────────────────┐
│          Image Hierarchy                │
├─────────────────────────────────────────┤
│ Profile Images                          │
│  └─ {userId}/profile.jpg               │
│  └─ {userId}/signature.png             │
├─────────────────────────────────────────┤
│ Site Images                             │
│  └─ {userId}/sites/{siteId}/site.jpg   │
├─────────────────────────────────────────┤
│ Snag Before Images (Owner)              │
│  └─ {ownerId}/sites/{siteId}/snags/    │
│      {snagId}/before_main.jpg          │
│      {snagId}/before_{2-4}.jpg         │
├─────────────────────────────────────────┤
│ Snag After Images (Assignee)            │
│  └─ {assigneeId}/sites/{siteId}/snags/ │
│      {snagId}/after_main.jpg           │
│      {snagId}/after_{2-4}.jpg          │
└─────────────────────────────────────────┘
```

### 7.1 Compression Settings

**Profile Images:**
- Size: 1024x1024 max
- Format: JPEG
- Quality: 70%
- Estimated size: ~100KB

**Site Images:**
- Low (0): 640x640, 60% quality (~50KB)
- Medium (1): 1024x1024, 70% quality (~100KB)
- High (2): 2048x2048, 80% quality (~300KB)

**Snag Images:**
- Follow site's pictureQuality setting
- Apply same compression as site images
- Maintain aspect ratio

### 7.2 File Size Strategy

**Cost Control Without Hard Limits:**
1. Progressive compression based on file count:
   - Sites 1-10: High quality allowed
   - Sites 11-50: Medium quality recommended
   - Sites 50+: Low quality enforced

2. Storage cost indicator in UI:
   - Show monthly storage estimate
   - Warn when exceeding thresholds

3. Cleanup recommendations:
   - Suggest archiving old sites
   - Prompt to delete completed snag images

### 7.3 Naming Conventions

**Profile:**
- `{userId}/profile.jpg`
- `{userId}/signature.png`

**Sites:**
- `{userId}/sites/{siteId}/site.jpg`

**Snags Before:**
- `{creatorId}/sites/{siteId}/snags/{snagId}/before_main.jpg`
- `{creatorId}/sites/{siteId}/snags/{snagId}/before_{2-4}.jpg`

**Snags After:**
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_main.jpg`
- `{assigneeId}/sites/{siteId}/snags/{snagId}/after_{2-4}.jpg`

### 7.4 Orphaned Image Cleanup

**Detection:**
1. List all images in user's Storage folder
2. List all image references in Firestore
3. Compare to find orphans

**Cleanup Process:**
1. Run weekly during low usage
2. Delete images not referenced for 30 days
3. Log deletions for audit trail
4. Free up storage space

**Edge Cases:**
- Image in upload queue → Don't delete
- Recently uploaded → 24 hour grace period
- Sync pending → Check sync queue first

---

## 8. Edge Cases & Error Handling

### 8.1 User Signs Out

**Process:**
1. Sign out from Firebase Auth
2. Clear all local caches (SQLite, image cache)
3. Clear sync queues
4. Clear SharedPreferences
5. Reset image service state
6. Navigate to authentication screen

**Important**: Any pending sync operations are lost

### 8.2 User Switches Google Accounts

**Scenario:** User signs out and signs in with different Google account

**Handling:**
1. Follow sign out process (8.1)
2. Sign in with new account
3. Start fresh with new user data
4. Caches kept separate by userId to prevent data mixing

### 8.3 Device Storage Full

**Detection:**
- Catch file write exceptions
- Check available space before operations

**Handling:**
1. Image uploads: Show "Device storage full" error
2. Suggest clearing app cache (old images)
3. Prevent new image captures
4. Allow viewing existing data
5. Queue sync operations in memory only
6. Show storage indicator in settings

### 8.4 Cost-Efficient Strategies

#### Cost Optimization Approach

```
┌─────────────────────────────────────────┐
│      Document-Level Sync Strategy       │
├─────────────────────────────────────────┤
│ Traditional (Field-Level) - EXPENSIVE   │
│                                         │
│ Update Name     ──► 1 write            │
│ Update Phone    ──► 1 write            │
│ Update Image    ──► 1 write            │
│ Update JobTitle ──► 1 write            │
│                     --------            │
│ Total: 4 writes = 4x cost              │
├─────────────────────────────────────────┤
│ Our Approach (Document-Level) - CHEAP   │
│                                         │
│ Update entire document ──► 1 write      │
│                                         │
│ Total: 1 write = 80% cost savings      │
└─────────────────────────────────────────┘
```

**Minimize Firebase Operations:**
1. Batch reads where possible
2. Cache aggressively with ETags
3. Full document sync (not fields)
4. Compress images before upload
5. Use pagination for large lists (50 items per page)
6. Background sync only when needed
7. Batch operations limited to 500 documents (Firestore limit)

**Cost Monitoring:**
1. Track operation counts locally
2. Show usage statistics to user
3. Suggest optimizations when high
4. Implement soft limits with warnings

### 8.5 Manual Account Deletion

**Process When User Requests Deletion:**
1. User contacts support
2. Admin manually:
   - Deletes all user's images from Storage
   - Deletes all Firestore documents
   - Removes from Firebase Auth
   - Logs deletion for compliance

**App Handling:**
- Graceful failure when data not found
- Clear local cache on 404 errors
- Show "Account not found" if needed

---

## 9. Data Flow and Dependencies

### Complete Data Flow Diagram

```
┌─────────────────┐
│ Authentication  │
│ (Google/Email)  │
└───────┬─────────┘
        │ Verified
        ▼
┌─────────────────┐
│ Profile Setup   │
│ (One Time)      │
└───────┬─────────┘
        │ Complete
        ▼
┌─────────────────┐
│   Main Menu     │
│ (Sites List)    │
└───┬─────────┬───┘
    │         │
    │ Create  │ View Shared
    ▼         ▼
┌─────────┐ ┌─────────┐
│  Site   │ │ Shared  │
│ (Owner) │ │  Sites  │
└────┬────┘ └────┬────┘
     │           │
     │ Create    │ View
     ▼           ▼
┌─────────┐ ┌─────────┐
│  Snag   │ │ Assigned│
│(Created)│ │  Snags  │
└────┬────┘ └────┬────┘
     │           │
     │ Assign    │ Fix
     ▼           ▼
┌─────────────────┐
│   Snag Cycle    │
│ Assign→Fix→Close│
└─────────────────┘
```

### 9.1 Authentication → Profile Flow
1. User authenticates (Google or Email/Password)
2. Email verification required for Email/Password users (automatic for Google)
3. Only verified users can create profile
4. Profile creation is mandatory before accessing any other features

### 9.2 Profile → Sites Flow
1. Profile must exist with valid data
2. Colleagues must be added to profile before site sharing
3. Company name from profile is copied to site (snapshot, not reference)
4. User's profile image path format determines site image path format

### 9.3 Sites → Snags Flow
1. Site must exist before creating snags
2. Site permissions determine snag visibility
3. Site's sharedWith list constrains snag assignment options
4. Site deletion cascades to all snags

### 9.4 Sync Dependencies
1. Profile sync independent of other entities
2. Site sync requires owner profile to exist
3. Snag sync requires parent site to exist
4. Image sync tied to parent entity sync

### 9.5 Offline → Online Transitions
1. Queued operations process in priority order (Snags → Sites → Profile)
2. Failed operations retry with exponential backoff
3. Creates/updates process before deletions (to avoid conflicts)
4. Image operations process in parallel with document operations

---

## Implementation Priority

1. **Phase 1**: Profile with image handling (current)
2. **Phase 2**: Sites with basic sharing
3. **Phase 3**: Snags with assignment workflow
4. **Phase 4**: Advanced features (archiving, cleanup)

## Development Guidelines

- **CLAUDE.md**: Store lint/typecheck commands and project-specific instructions
- **Testing**: Always run lint and typecheck before considering work complete
- **Comments**: Add thorough comments explaining why decisions were made
- **Debug Logging**: Use guarded debug statements at critical points

## Success Metrics

- Offline usage: 100% functionality without internet
- Sync reliability: 99.9% eventual consistency
- Cost efficiency: <$0.001 per user per day
- Performance: <100ms local operations
- Storage efficiency: <10MB per active user

---

*Document Version: 2.1*
*Last Updated: 2025-01-23*
*Status: Enhanced with Share Code Implementation*

**Version History:**
- v1.0: Initial draft
- v1.1: Corrected dependencies, clarified paths, added missing details
- v1.2: Final review - added profile deletion note, snag deletion section, clarified retry logic
- v1.3: Deep review - added sign out flow, shared sites discovery, clarified field validations, added development guidelines
- v1.4: Iterative review #1-2 - fixed Firestore query syntax, added field constraints, clarified fix fields, timezone handling, app killed scenario
- v1.5: Iterative review #3 - added location character limit, first launch offline case, batch limits, UUID generation
- v2.0: Added comprehensive visual diagrams, flow charts, hierarchies, and permission matrices throughout the document
- v2.1: Added share code implementation, authentication edge cases, updated site sharing mechanism