# SnagSnapper App Context

## App Status
- **Development Stage**: This is a DEVELOPMENT app, not production
- **No Legacy Users**: There are NO existing/legacy users to migrate
- **No Backward Compatibility Required**: We can make breaking changes as needed

## Module Status (Updated 2025-06-06)
| Module | Status | Notes |
|--------|--------|-------|
| Profile | ✅ Complete | Full sync with image/signature |
| Sites | ✅ Complete | NEW Site model, instant image ops |
| Snags | 🔲 Not Started | Planned next |

## Key Decisions
1. **Profile Collection**: Always use 'Profile' (capital P), never 'profiles' or 'users'
2. **Site Model**: Use NEW model at `lib/Data/models/site.dart` (not OLD `lib/Data/site.dart`)
3. **No Legacy Support**: Do not add code for backward compatibility with old data structures
4. **Clean Slate**: This app has a fresh Firebase instance with no historical data

## Firebase Configuration
- **Region**: Europe-west1 (not US-central)
- **Realtime Database URL**: https://snagsnapperpro-default-rtdb.europe-west1.firebasedatabase.app/
- **Firestore Collections**:
  - `Profile/{userId}` - User profiles
  - `Profile/{userId}/Sites/{siteId}` - Sites (subcollection)
- **Storage Paths**:
  - `users/{userId}/profile.jpg` - Profile images
  - `users/{userId}/signature.jpg` - Signatures
  - `sites/{ownerUID}/{siteId}/site.jpg` - Site images

## Architecture
- **Offline-First**: Local SQLite (Drift) database is source of truth
- **Sync Service**: Background sync triggered from MainMenu
- **Single Device Login**: Enforced via Realtime Database sessions
- **Instant Image Ops**: Pick/Remove are independent of Save button

## Testing Environment
- **Clean Installs**: Test with fresh iOS devices, no existing app data
- **Clean Firebase**: Start with empty Firebase collections for testing
- **Auth Persistence**: iOS Keychain may persist auth even after app deletion