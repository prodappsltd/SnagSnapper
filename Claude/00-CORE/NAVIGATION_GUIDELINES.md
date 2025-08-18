# App-Wide Navigation Guidelines

## Core Principle: Forward Flow
**After any save/submit action, navigate to the next logical screen, not stay on the current screen.**

## Navigation Rules

### 1. Save Actions
**Rule**: When user saves data, navigate to the appropriate next screen.

#### Examples:
- **Profile Save** → Navigate back to previous screen (Main Menu/Settings)
- **Site Creation** → Navigate to Site Details screen
- **Snag Creation** → Navigate back to Snags List
- **Settings Save** → Navigate back to previous screen

```dart
// ✅ CORRECT - Navigate after save
Future<void> _saveData() async {
  final success = await saveToDatabase();
  if (success) {
    showSuccessMessage('Saved successfully');
    Navigator.pop(context); // or pushReplacement
  }
}

// ❌ WRONG - Staying on same screen
Future<void> _saveData() async {
  final success = await saveToDatabase();
  if (success) {
    showSuccessMessage('Saved successfully');
    // User stays on same screen - confusing!
  }
}
```

### 2. New User Flow
**Rule**: New users cannot go back until required setup is complete.

- **First Profile Creation** → No back button, must complete
- **After Profile Save** → Navigate to Main Menu (remove all previous routes)

```dart
// New user profile creation
Navigator.pushNamedAndRemoveUntil(
  context,
  '/mainMenu',
  (route) => false, // Remove all previous routes
);
```

### 3. Edit Flow
**Rule**: Existing users can go back and should return after save.

```dart
// Existing user editing profile
if (isExistingUser) {
  Navigator.pop(context); // Return to previous screen
}
```

### 4. Success Feedback
**Rule**: Show brief success message before navigation.

```dart
// Show success, then navigate
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Saved successfully')),
);

// Small delay to let user see message
Future.delayed(Duration(milliseconds: 500), () {
  Navigator.pop(context);
});
```

### 5. Error Handling
**Rule**: On error, stay on current screen to allow retry.

```dart
if (error) {
  showErrorMessage('Failed to save. Please try again.');
  // Stay on screen for user to fix and retry
} else {
  // Success - navigate away
  Navigator.pop(context);
}
```

## Screen-Specific Navigation

### Profile Screen
- **New User Save** → Main Menu (no back)
- **Edit Profile Save** → Previous screen (Main Menu/Settings)
- **Cancel** → Previous screen (only for existing users)

### Site Creation
- **Save Site** → Site Details or Sites List
- **Cancel** → Sites List

### Snag Creation
- **Save Snag** → Snags List
- **Save & Add Another** → Clear form, stay on screen
- **Cancel** → Snags List

### Settings
- **Save Settings** → Previous screen
- **Cancel** → Previous screen (discard changes)

## Implementation Checklist

When implementing any form/edit screen:

- [ ] Determine if user is new or existing
- [ ] Hide back button for mandatory flows
- [ ] Navigate after successful save
- [ ] Show success feedback before navigation
- [ ] Handle errors by staying on screen
- [ ] Clear form data after navigation
- [ ] Remove routes appropriately for one-way flows

## User Experience Benefits

1. **Clear Progress**: Users understand they've moved forward
2. **No Confusion**: No wondering "did it save?"
3. **Efficient Workflow**: Natural progression through tasks
4. **Prevents Duplicate Saves**: Can't accidentally save twice
5. **Clean State**: Each screen visit is fresh

## Anti-Patterns to Avoid

❌ **Don't**:
- Stay on form after save
- Show "Saved!" but leave user on same screen
- Clear form but stay on screen (except "Save & Add Another")
- Navigate without feedback
- Allow back button during mandatory setup

✅ **Do**:
- Navigate after save
- Show brief success message
- Return to logical previous screen
- Block back during setup
- Provide clear navigation path