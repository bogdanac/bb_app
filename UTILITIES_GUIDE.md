# App Utilities Guide

This guide documents the centralized utilities created to reduce code duplication and improve consistency across the app.

## 📦 Available Utilities

### 1. SnackBarUtils (`lib/shared/snackbar_utils.dart`)

Centralized SnackBar management for consistent messaging.

```dart
import 'package:bb_app/shared/snackbar_utils.dart';

// Success message (green)
SnackBarUtils.showSuccess(context, 'Task completed successfully!');

// Error message (red)
SnackBarUtils.showError(context, 'Failed to save data');

// Info message (grey)
SnackBarUtils.showInfo(context, 'Data refreshed');

// Warning message (orange)
SnackBarUtils.showWarning(context, 'Battery low');

// Loading message (with spinner)
SnackBarUtils.showLoading(context, 'Saving...');
// Must hide manually:
SnackBarUtils.hide(context);

// Custom color
SnackBarUtils.showCustom(
  context,
  'Custom message',
  backgroundColor: Colors.blue,
  icon: Icon(Icons.info),
);
```

### 2. DateFormatUtils (`lib/shared/date_format_utils.dart`)

Romanian date formatting utilities.

```dart
import 'package:bb_app/shared/date_format_utils.dart';

final date = DateTime(1993, 11, 27);

// Romanian formats
DateFormatUtils.formatShort(date);              // "27 nov"
DateFormatUtils.formatLong(date);               // "27 nov 1993"
DateFormatUtils.formatFull(date);               // "27 noiembrie 1993"
DateFormatUtils.formatShortWithFullMonth(date); // "27 noiembrie"

// Time formats
DateFormatUtils.formatTime24(date);             // "14:30"
DateFormatUtils.formatTime12(date);             // "2:30 PM"
DateFormatUtils.formatDateTime(date);           // "27 nov 1993, 14:30"

// Date ranges
DateFormatUtils.formatRange(start, end);        // "27 nov - 3 dec"

// Relative dates
DateFormatUtils.formatRelative(date);           // "azi", "ieri", "mâine", "acum 3 zile"

// Numeric formats
DateFormatUtils.formatNumeric(date);            // "27/11/1993"
DateFormatUtils.formatShortNumeric(date);       // "27/11"

// Day of week
DateFormatUtils.getDayOfWeek(date);             // "sâmbătă"
DateFormatUtils.formatWithDayOfWeek(date);      // "sâmbătă, 27 nov"

// Duration
DateFormatUtils.formatDuration(duration);       // "2h 30m"

// Utility functions
DateFormatUtils.stripTime(date);                // Remove time, keep date only
DateFormatUtils.isSameDay(date1, date2);        // Check if same day
DateFormatUtils.formatISO(date);                // ISO 8601 string
DateFormatUtils.parseISO(isoString);            // Parse ISO string
```

### 3. DialogUtils (`lib/shared/dialog_utils.dart`)

Comprehensive dialog utilities for common scenarios.

```dart
import 'package:bb_app/shared/dialog_utils.dart';

// Confirmation dialog
final confirmed = await DialogUtils.showConfirmation(
  context,
  title: 'Confirmare',
  message: 'Sigur vrei să continui?',
  confirmText: 'Da',
  cancelText: 'Nu',
);

// Delete confirmation (pre-configured)
final delete = await DialogUtils.showDeleteConfirmation(
  context,
  itemName: 'Task',
);

// Info dialog
await DialogUtils.showInfo(
  context,
  title: 'Informație',
  message: 'Operațiunea a fost completată',
);

// Error dialog
await DialogUtils.showError(
  context,
  message: 'A apărut o eroare',
);

// Success dialog
await DialogUtils.showSuccess(
  context,
  message: 'Salvare reușită!',
);

// Warning dialog
await DialogUtils.showWarning(
  context,
  message: 'Baterie scăzută',
);

// Loading dialog (must dismiss manually with Navigator.pop)
DialogUtils.showLoading(context, message: 'Se încarcă...');
// Later:
Navigator.of(context).pop();

// Text input dialog
final name = await DialogUtils.showTextInput(
  context,
  title: 'Nume nou',
  hintText: 'Introdu numele',
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Numele este obligatoriu';
    }
    return null;
  },
);

// Choice dialog
final choice = await DialogUtils.showChoice<String>(
  context,
  title: 'Alege o opțiune',
  options: [
    ChoiceOption(
      label: 'Opțiunea 1',
      value: 'option1',
      description: 'Descriere opțiune 1',
      icon: Icon(Icons.star),
    ),
    ChoiceOption(
      label: 'Opțiunea 2',
      value: 'option2',
      description: 'Descriere opțiune 2',
      icon: Icon(Icons.favorite),
    ),
  ],
  cancelText: 'Anulează',
);

// Custom dialog with multiple actions
final result = await DialogUtils.showCustom<String>(
  context,
  title: 'Alege acțiunea',
  content: Text('Ce vrei să faci?'),
  actions: [
    DialogAction(label: 'Șterge', value: 'delete', color: Colors.red),
    DialogAction(label: 'Editează', value: 'edit'),
    DialogAction(label: 'Anulează', value: 'cancel'),
  ],
);
```

