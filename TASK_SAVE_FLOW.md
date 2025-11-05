# Task Save Flow Documentation

## Overview
Tasks go through multiple save stages to balance performance (immediate UI feedback) with data persistence.

## Save Stages

### 1. Auto-Save (Memory Only)
**When**: Triggered 500ms after user stops typing
**Purpose**: Quick UI feedback, prevent data loss during editing
**Implementation**:
- Calls `widget.onSave(task, isAutoSave: true)`
- Updates in-memory `_tasks` list in TodoScreen
- Does NOT save to SharedPreferences (expensive operation)
- Sets `_hasUnsavedChanges = false` (shows "Saved" indicator)

### 2. Final Save (Disk Persistence)
**When**: When user closes the TaskEditScreen
**Purpose**: Persist data to disk
**Implementation**:
- Triggered by `onPopInvokedWithResult` when back button pressed
- Only runs if `_hasUnsavedChanges == true`
- Calls `_saveTaskImmediately()` which calls `widget.onSave(task, isAutoSave: false)`
- Saves entire `_tasks` list to SharedPreferences
- Updates Android widget
- Schedules notifications

## THE BUG

**Problem**: Tasks created/edited but not saved to disk after auto-save

**Root Cause**:
1. User types "skip test" → auto-save fires
2. Auto-save calls `onSave(isAutoSave: true)` → adds to memory only
3. Auto-save sets `_hasUnsavedChanges = false` → shows "Saved"
4. User presses back → checks `_hasUnsavedChanges` → it's FALSE
5. Skips `_saveTaskImmediately()` → never saves to disk
6. On refresh, task is gone (loaded from disk which doesn't have it)

## THE FIX

**Option 1**: Track disk save separately from auto-save
- Add `_isSavedToDisk` flag
- Auto-save doesn't set this flag
- Final save sets it
- Back button checks this flag

**Option 2**: Always final save on close if task exists
- Don't check `_hasUnsavedChanges` in dispose/onPop
- Always call `_saveTaskImmediately()` if title is not empty
- Risk: Double save if no changes after auto-save

**Option 3**: Auto-save should save to disk occasionally
- Every 5th auto-save, actually save to disk
- Or save to disk after 10 seconds of inactivity

**Option 4** (RECOMMENDED): Call final save in dispose()
- Change dispose() to call `_saveTaskImmediately()` instead of `_autoSaveTask()`
- This ensures disk save happens even if `_hasUnsavedChanges` is false

## Current State
- Auto-save: isAutoSave=true → memory only
- Final save: isAutoSave=false → disk persistence
- Bug: Final save skipped if auto-save cleared the unsaved flag
