# Routines & Habits System Documentation

## Overview

The BB App includes a comprehensive Routines & Habits system designed to help users build and maintain daily routines and long-term habits. The system provides both Flutter app functionality and Android widget integration for seamless user experience.

## 🔄 Routines System

### Core Concepts

**Routine**: A collection of sequential steps/tasks that are performed regularly (e.g., morning routine, evening routine)
- Each routine has a title, list of items, reminder settings, and active days
- Supports step-by-step execution with completion tracking
- Can be scheduled for specific days of the week

**RoutineItem**: Individual steps within a routine
- Has text description and completion status (completed/skipped/pending)
- Can be marked as completed or skipped without removing from list
- Progress persists throughout the day

### Data Models

#### Routine (`lib/Routines/routine_data_models.dart:2-67`)
```dart
class Routine {
  final String id;
  String title;
  List<RoutineItem> items;
  bool reminderEnabled;
  int reminderHour;
  int reminderMinute;
  Set<int> activeDays; // 1=Monday, 2=Tuesday, ..., 7=Sunday
}
```

#### RoutineItem (`lib/Routines/routine_data_models.dart:69-95`)
```dart
class RoutineItem {
  final String id;
  String text;
  bool isCompleted;
  bool isSkipped;
}
```

### Key Features

#### 1. Day-Based Scheduling
- Routines can be configured to run on specific days (weekdays, weekends, or custom combinations)
- Active day logic determines which routine is displayed today
- Supports "effective date" concept (considers times before 2 AM as previous day)

#### 2. Progress Tracking
- **Daily Reset**: Progress automatically resets each day
- **Persistent Progress**: Step completion survives app restarts within the same day
- **Skip vs Complete**: Steps can be completed (done) or skipped (postponed)
- **Smart Navigation**: Automatically moves to next unfinished step

#### 3. Morning Routine Card
The home screen displays an active morning routine card with:
- Current step display
- Complete/Skip action buttons
- Progress indicator (completed/total steps)
- "Not Today" option to hide the card
- Smart step navigation (finds next unfinished or skipped step)

### Services Architecture

#### RoutineService (`lib/Routines/routine_service.dart`)
Main service handling routine data and logic:
- `loadRoutines()`: Loads all routines from SharedPreferences
- `saveRoutines()`: Saves routines and updates notifications/widget
- `findMorningRoutine()`: Finds active morning routine for today
- `setActiveRoutineForToday()`: Manual override for routine selection
- Provides default morning routine on first launch

#### RoutineProgressService (`lib/Routines/routine_progress_service.dart`)
Unified progress tracking service:
- `markRoutineInProgress()`: Marks routine as actively being performed
- `saveRoutineProgress()`: Saves current step and completion status
- `loadRoutineProgress()`: Loads today's progress for a routine
- `getInProgressRoutineId()`: Returns which routine is currently active

#### RoutineWidgetService (`lib/Routines/routine_widget_service.dart`)
Bridges Flutter and Android widget:
- `updateWidget()`: Syncs current routine data to Android widget
- `refreshWidgetColor()`: Updates widget background color
- `syncWithWidget()`: Ensures app and widget are synchronized

### UI Components

#### Routines Management Screen (`lib/Routines/routines_habits_screen.dart:385-443`)
- List view of all routines with reorderable cards
- Start/Continue routine functionality  
- In-progress indicator for active routines
- Duplicate, edit, delete options
- Reminder settings access

#### Morning Routine Card (`lib/Routines/morning_routine_card.dart`)
Interactive card on home screen:
- Displays current step with complete/skip buttons
- Shows completion progress
- Handles step navigation logic
- Persists progress across app lifecycle events

#### Routine Execution Screen (`lib/Routines/routine_execution_screen.dart`)
Full-screen routine execution interface (accessed via "Continue" button):
- Step-by-step guided execution
- Progress visualization
- Complete/skip functionality
- Completion celebration

## 🎯 Habits System

### Core Concepts

**Habit**: A behavior or activity to be performed daily, tracked over 21-day cycles
- Each habit tracks completion dates and streak information
- Uses 21-day cycle system for habit formation
- Supports multiple cycles for long-term habit building

