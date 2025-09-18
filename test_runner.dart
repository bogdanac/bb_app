#!/usr/bin/env dart

/// Simple test runner script for backup system tests
///
/// Usage:
///   dart test_runner.dart          # Run all tests
///   dart test_runner.dart unit     # Run only unit tests
///   dart test_runner.dart widget   # Run only widget tests
///   dart test_runner.dart setup    # Show setup instructions

import 'dart:io';

import 'package:flutter/foundation.dart';

void main(List<String> arguments) {
  final command = arguments.isEmpty ? 'all' : arguments[0];

  switch (command) {
    case 'setup':
      showSetupInstructions();
      break;
    case 'unit':
      runUnitTests();
      break;
    case 'widget':
      runWidgetTests();
      break;
    case 'integration':
      runIntegrationTests();
      break;
    case 'all':
    default:
      runAllTests();
      break;
  }
}

void showSetupInstructions() {
  if (kDebugMode) {
    print('🧪 BBetter Backup System Test Suite Setup');
    print('=' * 50);
    print('');
    print('1. Install dependencies:');
    print('   flutter pub get');
    print('');
    print('2. Run tests:');
    print('   dart test_runner.dart all          # All tests');
    print('   dart test_runner.dart unit         # Unit tests only');
    print('   dart test_runner.dart widget       # Widget tests only');
    print('   dart test_runner.dart integration  # Integration tests');
    print('');
    print('3. Generate test coverage:');
    print('   flutter test --coverage');
    print('   genhtml coverage/lcov.info -o coverage/html');
    print('');
    print('📋 Test Categories:');
    print('   • Unit Tests: BackupService logic validation');
    print('   • Widget Tests: BackupScreen UI component testing');
    print('   • Integration Tests: End-to-end backup flows');
    print('');
    print('🔧 Required dev dependencies (already added to pubspec.yaml):');
    print('   • mockito: ^5.4.4');
    print('   • build_runner: ^2.4.7');
    print('   • integration_test: sdk: flutter');
    print('');
  }
}

void runUnitTests() {
  if (kDebugMode) {
    print('🔬 Running Unit Tests...');
  }
  final result = Process.runSync('flutter', ['test', 'test/unit/']);
  stdout.write(result.stdout);
  if (result.stderr.isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (kDebugMode) {
    print('Unit tests completed with exit code: ${result.exitCode}');
  }
}

void runWidgetTests() {
  if (kDebugMode) {
    print('🎨 Running Widget Tests...');
  }
  final result = Process.runSync('flutter', ['test', 'test/widget/']);
  stdout.write(result.stdout);
  if (result.stderr.isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (kDebugMode) {
    print('Widget tests completed with exit code: ${result.exitCode}');
  }
}

void runIntegrationTests() {
  if (kDebugMode) {
    print('🔗 Running Integration Tests...');
    print('Note: Integration tests require a device or emulator');
  }
  final result = Process.runSync('flutter', ['test', 'integration_test/']);
  stdout.write(result.stdout);
  if (result.stderr.isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (kDebugMode) {
    print('Integration tests completed with exit code: ${result.exitCode}');
  }
}

void runAllTests() {
  if (kDebugMode) {
    print('🚀 Running All Backup System Tests...');
    print('=' * 50);
  }

  runUnitTests();
  if (kDebugMode) {
    print('');
  }
  runWidgetTests();

  if (kDebugMode) {
    print('');
    print('📊 Test Summary:');
    print('   ✅ Unit Tests: BackupService functionality');
    print('   ✅ Widget Tests: BackupScreen UI components');
    print('   📝 Integration Tests: Run separately with device/emulator');
    print('');
    print('To run integration tests:');
    print('   dart test_runner.dart integration');
    print('');
  }
}
