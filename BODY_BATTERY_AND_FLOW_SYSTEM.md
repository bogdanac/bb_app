# Body Battery & Flow System

## Overview

The Body Battery & Flow system is a comprehensive energy tracking and productivity management system that integrates with the menstrual cycle to provide personalized daily goals and meaningful progress metrics.

## Core Concepts

### Two Metrics

**1. Body Battery (%)**
- Represents how you feel throughout the day
- Range: 5% - 120% (based on menstrual cycle phase)
- Can go negative (overexertion) or above 120% (supercharged)
- Tasks either **drain** (negative energy) or **charge** (positive energy) your battery

**2. Flow (points)**
- Represents your productivity and activity level
- Accumulated through completing tasks and routine steps
- Daily goal adapts based on menstrual cycle phase
- Tracks streaks and personal records

## Energy Scale

Tasks use an energy scale from **-5 to +5**:

| Value | Type | Battery Impact | Flow Points | Example |
|-------|------|----------------|-------------|---------|
| **-5** | Most draining | -50% | 10 pts | Exhausting meeting, major project |
| **-4** | Very draining | -40% | 8 pts | Deep work session |
| **-3** | Draining | -30% | 6 pts | House cleaning, difficult task |
| **-2** | Moderately draining | -20% | 4 pts | Regular work task |
| **-1** | Slightly draining | -10% | 2 pts | Quick chore *(default)* |
| **0** | Neutral | 0% | 1 pt | Routine maintenance |
| **+1** | Slightly charging | +10% | 2 pts | Pleasant activity |
| **+2** | Moderately charging | +20% | 3 pts | Light hobby |
| **+3** | Charging | +30% | 4 pts | Fun activity |
| **+4** | Very charging | +40% | 5 pts | Exciting project |
| **+5** | Most charging | +50% | 6 pts | Passion work, play |

### Default Energy Level

New tasks default to **-1** (slightly draining), representing typical tasks that require effort but aren't overwhelming.

## Formulas

### Battery Change
```
Battery Change = Energy Level × 10%
```

**Examples:**
- Task with -5 energy → Drains 50% battery
- Task with -1 energy → Drains 10% battery
- Task with +3 energy → Charges 30% battery

### Flow Points
```
Draining tasks (negative energy): |energy| × 2
  -5 → 10 points
  -4 →  8 points
  -3 →  6 points
  -2 →  4 points
  -1 →  2 points

Neutral: 0 → 1 point

Charging tasks (positive energy): energy + 1
  +1 →  2 points
  +2 →  3 points
  +3 →  4 points
  +4 →  5 points
  +5 →  6 points
```

**Key Insight:** Draining tasks earn MORE flow points than charging tasks. This rewards you for doing hard work!

## Menstrual Cycle Integration

### Starting Battery Calculation

Your suggested starting battery each morning is based on your current menstrual cycle phase:

```
Battery % = Low Battery + (Phase Progress × Battery Range)

Where:
- Low Battery = 5% (first day of period)
- High Battery = 120% (ovulation day)
- Battery Range = 115%
- Phase Progress = 0.0 to 1.0
```

**Phase Progression:**
- **Day 1 (Period starts):** 5% battery (lowest)
- **Days 2-13 (Follicular):** Gradually increasing
- **Day 14 (Ovulation):** 120% battery (peak)
- **Days 15-28 (Luteal):** Gradually decreasing
- **Day 28 (Late luteal):** Back to ~5-10%

### Flow Goal Adaptation

Your daily Flow goal also adapts to your cycle:

```
Daily Goal = Min Goal + (Phase Progress × Goal Range)

Where:
- Min Goal = 5-20 (configurable in settings)
- Max Goal = User's max setting
- Phase Progress = same as battery
```

**Example (Min: 10, Max: 30):**
- **Ovulation day:** 30 points goal (high energy = do more!)
- **Late luteal:** 10 points goal (low energy = be gentle)
- **Mid-follicular:** ~20 points goal (building up)

## Daily Workflow

### Morning

1. **Morning Battery Prompt** appears on first app open
2. Shows your suggested battery based on cycle phase
3. You can adjust with a slider (5% - 120%)
4. Shows today's Flow goal
5. Dismiss to start the day

### Throughout the Day

1. Complete tasks → Battery changes, Flow points earned
2. Use quick buttons for untracked activities:
   - **[−10%] [+10%]** - Adjust battery manually
   - **[+1 pts] [+2 pts]** - Add flow points for small tasks
