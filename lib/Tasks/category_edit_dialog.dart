import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

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

  /// Show as a full-screen page
  static Future<void> show(
    BuildContext context, {
    String? initialName,
    Color? initialColor,
    required Function(String, Color) onSave,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryEditDialog(
          initialName: initialName,
          initialColor: initialColor,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<CategoryEditDialog> {
  final _nameController = TextEditingController();
  late Color _selectedColor;

  final List<Color> _availableColors = [
    AppColors.coral,
    AppColors.orange,
    AppColors.yellow,
    AppColors.red,
    AppColors.greyText,
    AppColors.successGreen,
    AppColors.lightPink,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _selectedColor = widget.initialColor ?? AppColors.purple;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isNotEmpty) {
      widget.onSave(_nameController.text.trim(), _selectedColor);
      Navigator.pop(context);
    }
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;

    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Category' : 'Add Category'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _canSave ? _submit : null,
              icon: Icon(
                Icons.check_rounded,
                color: _canSave ? AppColors.successGreen : AppColors.grey300,
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  color: _canSave ? AppColors.successGreen : AppColors.grey300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isEmpty ? 'Category Name' : _nameController.text,
                    style: TextStyle(
                      color: _nameController.text.isEmpty ? AppColors.grey300 : AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            _buildFieldContainer(
              icon: Icons.label_rounded,
              iconColor: AppColors.purple,
              label: 'Category Name',
              child: TextField(
                controller: _nameController,
                decoration: AppStyles.inputDecoration(
                  hintText: 'e.g., Work, Personal, Health',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: widget.initialName == null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            _buildFieldContainer(
              icon: Icons.palette_rounded,
              iconColor: _selectedColor,
              label: 'Color',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _availableColors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check_rounded, color: AppColors.white, size: 24)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContainer({
    required IconData icon,
    required Color iconColor,
    required String label,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration(color: AppColors.homeCardBackground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}
