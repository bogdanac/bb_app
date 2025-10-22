import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/snackbar_utils.dart';
class RoutineScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const RoutineScreen({super.key, required this.onCompleted});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final List<Map<String, dynamic>> _routineItems = [
    {'text': '☀️ Stretch and breathe', 'completed': false},
    {'text': '💧 Drink a glass of water', 'completed': false},
    {'text': '🧘 5 minutes meditation', 'completed': false},
    {'text': '📝 Write 3 gratitudes', 'completed': false},
  ];

  @override
  Widget build(BuildContext context) {
    final completedCount = _routineItems.where((item) => item['completed']).length;
    final allCompleted = completedCount == _routineItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine'),
        backgroundColor: AppColors.orange.withValues(alpha: 0.3),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.orange.withValues(alpha: 0.3),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        '✨ Let\'s Go!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete your routine ($completedCount/${_routineItems.length})',
                        style: const TextStyle(fontSize: 16, color: AppColors.greyText),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: completedCount / _routineItems.length,
                        backgroundColor: AppColors.greyText,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _routineItems.length,
                  itemBuilder: (context, index) {
                    final item = _routineItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CheckboxListTile(
                        title: Text(
                          item['text'],
                          style: TextStyle(
                            fontSize: 16,
                            decoration: item['completed']
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        value: item['completed'],
                        onChanged: (bool? value) {
                          setState(() {
                            _routineItems[index]['completed'] = value ?? false;
                          });
                        },
                        activeColor: AppColors.orange,
                      ),
                    );
                  },
                ),
              ),
              if (allCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onCompleted();
                      Navigator.pop(context);
                      SnackBarUtils.showSuccess(context, '🎉 Routine completed! Great job!');
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Complete Routine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}