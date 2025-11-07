# Tasks System Documentation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Data Models](#data-models)
3. [Core Services](#core-services)
4. [UI Components](#ui-components)
5. [Business Logic](#business-logic)
6. [User Workflows](#user-workflows)
7. [Features](#features)
8. [Integration Points](#integration-points)

## Architecture Overview

The Tasks system follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│                UI Layer                 │
├─────────────────────────────────────────┤
│ • TodoScreen (main interface)           │
│ • DailyTasksCard (home widget)         │
│ • TaskEditScreen (CRUD operations)     │
│ • TaskCard (individual task display)   │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│              Service Layer              │
├─────────────────────────────────────────┤
│ • TaskService (business logic)          │
│ • TaskCardUtils (display utilities)    │
│ • NotificationService (reminders)      │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│               Data Layer                │
├─────────────────────────────────────────┤
│ • Task (main entity)                    │
│ • TaskCategory (organization)           │
│ • TaskRecurrence (scheduling)           │
│ • SharedPreferences (persistence)      │
└─────────────────────────────────────────┘
```

## Data Models

### Task (`tasks_data_models.dart`)

The core entity representing a user task.

```dart
class Task {
  final String id;              // Unique identifier
  String title;                 // Task name
  String description;           // Optional details
  List<String> categoryIds;     // Associated categories
  DateTime? deadline;           // Hard deadline
  DateTime? scheduledDate;      // When task is scheduled for (recurring tasks)
  DateTime? reminderTime;       // Notification time
  bool isImportant;            // Priority flag
  bool isPostponed;            // True if user manually postponed/rescheduled
  TaskRecurrence? recurrence;   // Recurring pattern
  bool isCompleted;            // Completion status
  DateTime? completedAt;        // Completion timestamp
  DateTime createdAt;          // Creation timestamp
}
```

**Key Methods:**
- `isDueToday()` - Determines if task should appear today based on priority logic
- `getNextDueDate()` - Calculates next occurrence for recurring tasks

**Priority Logic (in `isDueToday()`):**
1. **Deadline** (highest priority) - Tasks with deadlines today or overdue
2. **ScheduledDate** - Tasks explicitly scheduled for today
3. **Recurrence** - Recurring tasks due today (only if no scheduledDate)
4. **ReminderTime** - Tasks with reminders set for today

### TaskCategory (`tasks_data_models.dart`)

Organizational structure for grouping tasks.

```dart
class TaskCategory {
  final String id;
  String name;
  Color color;
  int order;                   // Display priority (lower = higher priority)
}
```

### TaskRecurrence (`tasks_data_models.dart`)

Complex recurring pattern definitions supporting multiple recurrence types.

```dart
class TaskRecurrence {
  final List<RecurrenceType> types;  // Multiple recurrence patterns
  final int interval;                // Frequency multiplier
  final List<int> weekDays;         // Weekly: days of week (1-7)
  final int? dayOfMonth;            // Monthly: specific day
  final bool isLastDayOfMonth;      // Monthly: last day option
  final DateTime? startDate;        // When pattern begins
  final DateTime? endDate;          // When pattern ends
  final int? phaseDay;              // Menstrual cycle: specific day in phase
  final int? daysAfterPeriod;       // Menstrual cycle: days after period
  final TimeOfDay? reminderTime;    // Default reminder time
}
```

**Supported Recurrence Types:**
- `daily` - Every N days
- `weekly` - Specific days of week
- `monthly` - Specific day of month or last day
- `yearly` - Specific date annually
- `menstrualPhase` - During menstrual cycle phases
- `follicularPhase` - During follicular phase
- `ovulationPhase` - During ovulation phase
- `earlyLutealPhase` - During early luteal phase
- `lateLutealPhase` - During late luteal phase
- `menstrualStartDay` - Specific cycle day
- `ovulationPeakDay` - Peak ovulation day
- `custom` - Custom period-based patterns

## Core Services

### TaskService (`task_service.dart`)

Central service managing all task operations with singleton pattern.

**Key Responsibilities:**
- Task CRUD operations
- Priority calculation and sorting
- Recurring task management
- Notification scheduling
- Global change notifications
- Data persistence

**Priority Scoring System:**
The service uses a sophisticated point-based system to prioritize tasks:

```dart
// Scoring ranges (higher score = higher priority):
// 1200+:   Critical overdue reminders (within 1 hour)
// 900-1200: Overdue reminders and deadlines
// 700-900:  Recurring tasks due today, reminders < 30 min
// 600+:     Tasks scheduled TODAY (with reminder within 30 min or no reminder)
//           + Category points (sum of all categories)
//           + Important bonus (+100)
// 550-595:  Overdue scheduled tasks (decreasing by 5 points/day)
// 400+:     UNSCHEDULED tasks (no scheduled date)
//           + Category points (sum of all categories)
//           + Important bonus (+50)
// 125:      Scheduled TODAY with distant reminder (> 30 min away)
// 120:      Tomorrow (no categories, no important)
// 115-1:    Future scheduled dates (decreasing priority)
// 2:        Postponed recurring tasks (lowest)
```

**Category Scoring (NEW):**
Categories now use an additive system where points accumulate:
- **Priority 1**: 20 × 5 = 100 points
- **Priority 2**: 18 × 5 = 90 points
- **Priority 3**: 16 × 5 = 80 points
- **Priority 4**: 14 × 5 = 70 points
- **Priority N**: max(2, 20 - (N × 2)) × 5 points
- **Multiple categories**: Points are summed (e.g., Cat1 + Cat2 = 190 points)
- **Applied only to**: Unscheduled tasks and tasks scheduled TODAY (not future dates)

**Distant Reminder Rule:**
Tasks with reminders > 30 minutes away are treated differently:
- If scheduled TODAY with reminder > 30 min: Gets flat 125 points (no categories, no important)
- If scheduled future or unscheduled with reminder > 30 min: Gets no scheduling bonuses
- This prevents tasks scheduled for evening from cluttering the morning view

**Priority Calculation Logic:**
1. **Critical overdue reminders** - 1200+ points (< 1 hour overdue)
2. **Overdue reminders** - 800-1000 points (1-24+ hours overdue)
3. **Reminders < 30 min** - 1100 points
4. **Overdue deadlines** - 900 points (decreasing by 10 points/day)
5. **Deadlines today** - 800 points
6. **Recurring tasks due today** - 700 points
7. **Scheduled today** (reminder within 30 min or no reminder) - 600 + categories + important
8. **Overdue scheduled tasks** - 550-595 points (decreases 5 points/day)
9. **Unscheduled tasks** - 400 + categories + important
10. **Scheduled today** (reminder > 30 min) - 125 points
11. **Tomorrow** - 120 points
12. **Day 2-7** - 115, 110, 105, 100, 95, 90 points
13. **Day 8-20** - Decreases by 5 each day (85, 80, 75...)
14. **Day 21+** - Decreases by 1 each day until minimum of 1
15. **Postponed recurring tasks** - 2 points (lowest)

**Global Change Notification System:**
```dart
// Listeners for synchronizing UI across components
void addTaskChangeListener(VoidCallback listener);
void removeTaskChangeListener(VoidCallback listener);
void _notifyTasksChanged(); // Called after task modifications
```

### TaskCardUtils (`task_card_utils.dart`)

Utility class for task display and formatting.

**Key Functions:**
- `getTaskPriorityReason(Task)` - Determines display reason ("today", "overdue", etc.)
- `getPriorityColor(String)` - Maps reasons to colors
- `getScheduledDateText(Task, String)` - Formats scheduled dates with overlap prevention
- `buildInfoChip()` - Creates consistent chip widgets
- `getShortRecurrenceText()` - Abbreviated recurrence descriptions

## UI Components

### TodoScreen (`todo_screen.dart`)

Main task management interface with full functionality.

**Features:**
- Task list with priority sorting
- Category filtering
- Menstrual cycle filtering
- Completed task toggle
- Pull-to-refresh (configurable)
- Task randomizer
- Full CRUD operations

**Parameters:**
- `showFilters` - Show/hide filter UI
- `showAddButton` - Show/hide floating action button  
- `enableRefresh` - Enable/disable pull-to-refresh
- `onTasksChanged` - Callback for task modifications

### DailyTasksCard (`daily_tasks_card.dart`)

Compact task widget for home screen integration.

**Features:**
- Embedded TodoScreen with limited functionality
- Fixed height (400px)
- No filters or add button
- Disabled refresh to prevent scroll conflicts
- Automatic task loading and synchronization

### TaskCard (`task_card_widget.dart`)

Individual task display component with rich interactions.

**Features:**
- **Swipe & Hold gestures** (70% threshold, 2-second hold):
  - Swipe right & hold → Postpone task to tomorrow
  - Swipe left & hold → Delete task
  - Visual feedback: timer icon → checkmark with green background
  - Confirmation executes after 1 second, even if released
- Tap to edit
- Checkbox for completion toggle with confetti animation (1200ms)
- Information chips display:
  1. Priority reason (highest priority)
  2. Scheduled date (with overlap prevention)
  3. Deadline (most important)
  4. Reminder time
  5. Recurrence pattern
  6. Category tags
- **Important task highlighting**:
  - 2px coral border (alpha: 0.3)
  - Elevated shadow (elevation: 6)
- Visual completion states

### TaskEditScreen (`task_edit_screen.dart`)

Comprehensive task creation and editing interface.

**Form Organization:**
1. **Deadline** - Hard deadline with date/time picker
2. **Reminder Time** - Notification scheduling
3. **Important** - Priority toggle
4. **Title** - Task name (required)
5. **Description** - Optional details
6. **Categories** - Multi-select organization
7. **Recurrence** - Complex pattern definition

**Validation:**
- Title required
- Date consistency checks
- Recurrence pattern validation

### RecurrenceDialog (`recurrence_dialog.dart`)

Specialized dialog for defining recurring patterns.

**Capabilities:**
- Multiple recurrence type selection
- Interval configuration
- Start/end date settings
- Menstrual cycle integration
- Day-specific options
- Reminder time for recurring tasks

## Business Logic

### Task Completion Flow

**Regular Tasks:**
1. User taps checkbox → completion animation starts (1200ms)
2. Animation completes → toggle completion status
3. Set/clear completion timestamp
4. Save to persistent storage
5. Notify change listeners
6. Update UI with fade out

**Recurring Tasks (Daily/Weekly/etc):**
1. User taps checkbox → completion animation starts
2. Animation completes → trigger recurring task handler
3. Calculate next due date using recurrence pattern
4. Create updated task with:
   - Reset completion status to false
   - Updated scheduledDate to next occurrence
   - Reset isPostponed flag
   - Preserved original deadline
   - Adjusted reminder time to new date
5. Save updated task (replaces current task, same ID)
6. Reschedule notification for new date
7. Update UI immediately - task appears for next occurrence
8. Notify change listeners

**Note:** Daily recurring tasks now properly reset to uncompleted and schedule for tomorrow, appearing as a new task the next day.

### Priority System

The system uses contextual priority scoring that adapts to time of day:

```dart
int _getContextualTomorrowPriority(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 50;   // Morning: focus on today
  if (hour < 18) return 150;  // Afternoon: light planning
  return 300;                 // Evening: prepare for tomorrow
}
```

**Special Rules:**
- **Distant reminders** (> 30 min): Block most bonuses to prevent premature display
- **Scheduled today with distant reminder**: Get flat 125 points (just above tomorrow's 120)
- **Unscheduled tasks**: Get 400 points + categories + important bonus
- **Future scheduled tasks**: Get decreasing date-based priority (no categories/important)
- **Categories**: Sum all category points (Cat1=100, Cat2=90, etc.)
- **Important flag**: +100 for scheduled today, +50 for unscheduled, +0 for future dates
- **Postponed recurring tasks**: Get very low priority (2 points)
- **Menstrual cycle tasks**: Get distance-based priority boost

**Key Priority Hierarchy:**
1. Urgent/Overdue (800-1200) - Time-sensitive tasks
2. Scheduled Today (600-700) - Today's planned work
3. Unscheduled (400-500) - Tasks needing scheduling
4. Scheduled Today (distant reminder) (125) - Today but not urgent yet
5. Future Dates (120 down to 1) - Strict chronological order

### Menstrual Cycle Integration

Tasks can be tied to menstrual cycle phases for health tracking:

**Supported Patterns:**
- Phase-based (menstrual, follicular, ovulation, luteal phases)
- Specific cycle days (day 1, ovulation peak)
- Days after period ends
- Combination patterns (e.g., "weekly on Mondays during ovulation phase")

**Filtering:**
- Flower icon toggles cycle-based filtering
- When enabled: shows only current phase tasks + non-cycle tasks
- When disabled: shows all tasks regardless of cycle phase

## User Workflows

### Creating a Task

1. Tap floating action button or use task edit
2. Fill required title field
3. Optionally set deadline, reminder, importance
4. Choose categories for organization
5. Configure recurrence if needed
6. Save - task appears in prioritized list

### Completing a Task

**One-time Task:**
1. Tap checkbox or swipe to complete
2. Task moves to completed section
3. Completion animation plays
4. Task hidden from main list

**Recurring Task:**
1. Tap checkbox to complete current occurrence
2. Task automatically reschedules to next due date
3. Appears as new incomplete task
4. Maintains all original settings

### Task Postponement

1. Swipe right on task card (70% threshold required)
2. Hold for 2 seconds - timer icon appears
3. After 2 seconds, confirmation appears (green checkmark)
4. Release anytime after confirmation - action executes after 1 second
5. Task scheduledDate moves to tomorrow
6. isPostponed flag set to true
7. Priority automatically adjusts
8. Task appears lower in list until due

**Note:** Once confirmation shows, you can release immediately and the postponement will still execute.

### Category Management

1. Access via category icon in TodoScreen
2. Create categories with custom colors and names
3. Assign order for priority tie-breaking
4. Filter tasks by category using chip filters

### Task Prioritization

Tasks automatically sort by calculated priority considering:
1. Urgency (overdue, due today)
2. Importance (user-flagged important tasks)
3. Time context (morning vs evening planning)
4. Recurrence patterns
5. Category organization

## Features

### Advanced Scheduling

- **Multi-pattern Recurrence**: Tasks can have multiple recurrence types
- **Smart Rescheduling**: Completed recurring tasks automatically find next occurrence
- **Start/End Dates**: Recurrence patterns can be time-bounded
- **Menstrual Integration**: Health-focused scheduling options
- **Overdue Scheduled Tasks**: Tasks scheduled in the past (non-recurring) automatically get elevated priority:
  - 1 day overdue: 590 points
  - 2 days overdue: 585 points
  - 3 days overdue: 580 points
  - Priority decreases by 5 points per day
  - Minimum priority: 550 points
  - Always appears right after "scheduled today" tasks

### Intelligent Prioritization

- **Context-Aware**: Priority changes based on time of day
- **Multi-factor Scoring**: Considers deadlines, importance, recurrence, categories
- **Tie-breaking**: Category order used for final sorting

### Flexible Display

- **Chip System**: Visual information tags with overlap prevention
- **Scheduled Date Display**: Shows when recurring tasks are next due
- **Priority Indicators**: Color-coded importance levels
- **Completion Animation**: 1200ms confetti animation with:
  - 25 colorful particles bursting from center
  - Card scaling and green glow effect
  - Fade out with opacity transition
  - Automatic task rescheduling (recurring) or removal (one-time)

### Integration Features

- **Global Synchronization**: Changes propagate across all UI components
- **Notification System**: Reminder scheduling with recurring task support  
- **Home Screen Widget**: Compact daily task view
- **Swipe Gestures**: Quick actions without menu navigation

### Accessibility & UX

- **Pull-to-Refresh Control**: Configurable per component
- **Visual Feedback**: Haptic feedback and animations
- **Consistent UI**: Standardized chip design and colors
- **Error Handling**: Graceful failure with debug information

## Integration Points

### Home Screen

- `DailyTasksCard` provides compact task overview
- Integrates with home screen refresh functionality
- Shows top priority tasks only
- Links to full TodoScreen for detailed management

### Notifications

- `NotificationService` handles reminder scheduling
- Supports both one-time and recurring reminders
- Calculates next reminder times for recurring tasks
- Maintains notification consistency across app lifecycle

### Menstrual Cycle System

- Tasks can be filtered by cycle phase
- Recurrence patterns support cycle-based scheduling
- Integration with menstrual cycle tracking
- Phase-aware task prioritization

### Data Persistence

- `SharedPreferences` for local storage
- JSON serialization for complex data structures
- Automatic migration for data model changes
- Error recovery and fallback mechanisms

---

## File Structure

```
lib/Tasks/
├── tasks_data_models.dart      # Core data structures
├── task_service.dart          # Business logic service
├── task_card_utils.dart       # Display utilities
├── todo_screen.dart           # Main task interface
├── daily_tasks_card.dart      # Home widget
├── task_card_widget.dart      # Individual task display
├── task_edit_screen.dart      # Task creation/editing
├── recurrence_dialog.dart     # Recurrence configuration
├── task_categories_screen.dart # Category management
├── category_edit_dialog.dart   # Category editing
├── task_completion_animation.dart # Visual feedback
└── task_widget_service.dart    # Widget-specific services
```

This documentation covers the complete Tasks system architecture, from data models to user interactions, providing a comprehensive reference for understanding and extending the functionality.