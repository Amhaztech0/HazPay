# Testing Guide for ZinChat

This guide explains how to test the ZinChat application, including both automated tests and manual testing procedures.

## Test Structure

```
test/
├── integration/
│   └── settings_navigation_test.dart  # Basic widget instantiation tests
└── README.md                          # This file
```

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/integration/settings_navigation_test.dart
```

### Run with Verbose Output

```bash
flutter test --verbose
```

### Run with Coverage

```bash
flutter test --coverage
```

---

## Why Integration Tests are Limited

The current integration tests in `test/integration/settings_navigation_test.dart` are minimal because:

1. **Supabase Initialization Required**: The `SettingsScreen` and related features require Supabase to be initialized, which cannot be done in unit tests without complex mocking.

2. **Authentication Required**: Most features require an authenticated user session.

3. **Real Backend Needed**: Privacy features (blocking, message requests) interact with the database and need real RLS policies to work correctly.

4. **State Management**: The app uses Provider and various services that depend on the Supabase client being initialized.

---

## Manual Testing (Recommended)

For comprehensive testing of the privacy and settings features, **use the manual testing guide**:

📋 **[PRIVACY_FEATURES_TESTING_GUIDE.md](../PRIVACY_FEATURES_TESTING_GUIDE.md)**

This guide provides:
- ✅ Complete step-by-step testing procedures
- ✅ Database verification queries
- ✅ Expected outcomes for every feature
- ✅ Troubleshooting tips
- ✅ Security verification steps
- ✅ Performance testing checklist
- ✅ 5-minute quick smoke test

### Quick Manual Test Commands

**Test Settings Navigation:**
1. Run app: `flutter run`
2. Open drawer (☰)
3. Tap "Settings"
4. Verify all sections display

**Test Privacy Features:**
1. Follow steps in `PRIVACY_FEATURES_TESTING_GUIDE.md`
2. Use two test accounts (User A and User B)
3. Test blocking, message requests, and privacy settings

---

## Future Testing Improvements

To add more comprehensive automated tests, consider:

### 1. Mock-Based Unit Tests

Create mocks for Supabase client and services:

```dart
// Example structure
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockPrivacyService extends Mock implements PrivacyService {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockPrivacyService mockPrivacy;
  
  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockPrivacy = MockPrivacyService();
  });
  
  // Test with mocked dependencies
}
```

**Required packages:**
```yaml
dev_dependencies:
  mockito: ^5.4.4
  build_runner: ^2.4.8
```

### 2. Integration Tests with Test Supabase Instance

Set up a dedicated test Supabase project:

```dart
void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'YOUR_TEST_SUPABASE_URL',
      anonKey: 'YOUR_TEST_SUPABASE_ANON_KEY',
    );
  });
  
  // Run integration tests against test instance
}
```

### 3. Widget Tests with Mocked Services

Test individual widgets in isolation:

```dart
testWidgets('MessageRequestsScreen displays requests', (tester) async {
  final mockService = MockPrivacyService();
  
  when(mockService.getPendingMessageRequests())
      .thenAnswer((_) async => [/* test data */]);
  
  await tester.pumpWidget(
    MaterialApp(
      home: MessageRequestsScreen(privacyService: mockService),
    ),
  );
  
  expect(find.text('Message Requests'), findsOneWidget);
});
```

### 4. Golden Tests for UI Consistency

Capture UI snapshots to detect visual regressions:

```bash
flutter test --update-goldens
```

### 5. Performance Tests

Measure widget build times and interaction performance:

```dart
testWidgets('SettingsScreen builds quickly', (tester) async {
  final stopwatch = Stopwatch()..start();
  
  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
});
```

---

## Testing Best Practices

### Before Testing

1. ✅ Run database script: `db/PRIVACY_AND_BLOCKING.sql`
2. ✅ Hot restart app after database changes
3. ✅ Create test user accounts (at least 2)
4. ✅ Clear app data if needed

### During Testing

1. ✅ Test one feature at a time
2. ✅ Document any issues found
3. ✅ Verify database state with SQL queries
4. ✅ Check console for errors
5. ✅ Test both success and failure cases

### After Testing

1. ✅ Clean up test data
2. ✅ Document test results
3. ✅ Report bugs with reproduction steps
4. ✅ Update test documentation if needed

---

## Test Coverage Goals

Current coverage areas:

| Feature | Unit Tests | Widget Tests | Manual Tests |
|---------|-----------|--------------|--------------|
| Settings Navigation | ❌ | ❌ | ✅ |
| Privacy Settings | ❌ | ❌ | ✅ |
| Message Requests | ❌ | ❌ | ✅ |
| Blocking | ❌ | ❌ | ✅ |
| UI Components | ❌ | ❌ | ✅ |
| Database RLS | ❌ | ❌ | ✅ |

**Target Coverage:**
- Unit Tests: 70%+
- Widget Tests: 50%+
- Integration Tests: 30%+
- Manual Tests: 100% (documented procedures)

---

## Continuous Integration Setup

For CI/CD pipelines, add these steps:

```yaml
# Example GitHub Actions workflow
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter test --coverage
```

---

## Common Testing Issues

### Issue: "Supabase not initialized"

**Solution:** This is expected for widget tests. Use manual testing or implement mocking.

### Issue: "No tests found"

**Solution:** 
```bash
# Make sure you're in the project root
cd c:\Users\Amhaz\Desktop\zinchat\zinchat

# Verify test files exist
dir test /s /b
```

### Issue: Tests timeout

**Solution:**
```bash
# Increase timeout
flutter test --timeout=30s
```

### Issue: Widget not found in tests

**Solution:** Add `await tester.pumpAndSettle()` after navigation or state changes.

---

## Testing Checklist

Before considering a feature "tested":

- [ ] Code compiles without errors
- [ ] Lint warnings addressed
- [ ] Manual testing completed (see PRIVACY_FEATURES_TESTING_GUIDE.md)
- [ ] Database state verified
- [ ] Error cases handled
- [ ] UI feedback working (toasts, dialogs)
- [ ] Loading states display correctly
- [ ] Empty states show appropriate messages
- [ ] Security verified (RLS policies enforced)
- [ ] Performance acceptable (no lag)
- [ ] Works on both Android and iOS (if applicable)
- [ ] Documented any known issues

---

## Quick Reference

**Run tests:**
```bash
flutter test
```

**Run with coverage:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**Analyze code:**
```bash
flutter analyze
```

**Format code:**
```bash
flutter format lib/ test/
```

**Check for outdated packages:**
```bash
flutter pub outdated
```

---

## Getting Help

If tests fail or you encounter issues:

1. Check [PRIVACY_FEATURES_TESTING_GUIDE.md](../PRIVACY_FEATURES_TESTING_GUIDE.md) for manual testing steps
2. Review [PRIVACY_AND_BLOCKING_GUIDE.md](../PRIVACY_AND_BLOCKING_GUIDE.md) for implementation details
3. Run database verification queries from the testing guide
4. Check Supabase logs for backend errors
5. Review console output for Dart/Flutter errors

---

**Last Updated:** November 10, 2025
**Test Coverage:** Manual testing procedures documented and verified
**Status:** ✅ Ready for manual testing