3. Check progress on Battery & Flow home card

### Evening

1. See your final stats:
   - Ending battery level
   - Flow points earned vs goal
   - Streak status
2. Get feedback:
   - **Goal met:** "🎉 Daily goal complete!"
   - **Personal Record:** "🏆 New PR: 85 points!"
   - **Low battery:** "💜 Rest up tomorrow"

## Priority System

Tasks scheduled for **today** get an energy-based priority boost:

### Priority Boost Formula
```
Priority Boost = 200 - ((Energy Level + 5) × 18)
```

### Boost Range

| Energy | Priority Boost | Effect |
|--------|----------------|--------|
| **-5** | +200 | Pushed to top of today's list |
| **-3** | +164 | High priority |
| **-1** | +128 | Above neutral |
| **0** | +110 | Neutral |
| **+3** | +56 | Lower priority |
| **+5** | +20 | Bottom of today's list |

### Why This Matters

- **Draining tasks** get prioritized when you have energy
- **Charging tasks** naturally fall to later in the day
- Encourages tackling hard work early
- Respects existing urgency (deadlines/reminders still override)
- **Only affects today's tasks** - future tasks unaffected

## Achievements & Gamification

### Streaks

Track consecutive days of meeting your Flow goal:

- **3 days:** "🔥 3 day streak!"
- **7 days:** "🔥 Week streak!"
- **14 days:** "🔥 Two weeks!"
- **30 days:** "🔥 Month streak!"
- **50 days:** "🔥 Unstoppable!"
- **100 days:** "🔥🔥 Century!"

### Personal Records (PR)

Your highest single-day Flow score ever. When you beat it:
- **"🏆 New Personal Record!"**
- Shown in history calendar
- Displayed on home card

### Celebrations

**Flow Goal Met:**
```
🎉 Daily goal complete!
```

**Streak Milestone:**
```
🔥 7 day streak! Keep it going!
```

**New PR:**
```
🏆 New Personal Record!
You earned 85 points today!
```

**Low Battery Warning:**
```
💜 Rest up tomorrow
Your battery is at 15%
```

## UI Components

### Battery & Flow Home Card

Located under the Menstrual Card on the home screen:

**Displays:**
- Battery gauge showing current %
- Flow progress: "Today: 45 pts | Goal: 30 | PR: 85"
- Streak indicator: "🔥 5 day streak!"
- Quick action buttons
- "Adjust Battery" button

**Colors:**
- Red → Yellow → Green → Blue (based on battery level)
- Progress bar color matches battery health

### Task Editor

**Energy Slider:**
- Range: -5 to +5
- Default: -1
- Color gradient: Red (draining) → Yellow → Green (charging)
- Live preview: "Drains 30%, Earns 13 pts"

### Routine Editor

**Energy Selector:**
- Number buttons 1-10 for each routine step
- Color-coded by energy level
- Optional (can leave as null = no energy tracking)

### Energy Calendar History

**Calendar View:**
- Each day shows:
  - Starting battery → Ending battery
  - Flow points earned / goal
  - Achievement badges (Goal Met ✓, PR 🏆)
  - Menstrual phase indicator
- Color-coded by performance
- Tap for detailed daily breakdown

**Daily Detail View:**
- Starting & ending battery
- Flow points breakdown
- List of completed tasks/routines
- Energy consumption per task
- Phase info

## Data Models

### EnergySettings

```dart
class EnergySettings {
  final int minBattery;        // Default: 5%
  final int maxBattery;        // Default: 120%
  final int minFlowGoal;       // Default: 5
  final int maxFlowGoal;       // Default: 20
  final int currentStreak;     // Consecutive days meeting goal
  final int personalRecord;    // Best flow score ever
}
```

### DailyEnergyRecord

```dart
class DailyEnergyRecord {
  final DateTime date;
  final int startingBattery;   // Morning battery
  final int currentBattery;    // Current battery
  final int flowPoints;        // Points earned today
  final int flowGoal;          // Today's goal
  final bool isGoalMet;        // Did we meet goal?
  final bool isPR;             // Is this a personal record?
  final String menstrualPhase; // Current cycle phase
  final int cycleDayNumber;    // Day in cycle
  final List<EnergyConsumptionEntry> entries;
}
```

### EnergyConsumptionEntry

```dart
class EnergyConsumptionEntry {
  final String id;             // Task/routine step ID
  final String title;          // What was completed
  final int energyLevel;       // Energy value (-5 to +5)
  final DateTime completedAt;  // When
  final EnergySourceType sourceType; // task or routineStep
}
```

