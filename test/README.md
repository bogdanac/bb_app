# BBetter Backup System Test Suite

This comprehensive test suite validates all aspects of the backup and restore functionality in the BBetter app.

## 🗂️ Test Structure

```
test/
├── unit/                    # Unit tests for individual components
│   └── backup_service_test.dart
├── widget/                  # Widget tests for UI components
│   └── backup_screen_test.dart
├── integration/             # Integration tests for complete flows
│   └── backup_flow_test.dart
├── test_config.dart         # Shared test utilities and configuration
├── run_all_tests.dart       # Test runner for all unit/widget tests
└── README.md               # This file
```

## 🧪 Test Categories

### Unit Tests (`test/unit/`)

**BackupService Tests** - Core functionality validation:
- ✅ **Threshold Management**: Custom overdue warning thresholds (1-30 days)
- ✅ **Status Calculations**: Accurate overdue detection for manual/auto/cloud backups
- ✅ **Data Categorization**: Proper sorting of SharedPreferences data
- ✅ **Import Validation**: Version compatibility and data integrity checks
- ✅ **Security**: External storage only, no app-internal paths
- ✅ **Error Handling**: Graceful handling of corrupted data

### Widget Tests (`test/widget/`)

**BackupScreen Tests** - UI component validation:
- ✅ **Status Display**: Shows manual, auto, and cloud backup dates
- ✅ **Warning System**: Orange warnings for overdue backups
- ✅ **Threshold Controls**: +/- buttons for adjusting warning threshold
- ✅ **Auto Backup Toggle**: Settings persistence
- ✅ **Dynamic Messages**: Warning text updates with threshold changes
- ✅ **Accessibility**: Screen reader compatibility
- ✅ **Responsive Design**: Works on different screen sizes

### Integration Tests (`test/integration/`)

**Complete Flow Tests** - End-to-end validation:
- ✅ **Backup/Restore Cycle**: Export → Clear data → Import → Verify
- ✅ **Warning System**: Home screen icon appears when backups overdue
- ✅ **Settings Persistence**: Threshold and toggle settings survive app restart
- ✅ **Performance**: Threshold changes don't reload all data
- ✅ **Error Scenarios**: Graceful handling of permission denied, corrupted files
- ✅ **Real Device Testing**: Actual file system operations

## 🚀 Running Tests

### Run All Unit/Widget Tests
```bash
flutter test test/run_all_tests.dart
```

### Run Specific Test Categories
```bash
# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# Specific test file
flutter test test/unit/backup_service_test.dart
```

### Run Integration Tests
```bash
# Integration tests work without device (focused on widget integration)
flutter test test/integration/backup_flow_test.dart
```

### Run All Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🔧 Test Configuration

### Dependencies Required
Add these to your `pubspec.yaml` dev_dependencies:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.6
  integration_test:
    sdk: flutter
```

### Generate Mocks
```bash
flutter packages pub run build_runner build
```

### Mock Setup
Tests use `SharedPreferences.setMockInitialValues({})` to simulate different app states without affecting real data.

## 📊 Test Coverage

### Critical Backup Functionality ✅
- **Data Safety**: Backups only go to external storage (survive uninstall)
- **Accurate Timestamps**: Auto backups include correct creation time
- **Validation**: Comprehensive import validation prevents corruption
- **User Experience**: Clear warnings and error messages

### Edge Cases Covered ✅
- **Storage Permissions**: Denied permissions handled gracefully
- **Corrupted Data**: Invalid timestamps and malformed JSON
- **Version Compatibility**: Prevents restoring incompatible backups
- **Performance**: Efficient threshold changes
- **Accessibility**: Screen reader support

### Error Scenarios ✅
- Network failures during cloud operations
- Insufficient storage space
- Malformed backup files
- App-internal storage fallback prevention
- SharedPreferences corruption

## 🐛 Test Debugging

### Common Issues

**Tests failing due to async operations:**
```dart
await tester.pumpAndSettle(); // Wait for all animations/futures
await tester.pump(Duration(seconds: 1)); // Wait specific time
```

**Mock SharedPreferences not working:**
```dart
SharedPreferences.setMockInitialValues({}); // Call in setUp()
```

**Integration tests require device:**
```bash
flutter emulators --launch <emulator_name>
flutter test integration_test/backup_flow_test.dart
```

### Test Data Generation
Use `BackupTestConfig.createValidBackupData()` and related helpers to generate consistent test data.

## 🎯 Test Strategy

### What We Test
1. **Business Logic**: All backup/restore calculations and validations
2. **User Interface**: All interactive elements and visual feedback
3. **Data Safety**: External storage, validation, error handling
4. **Performance**: No unnecessary operations or UI freezes
5. **Accessibility**: Screen reader and keyboard navigation
6. **Real-world Scenarios**: Actual device file operations

### What We Don't Test
- Platform-specific file system implementation details
- Third-party library internals (SharedPreferences, file_picker)
- Network operations to cloud services
- iOS-specific functionality (Android-only app)

## 📈 Continuous Integration

### GitHub Actions Example
```yaml
- name: Run backup system tests
  run: |
    flutter test test/unit/
    flutter test test/widget/

- name: Run integration tests
  run: |
    flutter test integration_test/ --device-id=emulator
```

### Coverage Requirements
- **Unit Tests**: >90% coverage for BackupService
- **Widget Tests**: All user interactions tested
- **Integration Tests**: All critical user flows validated

## 🔄 Test Maintenance

### When to Update Tests
- ✅ Adding new backup features
- ✅ Changing data categorization logic
- ✅ Modifying validation rules
- ✅ UI layout changes
- ✅ Error message updates

### Test Review Checklist
- [ ] All critical paths tested
- [ ] Error scenarios covered
- [ ] Performance implications validated
- [ ] Accessibility requirements met
- [ ] Real device testing completed

---

## 📞 Support

For test-related questions or issues:
1. Check test output for specific failure details
2. Verify mock setup matches test expectations
3. Ensure device/emulator for integration tests
4. Review test coverage reports for gaps

**The backup system is mission-critical for user data safety. These tests ensure reliability, performance, and excellent user experience.**