### Data Models

#### Habit (`lib/Habits/habit_data_models.dart:4-145`)
```dart
class Habit {
  final String id;
  String name;
  bool isActive;
  DateTime createdAt;
  List<String> completedDates; // 'yyyy-MM-dd' format
  int currentCycle;
  bool isCompleted;
}
```

#### HabitStatistics (`lib/Habits/habit_data_models.dart:147-213`)
Comprehensive statistics for habit analysis:
- Current and longest streaks
- Completion rates (weekly, monthly, all-time)
- Monthly completion statistics
- Total completed days

### Key Features

#### 1. 21-Day Cycle System
- Each habit follows 21-day cycles for habit formation
- Progress tracking within current cycle
- Option to continue to next cycle after completion
- Visual progress indicators (X/21 days completed)

#### 2. Streak Tracking
- Current streak calculation (consecutive completed days)
- Longest streak tracking over habit lifetime
- Streak display in habit cards and statistics

#### 3. Flexible Completion Tracking
- Daily completion toggle (can mark/unmark for today)
- Date-based completion storage
- Completion rate analysis over different time periods

#### 4. Active/Inactive States
- Habits can be temporarily deactivated without losing data
- Only active habits appear in daily tracking
- Inactive habits preserved for future reactivation

### Services Architecture

#### HabitService (`lib/Habits/habit_service.dart`)
Main service for habit management:
- `loadHabits()` / `saveHabits()`: Data persistence
- `getActiveHabits()`: Returns only currently active habits
- `toggleHabitCompletion()`: Marks/unmarks habit for today
- `hasUncompletedHabitsToday()`: Checks if any habits remain unfinished
- `cleanupOldData()`: Removes completion data older than 1 year

### UI Components

#### Habit Card (`lib/Habits/habit_card.dart`)
Home screen widget showing today's habits:
- Lists uncompleted habits with checkboxes
- Shows completed habits with strikethrough
- Displays streak information
- "All habits completed" celebration message

#### Habits Management Screen (`lib/Routines/routines_habits_screen.dart:446-505`)
- List view of all habits with reorderable cards
- Active/inactive toggle switches
- Current cycle progress display (X/21 days)
- Edit, delete functionality
- Statistics access button

#### Habit Statistics Screen (`lib/Habits/habit_statistics_screen.dart`)
Comprehensive analytics dashboard:
- Current and longest streak display
- Completion rate charts (weekly/monthly/all-time)
- Monthly completion calendar view
- Progress visualization

## 📱 Android Widget Integration

### Widget Architecture

The system includes a native Android widget that displays the current routine and allows interaction directly from the home screen.

#### RoutineWidgetProvider (`android/app/src/main/kotlin/com/bb/bb_app/RoutineWidgetProvider.kt`)
Android widget provider handling:
- **Widget Display**: Shows current routine title, step text, and progress
- **User Interactions**: Complete/Skip buttons, refresh button
- **Data Sync**: Reads routine data from Flutter SharedPreferences
- **Color Customization**: Applies user-selected background colors

#### Widget Features
- **Current Step Display**: Shows active routine step with completion buttons
- **Progress Indicator**: X/Y steps completed counter
- **Action Buttons**: Complete (✓) and Skip (→) buttons
- **Refresh Button**: Manual sync with app data
- **Custom Background**: User-selectable widget background colors
- **Smart Detection**: Finds active routine based on day/time logic

#### Data Flow
1. **Flutter → Android**: RoutineWidgetService saves routine data to SharedPreferences
2. **Android Reading**: Widget provider reads flutter-prefixed keys from SharedPreferences
3. **User Actions**: Widget button presses update progress and refresh display
4. **Bi-directional Sync**: Changes sync between app and widget

### Widget Color Customization

#### Color Settings Screen (`lib/Routines/widget_color_settings_screen.dart`)
Full-featured color picker interface:
- **Predefined Colors**: Grid of vibrant Material Design colors
- **Custom Color Picker**: HSL-based color generation with 64 color options
- **Live Preview**: Shows how widget will look with selected color
- **Instant Apply**: Colors update widget immediately upon selection