## Migration

### From Old System

The system automatically migrates existing energy data:

**Task Energy (was 1-5, now -5 to +5):**
```
Old Value → New Value
    1    →    -1
    2    →    -2
    3    →    -3
    4    →    -4
    5    →    -5
```

**Settings:**
- Old "energyGoal" system → New battery + flow system
- History preserved and recalculated with new formulas

## Quick Buttons

### Battery Adjustments

**[−10%] [+10%]**
- Manually adjust battery for untracked activities
- Use when you do things not in the app
- Examples:
  - Did unexpected chores? → -10%
  - Had a great nap? → +10%

### Flow Points

**[+1 pts] [+2 pts]**
- Add flow points for small untracked tasks
- Helps capture your full productivity
- Examples:
  - Quick phone call → +1 pt
  - Helped someone → +2 pts

## Settings

**Energy Tracking Settings** (in Settings → Energy Tracking):

1. **Battery Range**
   - Minimum battery (late luteal): 5-30%
   - Maximum battery (ovulation): 100-150%

2. **Flow Goals**
   - Minimum daily goal: 5-20 points
   - Maximum daily goal: 15-50 points
   - Goals auto-adapt between these values

3. **Current Stats** (read-only)
   - Current streak
   - Personal record
   - Recent averages

## Best Practices

### 1. Set Realistic Energy Levels

- **Don't overthink it** - use your gut feeling
- **Most tasks are -1 or -2** (slightly to moderately draining)
- **Save -5 for truly exhausting** work
- **Save +5 for things that genuinely energize** you

### 2. Adjust Your Battery Honestly

- **In the morning:** How do you actually feel?
- If suggested battery is 80% but you feel 50%, adjust it!
- The system works best with honest input

### 3. Use Quick Buttons

- Don't feel obligated to track every tiny task
- Use quick buttons for the small stuff
- Focus task tracking on significant activities

### 4. Let the System Guide You

- **Draining tasks at top of list?** Tackle them while fresh
- **Battery low?** Focus on charging activities
- **Streak at risk?** Just need a few more points!

### 5. Respect Low Battery Days

- **Late luteal phase = low battery** - this is normal!
- Goals are lower - meet them and rest
- Don't compare low-battery days to high-battery days

## Technical Implementation

### Services

**FlowCalculator**
- `calculateBatteryChange(energyLevel)` → battery %
- `calculateFlowPoints(energyLevel)` → points
- `isFlowGoalMet(points, goal)` → bool
- `updateStreak(...)` → new streak value
- `checkStreakMilestone(streak)` → milestone or null

**EnergyCalculator**
- `calculateSuggestedBattery(phase, cycleDay)` → battery %
- `calculateFlowGoal(phase, settings)` → points
- `getTodaySummary()` → full stats

**EnergyService**
- `addTaskEnergyConsumption(...)` → updates battery & flow
- `addRoutineStepEnergyConsumption(...)` → updates battery & flow
- `adjustBattery(change)` → manual adjustment
- `addFlowPoints(points)` → manual addition
- `removeEnergyConsumption(id)` → reverses changes

### Task Priority Integration

Priority boost only applies to tasks scheduled for today:

```dart
if (isScheduledToday && !hasDistantReminder) {
  score += 200 - ((task.energyLevel + 5) * 18);
}
```

This gives -5 energy tasks a +200 boost and +5 energy tasks a +20 boost, creating a 180-point range that encourages tackling draining work early.

## Testing

Comprehensive test suite covers:
- Battery calculation formulas
- Flow point calculations
- Streak tracking and milestones
- Personal record detection
- Energy consumption tracking
- Priority boost formula
- Menstrual cycle integration
- Data persistence and migration

See `test/unit/body_battery_flow_test.dart` and `test/unit/task_priority_energy_boost_test.dart` for details.

---

## Summary

The Body Battery & Flow system transforms simple task tracking into a holistic energy management system that:

✅ **Respects your cycle** - Goals adapt to your natural energy rhythms
✅ **Rewards hard work** - Draining tasks earn more flow points
✅ **Guides priorities** - Hard work gets prioritized when you have energy
✅ **Tracks progress** - Streaks and PRs provide motivation
✅ **Stays flexible** - Quick buttons and manual adjustments for real life
✅ **Provides insight** - Historical data shows patterns and progress

The result is a productivity system that works **with** your body, not against it.
