import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tasks_data_models.dart';

// TASK EDIT SCREEN
class TaskEditScreen extends StatefulWidget {
  final Task? task;
  final List<TaskCategory> categories;
  final Function(Task) onSave;

  const TaskEditScreen({
    Key? key,
    this.task,
    required this.categories,
    required this.onSave,
  }) : super(key: key);

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _selectedCategoryIds = [];
  DateTime? _deadline;
  DateTime? _reminderTime;
  bool _isImportant = false;
  TaskRecurrence? _recurrence;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      final task = widget.task!;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _selectedCategoryIds = List.from(task.categoryIds);
      _deadline = task.deadline;
      _reminderTime = task.reminderTime;
      _isImportant = task.isImportant;
      _recurrence = task.recurrence;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Categories
            const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.categories.map((category) {
                final isSelected = _selectedCategoryIds.contains(category.id);
                return FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  backgroundColor: category.color.withOpacity(0.2),
                  selectedColor: category.color.withOpacity(0.5),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(category.id);
                      } else {
                        _selectedCategoryIds.remove(category.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Important
            SwitchListTile(
              title: const Text('Important'),
              subtitle: const Text('Mark this task as important'),
              value: _isImportant,
              onChanged: (value) => setState(() => _isImportant = value),
            ),
            const SizedBox(height: 16),

            // Deadline
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Deadline'),
                subtitle: _deadline != null
                    ? Text(DateFormat('MMM dd, yyyy').format(_deadline!))
                    : const Text('No deadline set'),
                trailing: _deadline != null
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => setState(() => _deadline = null),
                )
                    : null,
                onTap: _selectDeadline,
              ),
            ),
            const SizedBox(height: 8),

            // Reminder Time
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: const Text('Reminder Time'),
                subtitle: _reminderTime != null
                    ? Text(DateFormat('HH:mm').format(_reminderTime!))
                    : const Text('No reminder set'),
                trailing: _reminderTime != null
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => setState(() => _reminderTime = null),
                )
                    : null,
                onTap: _selectReminderTime,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime != null
          ? TimeOfDay.fromDateTime(_reminderTime!)
          : TimeOfDay.now(),
    );
    if (time != null) {
      final now = DateTime.now();
      setState(() {
        _reminderTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      });
    }
  }

  _saveTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    final task = Task(
      id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryIds: _selectedCategoryIds,
      deadline: _deadline,
      reminderTime: _reminderTime,
      isImportant: _isImportant,
      recurrence: _recurrence,
      isCompleted: widget.task?.isCompleted ?? false,
      completedAt: widget.task?.completedAt,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
    );

    widget.onSave(task);
    Navigator.pop(context);
  }
}
