# Task System Architecture

## Overview

The task system has been refactored from a monolithic `TaskService` into a clean, modular architecture with clear separation of concerns.

## Architecture Diagram

```
TaskService (Facade)
├── TaskRepository (Data Layer)
│   └── Handles ALL persistence operations
│
├── TaskPriorityService (Business Logic)
│   └── Calculates priority scores and sorts tasks
│
├── RecurrenceCalculator (Business Logic)
│   └── Pure functions for recurrence date calculations
│
└── TaskNotificationService (Integration)
    └── Manages task notifications
```

## Components

### 1. TaskRepository
**Location:** `lib/Tasks/repositories/task_repository.dart`

**Responsibility:** ONLY data persistence (SharedPreferences)

**Methods:**
- `loadTasks()` - Load tasks from storage
- `saveTasks()` - Save tasks to storage
- `loadCategories()` - Load categories from storage
- `saveCategories()` - Save categories to storage
- `loadTaskSettings()` - Load settings from storage
- `saveTaskSettings()` - Save settings to storage
- `loadSelectedCategoryFilters()` - Load filters from storage
- `saveSelectedCategoryFilters()` - Save filters to storage

**Key Principles:**
- NO business logic
- NO notifications
- NO widget updates
- Pure data operations only

---

### 2. TaskPriorityService
**Location:** `lib/Tasks/services/task_priority_service.dart`

**Responsibility:** Calculate task priority scores and sort tasks

**Methods:**
- `getPrioritizedTasks()` - Get sorted list of tasks by priority
- `calculateTaskPriorityScore()` - Calculate priority score for a single task

**Key Principles:**
- Pure logic - NO side effects
- NO async operations in scoring (for performance)
- Uses comprehensive scoring algorithm considering:
  - Reminder times (past/future)
  - Deadlines (overdue/today/tomorrow)
  - Recurring tasks
  - Scheduled dates
  - Important flag
  - Category order
  - Menstrual cycle phases

**Performance Fix:**
- Pre-calculates scores once per task (previously recalculated during sort)
- Removed async side effect (_updateTaskScheduledDate call) that was happening during sort

---

### 3. RecurrenceCalculator
**Location:** `lib/Tasks/services/recurrence_calculator.dart`

**Responsibility:** Calculate recurrence dates for recurring tasks

**Methods:**
- `calculateNextOccurrenceDate()` - Calculate just the DATE for next occurrence
- `calculateNextScheduledDate()` - Create a Task with updated scheduledDate
- `calculateMenstrualTaskScheduledDate()` - Calculate date for menstrual tasks
- `calculateRegularRecurringTaskDate()` - Calculate date for regular recurring tasks
- `calculatePhaseStartDates()` - Calculate menstrual phase start dates
- `calculateMenstrualDateFromCache()` - Calculate from cached phase data

**Key Principles:**
- Pure functions - NO side effects
- Optimized for common recurrence types (daily, weekly, monthly, yearly)
- Special handling for menstrual cycle tasks
- Always resets completion status for next occurrences

---

### 4. TaskNotificationService
**Location:** `lib/Tasks/services/task_notification_service.dart`

**Responsibility:** Schedule and manage task notifications

**Methods:**
- `ensureNotificationServiceInitialized()` - Initialize notification service
- `scheduleAllTaskNotifications()` - Schedule notifications for all tasks
- `scheduleTaskNotification()` - Schedule notification for a single task
- `cancelAllTaskNotifications()` - Cancel all task notifications
- `cancelTaskNotification()` - Cancel notification for a specific task
- `forceRescheduleAllNotifications()` - Force reschedule (for debugging)

**Key Principles:**
- Handles ONLY notification operations
- Delegates to underlying NotificationService
- Handles recurring task notification logic
- Prevents duplicate notifications

---

### 5. TaskService (Facade)
**Location:** `lib/Tasks/task_service.dart`

**Responsibility:** Coordinate operations between all services

**Key Changes:**
- Now acts as a FACADE instead of doing everything itself
- Delegates to specialized services
- Maintains backward compatibility with existing API
- Handles complex workflows (e.g., load with migration, save with sorting)

**Delegation:**
- Data operations → `TaskRepository`
- Priority/sorting → `TaskPriorityService`
- Recurrence calculations → `RecurrenceCalculator`
- Notifications → `TaskNotificationService`

**Retained Responsibilities:**
- Auto-migration logic during load
- Task operations (skip, postpone)
- Menstrual task priority updates
- Change notification to listeners

---

## Key Improvements

### 1. Separation of Concerns
- Each service has ONE clear responsibility
- No mixing of data, business logic, and notifications

### 2. Performance Optimizations
- **saveTasks()**: Reduced from doing too much work on every save
  - Previously: Loaded categories, sorted by priority, scheduled notifications, updated widget
  - Now: Only sorts and saves (notifications/widget updates are optional)
  - Uses skip flags for frequent saves (e.g., typing in task title)

- **getPrioritizedTasks()**: Removed async side effect
  - Previously: Called `_updateTaskScheduledDate()` during sort (async operation!)
  - Now: Pure scoring function, no database writes during sort

### 3. Testability
- Pure functions are easy to test
- Services can be mocked independently
- Clear interfaces between components

### 4. Maintainability
- Each file has < 500 lines (vs 1700+ in original)
- Clear responsibility boundaries
- Easy to locate and fix bugs
- Easy to add new features

### 5. Uses Immutable Pattern
- Leverages `Task.copyWith()` throughout
- No more manual Task constructors with 15 parameters
- Safer, more readable code

---

## Migration Notes

### Breaking Changes
**NONE** - The public API of TaskService remains unchanged. All existing code continues to work.

### New Features
Services can now be used independently:
```dart
// Use priority service directly
final priorityService = TaskPriorityService();
final sortedTasks = priorityService.getPrioritizedTasks(tasks, categories, 10);

// Use recurrence calculator directly
final calculator = RecurrenceCalculator();
final nextDate = await calculator.calculateNextOccurrenceDate(task, prefs);

// Use repository directly (for faster data operations)
final repository = TaskRepository();
final tasks = await repository.loadTasks(); // No auto-migration
```

---

## File Structure

```
lib/Tasks/
├── task_service.dart                    # Facade (700 lines, was 1727)
├── tasks_data_models.dart               # Data models (unchanged)
│
├── repositories/
│   └── task_repository.dart             # Data persistence (180 lines)
│
└── services/
    ├── task_priority_service.dart       # Priority scoring (460 lines)
    ├── recurrence_calculator.dart       # Recurrence calculations (260 lines)
    └── task_notification_service.dart   # Notifications (150 lines)
```

**Total lines:** ~1,750 (similar to original, but now properly organized)

---

## Future Enhancements

Now that the architecture is clean, these become easy to add:

1. **Caching Layer** - Add a cache between TaskService and TaskRepository
2. **Offline Sync** - Add sync service for Firebase
3. **Task Analytics** - Add analytics service for task completion tracking
4. **AI Prioritization** - Replace TaskPriorityService with ML model
5. **Testing** - Each service can be unit tested independently

---

## Design Principles Applied

1. **Single Responsibility Principle** - Each service has ONE job
2. **Separation of Concerns** - Data, logic, and integration are separated
3. **Dependency Inversion** - TaskService depends on abstractions (services)
4. **Open/Closed Principle** - Easy to extend without modifying existing code
5. **DRY (Don't Repeat Yourself)** - No code duplication
6. **Facade Pattern** - TaskService provides simplified interface
7. **Immutability** - Using Task.copyWith() everywhere

---

Generated: 2025-10-31
