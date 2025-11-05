# TaskRecurrence Refactoring - Quick Reference

## Where to Find Things Now

### Need to modify data structure or serialization?
**File:** `lib/Tasks/models/task_recurrence_model.dart`
- Add/remove fields
- Modify toJson/fromJson
- Update migration logic
- Change copyWith behavior

### Need to modify when tasks are due?
**File:** `lib/Tasks/services/recurrence_evaluator.dart`
- Change isDueOn logic
- Modify getNextDueDate calculations
- Update recurrence evaluation rules
- Fix date calculation bugs

### Need to change how recurrence is displayed?
**File:** `lib/Tasks/utils/recurrence_formatter.dart`
- Change getDisplayText output
- Update formatting strings
- Modify display rules
- Add new display formats

### Need to maintain backward compatibility?
**File:** `lib/Tasks/tasks_data_models.dart` (TaskRecurrence class)
- Ensure facade delegates correctly
- Add new public methods
- Maintain API compatibility

## File Structure

```
lib/Tasks/
├── models/
│   └── task_recurrence_model.dart      [DATA MODEL]
│       - TaskRecurrenceModel class
│       - RecurrenceType enum
│       - Serialization methods
│
├── services/
│   └── recurrence_evaluator.dart       [BUSINESS LOGIC]
│       - RecurrenceEvaluator class
│       - isDueOn() method
│       - getNextDueDate() method
│
├── utils/
│   └── recurrence_formatter.dart       [PRESENTATION]
│       - RecurrenceFormatter class
│       - getDisplayText() method
│
└── tasks_data_models.dart              [FACADE]
    - TaskRecurrence class (delegates to above)
    - Other task models (Task, TaskCategory, etc.)
```

## Common Tasks

### Adding a New Recurrence Type

1. **Add to enum** (task_recurrence_model.dart):
   ```dart
   enum RecurrenceType {
     daily, weekly, monthly, yearly,
     // ... existing types ...
     myNewType,  // Add here
   }
   ```

2. **Add business logic** (recurrence_evaluator.dart):
   ```dart
   static bool _isTypeDueOn(/* ... */) {
     switch (type) {
       // ... existing cases ...
       case RecurrenceType.myNewType:
         return _isMyNewTypeDueOn(recurrence, date);
     }
   }
   ```

3. **Add formatting** (recurrence_formatter.dart):
   ```dart
   static String getDisplayText(TaskRecurrenceModel recurrence) {
     switch (recurrence.type) {
       // ... existing cases ...
       case RecurrenceType.myNewType:
         return 'My New Type';
     }
   }
   ```

4. **No changes needed** to TaskRecurrence facade!

### Fixing a Display Bug

1. **Only modify:** `recurrence_formatter.dart`
2. Find the relevant `_format*` method
3. Update the display logic
4. Test independently

### Fixing a Date Calculation Bug

1. **Only modify:** `recurrence_evaluator.dart`
2. Find the relevant `_is*DueOn` or `_getNext*DueDate` method
3. Update the calculation logic
4. Test independently

### Adding a New Field

1. **Add to model** (task_recurrence_model.dart):
   ```dart
   class TaskRecurrenceModel {
     final int? myNewField;

     const TaskRecurrenceModel({
       // ... existing fields ...
       this.myNewField,
     });
   }
   ```

2. **Update copyWith** (task_recurrence_model.dart)
3. **Update toJson/fromJson** (task_recurrence_model.dart)
4. **Expose in facade** (tasks_data_models.dart):
   ```dart
   class TaskRecurrence {
     int? get myNewField => _model.myNewField;
   }
   ```

5. **Update constructor** (tasks_data_models.dart) if needed

## Testing Strategy

### Test Data Model Independently
```dart
test('serialization roundtrip', () {
  final model = TaskRecurrenceModel(types: [RecurrenceType.daily]);
  final json = model.toJson();
  final loaded = TaskRecurrenceModel.fromJson(json);
  expect(loaded.types, equals([RecurrenceType.daily]));
});
```

### Test Business Logic Independently
```dart
test('daily recurrence is due every day', () {
  final model = TaskRecurrenceModel(types: [RecurrenceType.daily]);
  expect(RecurrenceEvaluator.isDueOn(model, DateTime.now()), true);
});
```

### Test Presentation Independently
```dart
test('daily recurrence displays correctly', () {
  final model = TaskRecurrenceModel(types: [RecurrenceType.daily]);
  expect(RecurrenceFormatter.getDisplayText(model), equals('Daily'));
});
```

### Test Facade (Integration)
```dart
test('facade works end-to-end', () {
  final recurrence = TaskRecurrence(type: RecurrenceType.daily);
  expect(recurrence.isDueOn(DateTime.now()), true);
  expect(recurrence.getDisplayText(), equals('Daily'));
});
```

## Import Statements

### Use the facade (recommended for most code):
```dart
import 'package:bb_app/Tasks/tasks_data_models.dart';

// Use TaskRecurrence as before
final recurrence = TaskRecurrence(type: RecurrenceType.daily);
```

### Use components directly (for testing or specialized needs):
```dart
// Import specific components
import 'package:bb_app/Tasks/models/task_recurrence_model.dart';
import 'package:bb_app/Tasks/services/recurrence_evaluator.dart';
import 'package:bb_app/Tasks/utils/recurrence_formatter.dart';

// Use components independently
final model = TaskRecurrenceModel(types: [RecurrenceType.daily]);
final isDue = RecurrenceEvaluator.isDueOn(model, DateTime.now());
final text = RecurrenceFormatter.getDisplayText(model);
```

## Key Principles

1. **Data** (model) should not know about business logic or presentation
2. **Business Logic** (evaluator) should not know about presentation
3. **Presentation** (formatter) should not contain business logic
4. **Facade** (TaskRecurrence) maintains backward compatibility

## Benefits Summary

- **Find bugs faster:** Know exactly which file to check
- **Write tests easier:** Test components in isolation
- **Add features cleaner:** Clear where new code belongs
- **Navigate code better:** Each file has a single purpose
- **Reduce merge conflicts:** Changes less likely to overlap
- **Onboard developers faster:** Clear structure to understand
