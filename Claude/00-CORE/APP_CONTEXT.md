# SnagSnapper App Context

## App Status
- **Development Stage**: This is a DEVELOPMENT app, not production
- **No Legacy Users**: There are NO existing/legacy users to migrate
- **No Backward Compatibility Required**: We can make breaking changes as needed

## Key Decisions
1. **Profile Collection**: Always use 'Profile' (capital P), never 'profiles' or 'users'
2. **No Legacy Support**: Do not add code for backward compatibility with old data structures
3. **Clean Slate**: This app has a fresh Firebase instance with no historical data

## Firebase Configuration
- **Region**: Europe-west1 (not US-central)
- **Realtime Database URL**: https://snagsnapperpro-default-rtdb.europe-west1.firebasedatabase.app/
- **Collections Used**:
  - `Profile` - User profiles (NOT 'profiles' or 'users')
  - `Sites` - Construction sites
  - `Snags` - Issues/defects

## Architecture
- **Offline-First**: Local SQLite database is source of truth
- **Sync Service**: Handles background synchronization with Firebase
- **Single Device Login**: Enforced via Realtime Database sessions

## Testing Environment
- **Clean Installs**: Test with fresh iOS devices, no existing app data
- **Clean Firebase**: Start with empty Firebase collections for testing
- **Auth Persistence**: iOS Keychain may persist auth even after app deletion