import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

class MorningRoutineScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const MorningRoutineScreen({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<MorningRoutineScreen> createState() => _MorningRoutineScreenState();
}

class _MorningRoutineScreenState extends State<MorningRoutineScreen> {
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
        title: const Text('Morning Routine'),
        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        '🌅 Good Morning!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete your morning routine ($completedCount/${_routineItems.length})',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: completedCount / _routineItems.length,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
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
                        activeColor: Theme.of(context).colorScheme.secondary,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Morning routine completed! Have a great day!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Complete Routine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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