## 🔄 Data Flow & Synchronization

### Routine Execution Flow
1. **Morning Routine Detection**: System finds active routine for current day
2. **Progress Loading**: Loads any existing progress for today
3. **Step Execution**: User completes/skips steps sequentially  
4. **Progress Saving**: Each action saves progress immediately
5. **Widget Sync**: Changes propagate to Android widget
6. **Daily Reset**: New day clears progress and starts fresh

### Habit Tracking Flow
1. **Daily Display**: Active habits appear on home screen
2. **Completion Toggle**: User marks habits as done/undone
3. **Streak Calculation**: System updates streak counters
4. **Cycle Progress**: Tracks progress within 21-day cycles
5. **Statistics Update**: All analytics update in real-time

### Cross-Platform Synchronization
- **SharedPreferences**: Primary data storage for both Flutter and Android
- **Key Prefixing**: Flutter automatically adds 'flutter.' prefix to keys
- **Dual Format Storage**: Routines saved in both Flutter and Android-compatible formats
- **Real-time Updates**: Widget updates immediately when app data changes

## 📊 Storage & Persistence

### Data Storage Architecture
- **SharedPreferences**: Primary storage mechanism for all routine and habit data
- **JSON Serialization**: All objects serialize to/from JSON for storage
- **Key Namespacing**: Organized key structure prevents data conflicts

### Storage Keys
- `routines`: List of all routines (JSON array)
- `routine_progress_{routineId}_{date}`: Daily progress for specific routine
- `morning_routine_progress_{date}`: Legacy morning routine progress
- `active_routine_{date}`: Currently in-progress routine
- `habits`: List of all habits (JSON array)
- `widget_background_color`: User-selected widget color

### Data Cleanup
- **Daily Reset**: Routine progress automatically expires after effective date
- **Habit Cleanup**: Old completion data (>1 year) automatically removed
- **Widget Sync**: Periodic cleanup of stale widget data

## 🎨 User Experience Features

### Smart Routine Management
- **Intelligent Day Detection**: Considers 2 AM as day boundary
- **Active Day Logic**: Only shows routines scheduled for today
- **Manual Override**: Can set any routine as active for today
- **In-Progress Tracking**: Visual indicators for currently active routines

### Flexible Step Navigation
- **Smart Next Step**: Automatically finds next unfinished step
- **Skip Handling**: Skipped steps can be retried later
- **Progress Preservation**: Completed steps stay completed throughout day
- **Completion Detection**: Celebrates when all steps are finished

### Habit Formation Support
- **21-Day Cycles**: Based on habit formation research
- **Streak Motivation**: Visual streak counters encourage consistency
- **Flexible Scheduling**: No fixed time requirements, just daily completion
- **Long-term Tracking**: Multi-cycle support for sustained habit building

### Accessibility & Usability
- **One-Handed Operation**: Compact buttons for easy mobile use
- **Visual Feedback**: Clear completion states and progress indicators
- **Contextual Actions**: Appropriate options based on current state
- **Error Recovery**: Graceful handling of data inconsistencies

## 🔧 Technical Implementation

### Architecture Patterns
- **Service Layer**: Separation of business logic and UI
- **State Management**: Flutter setState with lifecycle-aware updates
- **Data Persistence**: SharedPreferences with JSON serialization
- **Cross-Platform**: Flutter-Android communication via MethodChannels

### Performance Optimizations
- **Lazy Loading**: UI components load data on-demand
- **Efficient Updates**: Only relevant widgets refresh on data changes
- **Background Persistence**: Progress saves during app lifecycle changes
- **Memory Management**: Periodic cleanup of old data

### Error Handling
- **Graceful Degradation**: System continues working with partial data
- **Data Validation**: Input validation prevents corruption
- **Recovery Mechanisms**: Automatic fallbacks for missing data
- **Debug Logging**: Comprehensive error logging (cleaned for production)

This documentation provides a complete overview of the Routines & Habits system architecture, functionality, and implementation details. The system is designed for reliability, flexibility, and an excellent user experience across both the Flutter app and Android widget interfaces.