### 4. AppStyles (`lib/theme/app_styles.dart`)

Centralized UI styles for consistency.

```dart
import 'package:bb_app/theme/app_styles.dart';

// Border Radius
Container(
  decoration: BoxDecoration(
    borderRadius: AppStyles.borderRadiusMedium, // Most common: 12
  ),
);

// Available radii:
AppStyles.borderRadiusSmall    // 8
AppStyles.borderRadiusMedium   // 12
AppStyles.borderRadiusLarge    // 16
AppStyles.borderRadiusXLarge   // 20

// Or just the values:
AppStyles.radiusMedium         // 12.0

// Shadows
Container(
  decoration: BoxDecoration(
    boxShadow: AppStyles.cardShadow,  // Standard shadow
  ),
);

// Padding
Padding(
  padding: AppStyles.edgeInsetsMedium, // 12 all around
);

// Available padding:
AppStyles.paddingSmall      // 8
AppStyles.paddingMedium     // 12
AppStyles.paddingLarge      // 16
AppStyles.paddingXLarge     // 20
AppStyles.paddingXXLarge    // 24

// Card Decoration
Container(
  decoration: AppStyles.cardDecoration(),
);

Container(
  decoration: AppStyles.cardDecorationWithBorder(
    borderColor: Colors.red,
  ),
);

// Text Styles
Text('Heading', style: AppStyles.headingLarge);
Text('Body', style: AppStyles.bodyMedium);
Text('Caption', style: AppStyles.caption);

// Button Styles
ElevatedButton(
  style: AppStyles.elevatedButtonStyle(),
  onPressed: () {},
  child: Text('Click me'),
);

OutlinedButton(
  style: AppStyles.outlinedButtonStyle(),
  onPressed: () {},
  child: Text('Click me'),
);

// Input Decoration
TextField(
  decoration: AppStyles.inputDecoration(
    labelText: 'Name',
    hintText: 'Enter your name',
  ),
);

// Dividers
AppStyles.dividerThin
AppStyles.dividerMedium

// Animation Durations
AnimatedContainer(
  duration: AppStyles.animationDurationNormal,
  curve: AppStyles.animationCurve,
);
```

### 5. PreferencesService (`lib/shared/preferences_service.dart`)

Centralized SharedPreferences access (optional - existing code still works).

```dart
import 'package:bb_app/shared/preferences_service.dart';

// Initialize once in main()
await PreferencesService().init();

// Quick access methods
final service = PreferencesService();
final name = await service.getString('name');
await service.setString('name', 'John');

// Or get the prefs instance
final prefs = await service.prefs;
final value = prefs.getString('key');

// NOTE: This is optional! Existing code using SharedPreferences.getInstance()
// directly will continue to work without any changes.
```

## 🎯 Migration Guide

### Replace SnackBars

**Before:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Success!'),
    backgroundColor: AppColors.successGreen,
    duration: Duration(seconds: 3),
  ),
);
```

**After:**
```dart
SnackBarUtils.showSuccess(context, 'Success!');
```

### Replace Date Formatting

**Before:**
```dart
final formatted = DateFormat('MMM d').format(date);
```

**After:**
```dart
final formatted = DateFormatUtils.formatShort(date); // "27 nov"
```

### Replace Border Radius

**Before:**
```dart
borderRadius: BorderRadius.circular(12)
```

**After:**
```dart
borderRadius: AppStyles.borderRadiusMedium
```

### Replace Dialogs

**Before:**
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: AppColors.dialogBackground,
    title: Text('Confirmare'),
    content: Text('Sigur?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('Nu'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text('Da'),
      ),
    ],
  ),
);
```

**After:**
```dart
final confirmed = await DialogUtils.showConfirmation(
  context,
  title: 'Confirmare',
  message: 'Sigur?',
);
```

## ✅ Benefits

1. **Less Code**: Reduces 50-70% of boilerplate for common UI patterns
2. **Consistency**: All SnackBars, dialogs, and dates look the same
3. **Easy Updates**: Change styling in one place, affects entire app
4. **Romanian Support**: Built-in Romanian date formatting
5. **Type Safety**: Strong typing with generics for dialogs
6. **Maintainability**: Easier to find and fix issues

## 📝 Notes

- All utilities are **backward compatible** - existing code continues to work
- Migrate gradually - no need to update everything at once
- PreferencesService is completely optional
- All utilities include comprehensive documentation in code

## 🚀 Future Improvements

Consider creating utilities for:
- Navigation patterns
- Form validation
- API error handling
- Loading states
- Animation presets
