# SnagSnapper Project Rules

## Project Overview
- **Package Name**: uk.co.productiveapps.snagsnapper
- **Minimum SDK Versions**: 
  - Android: 25
  - iOS: 14.0

## Development Guidelines

### 1. Dependency Management
- Always keep dependencies at their latest stable versions
- Remove outdated or discontinued packages
- Run `flutter pub upgrade --major-versions` for major updates
- Verify compatibility after updates

### 2. Code Standards
- Follow existing code patterns and conventions
- Use singleton patterns where established (e.g., GoogleSignIn.instance)
- Maintain consistent error handling approaches
- Preserve existing file structure

### 3. Build Configuration
- **Android Gradle Plugin**: 8.3.0
- **Kotlin Version**: 2.0.0 (compatible with R8)
- **Gradle Wrapper**: 8.5
- **Supported ABIs**: arm64-v8a, armeabi-v7a, x86_64 (no x86)

### 4. Testing Requirements
- Run `flutter analyze` before commits
- Check for compilation warnings and errors
- Run lint and type checking when available

### 5. Version Control
- Only commit when explicitly requested
- Create meaningful commit messages

## Project-Specific Rules

### Add your custom rules below:
<!-- Add any specific rules or guidelines for this project -->
- Always use TDD approach! Write tests before you write code
- Always try to implement the simplest fix, never overcomplicate before asking me
- Always add thorough comments on code
- Always add guarded debug statements at critical points in development mode and Firebase Crashlytics in production mode with breadcrumbs
- Never assume anything, always check or ask for clarification before making strategic decisions