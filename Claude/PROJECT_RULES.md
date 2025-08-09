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

### Session Context Files
When starting a new session, review these key files:
1. **lib/Constants/validation_rules.dart** - Contains validation rules and session context
   - This file has references to other important files
   - Contains decisions made and pending decisions
   - Synchronization requirements between UI and Firebase
2. **Claude/PRD.md** - Product Requirements Document
   - Complete product specifications and features
   - User personas and use cases
   - Technical architecture documentation
   - Must be kept in sync with implementation changes
3. **Claude/IMAGE_SERVICE_PLAN.md** - Centralized image service architecture
   - Complete plan for image handling across the app
   - Implementation phases and specifications
   - Cost analysis and optimization strategies
4. **Claude/IMAGE_IMPLEMENTATION_GUIDE.md** - Detailed implementation guide for image handling
   - Complete flow documentation with edge cases
   - Offline-first architecture details
   - State management and error handling
   - Code examples and implementation checklist
5. **Claude/ACHIEVEMENTS.md** - Development achievements and progress
   - Consolidated report of completed work
   - Technical decisions and implementations
   - Bug fixes and improvements made

### Add your custom rules below:
<!-- Add any specific rules or guidelines for this project -->
- Always use TDD approach! Write tests before you write code
- Always try to implement the simplest fix, never overcomplicate before asking me
- Always add thorough comments on code
- Always add guarded debug statements at critical points in development mode and Firebase Crashlytics in production mode with breadcrumbs
- Always add guarded debug statements in ALL error handling blocks (catch blocks, error conditions, etc.) to log the error details before showing error messages to users
- Never assume anything, always check or ask for clarification before making strategic decisions
- Always work on the agreed scope and if you find further scope of improvement while working on the agreed scope, you will clarify with me first before any steps to resolve it
- Always act as a professional software developer incorporating good practices and SOLID programming principles
- **CRITICAL: Offline-First Design** - The app must be fully functional offline as it will be used in areas with poor/no internet connectivity. All features must work offline with sync when connection is available
- **BOTTOM LINE: Offline First, Sync in Background** - Every feature must work completely offline. Network operations are background tasks only. Users should NEVER wait for network operations. Local storage provides immediate response, background sync maintains eventual consistency
- **Memory Efficiency** - Keep memory usage minimal. Avoid storing duplicate data, clean up resources promptly, use efficient data structures
- **Performance Priority** - Prioritize app responsiveness and speed. Users should never wait for network operations. All network tasks should be non-blocking background operations
- **CRITICAL: Cost Efficiency** - Minimize Firebase usage to reduce operational costs. Only sync when absolutely necessary. Batch operations where possible. Avoid unnecessary reads/writes. Cache aggressively to prevent repeated downloads
- **SCOPE LIMITATION** - Only profile-related code is currently in scope for modifications. Other classes will be added to scope as development progresses. The architecture successfully implemented in profile will be extended to other classes when they come into scope
- **NO BACKWARD COMPATIBILITY NEEDED** - This is a new app with no existing users. No backward compatibility code is needed. Remove any legacy code paths without hesitation
- **KEEP DOCUMENTATION IN SYNC** - Always update PRD.md when making significant architectural changes or feature implementations so documentation stays current with the actual implementation

### Testing Guidelines

#### Test Organization
- When testing routing configuration, test the routing logic directly rather than instantiating the full app
- Avoid instantiating widgets that trigger complex initialization in unit tests
- Use simple unit tests for logic verification and widget tests for UI behavior
- If a test requires too many mocks, consider if it's testing at the wrong level of abstraction

#### Writing Effective Tests
- **Test behavior, not implementation**: Focus on WHAT the code does, not HOW it does it
- **One assertion per test**: Each test should verify one specific behavior
- **Use descriptive test names**: Test names should describe what scenario is being tested and expected outcome
- **Follow AAA pattern**: Arrange (setup), Act (execute), Assert (verify)
- **Keep tests independent**: Each test should be able to run in isolation without depending on other tests
- **Use test fixtures sparingly**: Prefer explicit setup in each test for clarity
- **Mock at the boundaries**: Mock external dependencies (Firebase, network, etc.) but not internal logic

#### Test Types and When to Use Them
- **Unit Tests**: For pure functions, business logic, data transformations
- **Widget Tests**: For UI components, user interactions, widget state management
- **Integration Tests**: For complete user journeys, critical paths only (they're slow)
- **Golden Tests**: For visual regression of complex UI layouts

#### Common Testing Anti-patterns to Avoid
- **Testing private methods**: Test through public API instead
- **Over-mocking**: If you're mocking everything, you're not testing anything
- **Brittle tests**: Tests that break with minor refactoring indicate testing implementation details
- **Slow tests**: Keep unit tests under 100ms, widget tests under 1s
- **Flaky tests**: Non-deterministic tests are worse than no tests
- **Testing framework code**: Don't test Flutter/Dart framework behavior

#### Performance Considerations
- **Run tests in parallel**: Use `flutter test --concurrency=10` for faster execution
- **Use `testWidgets` with `pumping` efficiently**: Avoid unnecessary `pumpAndSettle()` calls
- **Minimize test setup**: Create helper functions for common test setup
- **Skip animations in tests**: Use `WidgetTester.binding.disableAnimations = true`

#### Test Maintenance
- **Update tests with code changes**: Tests are documentation and must stay current
- **Remove redundant tests**: If multiple tests verify the same behavior, keep the clearest one
- **Refactor tests**: Apply same code quality standards to test code
- **Monitor test coverage**: Aim for 80%+ coverage on business logic, but quality > quantity

#### Debugging Failed Tests
- **Use `debugDumpApp()` in widget tests**: Shows widget tree when test fails
- **Add `printOnFailure()` for debugging**: Prints message only when test fails
- **Run single test for debugging**: `flutter test --name "specific test name"`
- **Use `--dart-define=DEBUG_TEST=true`**: For conditional debug output in tests