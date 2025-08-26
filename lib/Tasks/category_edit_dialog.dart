import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// CATEGORY EDIT DIALOG
class CategoryEditDialog extends StatefulWidget {
  final String? initialName;
  final Color? initialColor;
  final Function(String, Color) onSave;

  const CategoryEditDialog({
    super.key,
    this.initialName,
    this.initialColor,
    required this.onSave,
  });

  @override
  State<CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<CategoryEditDialog> {
  final _nameController = TextEditingController();
  late Color _selectedColor;

  final List<Color> _availableColors = [
    AppColors.error, // Red for important categories only
    AppColors.pink,
    AppColors.purple,
    AppColors.coral,
    AppColors.orange,
    AppColors.yellow,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.amber,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _selectedColor = widget.initialColor ?? AppColors.purple; // Default to purple
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? 'Add Category' : 'Edit Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableColors.map((color) {
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _selectedColor == color
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: _selectedColor == color
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              widget.onSave(_nameController.text.trim(), _selectedColor);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}