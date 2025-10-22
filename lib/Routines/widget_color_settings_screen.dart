import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'routine_widget_service.dart';
import '../shared/snackbar_utils.dart';

class WidgetColorSettingsScreen extends StatefulWidget {
  const WidgetColorSettingsScreen({super.key});

  @override
  State<WidgetColorSettingsScreen> createState() => _WidgetColorSettingsScreenState();
}

class _WidgetColorSettingsScreenState extends State<WidgetColorSettingsScreen> {
  Color _selectedColor = const Color(0xFF4CAF50); // Default vibrant green
  bool _isLoading = true;

  // Predefined color options - Much darker and more vibrant
  final List<Color> _colorOptions = [
    const Color(0xFFE13E76), // Material Pink
    const Color(0xFFDCCD49), // Bright Yellow
    const Color(0xFFED6F48), // Deep Orange
    const Color(0xFF3F96DC), // Material Blue
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFF673AB7), // Deep Purple
    const Color(0xFF9A4FA6), // Material Purple
    const Color(0xFF607D8B), // Blue Grey
    const Color(0xFF009688), // Teal
    const Color(0x807FDF81), // Material Green
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentColor();
  }

  Future<void> _loadCurrentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('widget_background_color') ?? _selectedColor.toARGB32();
    
    setState(() {
      _selectedColor = Color(colorValue);
      _isLoading = false;
    });
  }

  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('widget_background_color', color.toARGB32());
    
    setState(() {
      _selectedColor = color;
    });
    
    // Update the widget with the new color
    await RoutineWidgetService.refreshWidgetColor();
    
    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Widget color updated!');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Widget Color'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Color'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Color Preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.greyText,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.widgets_rounded,
                    size: 40,
                    color: AppColors.greyText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Widget Color',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is how your routine widget will look',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Choose a Color',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Color Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _colorOptions.length,
              itemBuilder: (context, index) {
                final color = _colorOptions[index];
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                
                return GestureDetector(
                  onTap: () => _saveColor(color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppStyles.borderRadiusMedium,
                      border: Border.all(
                        color: isSelected ? AppColors.lightGreen : AppColors.greyText,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.lightGreen,
                            size: 24,
                          )
                        : null,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Custom Color Picker Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppStyles.borderRadiusLarge,
                border: Border.all(
                  color: AppColors.greyText,
                ),
              ),
              child: InkWell(
                onTap: _showCustomColorPicker,
                borderRadius: AppStyles.borderRadiusLarge,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          color: AppColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Color',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pick any color you like',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Color'),
        content: SizedBox(
          width: 350,
          height: 300,
          child: _buildColorPicker(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        // Generate a variety of vibrant colors
        final hue = (index % 8) * 45.0; // 8 different hues across the row
        final lightness = 0.35 + (index ~/ 8) * 0.05; // Much darker, more variations
        final saturation = 0.6 + (index % 3) * 0.1; // More saturated variations
        final color = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
        
        return GestureDetector(
          onTap: () {
            _saveColor(color);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.greyText,
              ),
            ),
          ),
        );
      },
    );
  }
}