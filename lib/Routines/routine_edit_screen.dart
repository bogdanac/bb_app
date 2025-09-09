import 'package:flutter/material.dart';
import 'routine_data_models.dart';
import '../theme/app_colors.dart';

// ROUTINE EDIT SCREEN
class RoutineEditScreen extends StatefulWidget {
  final Routine? routine;
  final Function(Routine) onSave;

  const RoutineEditScreen({
    super.key,
    this.routine,
    required this.onSave,
  });

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  final _titleController = TextEditingController();
  List<RoutineItem> _items = [];
  Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7}; // Default to all days

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _titleController.text = widget.routine!.title;
      _items = List.from(widget.routine!.items);
      _activeDays = Set<int>.from(widget.routine!.activeDays);
    }
  }

  void _addItem() {
    setState(() {
      _items.add(RoutineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        isCompleted: false,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _saveRoutine() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine title')),
      );
      return;
    }

    if (_items.isEmpty || _items.any((item) => item.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step and fill in all text fields')),
      );
      return;
    }

    final routine = Routine(
      id: widget.routine?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      items: _items,
      reminderEnabled: widget.routine?.reminderEnabled ?? false,
      reminderHour: widget.routine?.reminderHour ?? 8,
      reminderMinute: widget.routine?.reminderMinute ?? 0,
      activeDays: _activeDays,
    );

    widget.onSave(routine);
    Navigator.pop(context);
  }

  Widget _buildDayButton(int day) {
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final isSelected = _activeDays.contains(day);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _activeDays.remove(day);
          } else {
            _activeDays.add(day);
          }
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.yellow 
              : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected 
                ? AppColors.yellow 
                : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Text(
            dayNames[day - 1],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'Add Routine' : 'Edit Routine'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Routine Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Days of the week selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Days',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int day = 1; day <= 7; day++)
                          _buildDayButton(day),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Steps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _items.isEmpty
                  ? const Center(
                child: Text(
                  'No steps added yet.\nTap "Add Step" to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ReorderableListView.builder(
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle_rounded, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: item.text),
                              decoration: const InputDecoration(
                                hintText: 'Enter step description...',
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                item.text = value;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: AppColors.lightYellow),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}