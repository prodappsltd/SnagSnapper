# SnagSnapper Test Strategy

## Overview
This document explains the testing approach for SnagSnapper, particularly regarding authentication and navigation testing.

## Test Types

### 1. Unit Tests
- **Purpose**: Test individual functions and classes in isolation
- **Example**: `auth_test.dart` - Tests Auth service methods with mocked Firebase
- **Key Point**: Dependencies must be injectable for mocking

### 2. Widget Tests  
- **Purpose**: Test UI components and their interactions
- **Example**: `unified_auth_screen_test.dart` - Tests UI elements and form validation
- **Key Point**: Can mock providers but not internal class instantiations

### 3. Integration Tests
- **Purpose**: Test complete user flows with real dependencies
- **Example**: `startup_flow_integration_test.dart` - Tests app initialization
- **Key Point**: Should use real dependencies, not mocks

## Common Testing Issues and Solutions

### Issue 1: Mocking Internal Dependencies
**Problem**: Classes that create their own dependencies internally (e.g., `Auth()` in UnifiedAuthScreen) cannot be mocked in tests.

**Solution**: 
- For unit testing: Use dependency injection or testable versions
- For widget testing: Test UI behavior without testing the actual authentication
- For integration testing: Use real dependencies

### Issue 2: Navigation Testing
**Problem**: Testing actual navigation requires a complete app setup with routes.

**Solution**:
- Use simple navigation smoke tests that verify routes exist
- Document expected navigation behavior in tests
- Use integration tests for end-to-end navigation testing

### Issue 3: Firebase in Tests
**Problem**: Firebase operations fail in test environment without proper initialization.

**Solution**:
- Mock Firebase dependencies in unit tests
- Skip Firebase operations in widget tests
- Use Firebase emulators for integration tests (when needed)

## Test Organization

```
test/
├── unit/           # Isolated class/function tests
├── widget/         # UI component tests
├── integration/    # End-to-end flow tests
├── helpers/        # Test utilities and mocks
└── fixtures/       # Test data and assets
```

## Best Practices

1. **Follow TDD**: Write tests before implementation
2. **Keep tests simple**: Test one thing at a time
3. **Use descriptive names**: Test names should explain what they verify
4. **Avoid over-mocking**: Don't mock what you're testing
5. **Test behavior, not implementation**: Focus on what the code does, not how

## Navigation Test Strategy

For navigation testing, we use a three-pronged approach:

1. **Route Configuration Tests** (`route_configuration_test.dart`)
   - Verify all expected routes are defined
   - Check deprecated routes are removed
   - Ensure InitializationState routes are correct

2. **Navigation Smoke Tests** (`navigation_smoke_test.dart`)
   - Test that navigation links work
   - Verify form validation prevents navigation
   - Check UI state changes during navigation

3. **Widget Flow Tests** (`google_signin_flow_test.dart`)
   - Test UI elements are present and functional
   - Document expected navigation behavior
   - Verify UI state management

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget/unified_auth_screen_test.dart

# Run tests matching a pattern
flutter test --name "navigation"

# Run with coverage
flutter test --coverage
```

## Continuous Improvement

- Regularly review and update tests
- Add tests for bug fixes to prevent regression
- Keep test documentation up to date
- Monitor test coverage but focus on quality over quantity