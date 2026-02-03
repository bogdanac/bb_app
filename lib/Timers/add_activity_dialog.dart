import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'timer_data_models.dart';

class AddActivityDialog extends StatefulWidget {
  final Function(Activity) onAdd;

  const AddActivityDialog({super.key, required this.onAdd});

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final activity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    widget.onAdd(activity);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      title: const Text('New Activity'),
      content: TextField(
        controller: _nameController,
        decoration: AppStyles.inputDecoration(
          hintText: 'e.g., Piano Learning',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: AppStyles.textButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: AppStyles.elevatedButtonStyle(backgroundColor: AppColors.purple),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
