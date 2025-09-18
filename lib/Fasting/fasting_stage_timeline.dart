import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FastingStageTimeline extends StatefulWidget {
  final Duration elapsedTime;
  final bool isFasting;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const FastingStageTimeline({
    super.key,
    required this.elapsedTime,
    required this.isFasting,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<FastingStageTimeline> createState() => _FastingStageTimelineState();
}

class _FastingStageTimelineState extends State<FastingStageTimeline>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  int selectedStageIndex = -1;
  bool _isManuallySelected = false;

  // Define all fasting stages with their hour ranges and details
  static final List<Map<String, dynamic>> _stages = [
    {
      'name': 'Digestion Phase',
      'hours': '0-4h',
      'startHour': 0,
      'endHour': 4,
      'color': AppColors.lightGreen,
      'icon': Icons.restaurant,
      'description': 'Your body processes the last meal and begins the transition to fasting.',
      'benefits': ['Blood sugar stabilizes', 'Insulin levels drop', 'Digestive rest begins'],
    },
    {
      'name': 'Glycogen Depletion',
      'hours': '4-8h',
      'startHour': 4,
      'endHour': 8,
      'color': AppColors.yellow,
      'icon': Icons.battery_charging_full,
      'description': 'Your body switches from glucose to stored glycogen for energy.',
      'benefits': ['Liver glycogen depletion', 'Metabolic flexibility', 'Fat mobilization starts'],
    },
    {
      'name': 'Fat Burning',
      'hours': '8-12h',
      'startHour': 8,
      'endHour': 12,
      'color': AppColors.pastelGreen,
      'icon': Icons.local_fire_department,
      'description': 'Your body begins burning fat stores as the primary fuel source.',
      'benefits': ['Lipolysis activation', 'Free fatty acid release', 'Weight loss acceleration'],
    },
    {
      'name': 'Ketosis Initiation',
      'hours': '12-16h',
      'startHour': 12,
      'endHour': 16,
      'color': AppColors.purple,
      'icon': Icons.psychology,
      'description': 'Ketone production begins, providing clean fuel for your brain.',
      'benefits': ['Ketone production', 'Mental clarity', 'Reduced hunger'],
    },
    {
      'name': 'Deep Ketosis',
      'hours': '16-20h',
      'startHour': 16,
      'endHour': 20,
      'color': AppColors.pink,
      'icon': Icons.flash_on,
      'description': 'Deep ketosis provides sustained energy and mental focus.',
      'benefits': ['High ketone levels', 'Energy surge', 'Appetite suppression'],
    },
    {
      'name': 'Growth Hormone Peak',
      'hours': '20-24h',
      'startHour': 20,
      'endHour': 24,
      'color': AppColors.red,
      'icon': Icons.fitness_center,
      'description': 'Human Growth Hormone levels reach peak elevation.',
      'benefits': ['5x HGH increase', 'Muscle preservation', 'Anti-aging effects'],
    },
    {
      'name': 'Autophagy Activation',
      'hours': '24-36h',
      'startHour': 24,
      'endHour': 36,
      'color': AppColors.successGreen,
      'icon': Icons.refresh,
      'description': 'Cellular repair and regeneration processes activate.',
      'benefits': ['Cellular cleanup', 'Protein recycling', 'Longevity benefits'],
    },
    {
      'name': 'Enhanced Autophagy',
      'hours': '36-48h',
      'startHour': 36,
      'endHour': 48,
      'color': AppColors.lightGreen,
      'icon': Icons.auto_awesome,
      'description': 'Peak cellular regeneration and maximum health benefits.',
      'benefits': ['Maximum autophagy', 'Stem cell regeneration', 'Disease prevention'],
    },
    {
      'name': 'Maximum Benefits',
      'hours': '48h+',
      'startHour': 48,
      'endHour': 72,
      'color': AppColors.yellow,
      'icon': Icons.star,
      'description': 'Ultimate metabolic transformation and health optimization.',
      'benefits': ['Immune system reset', 'Metabolic flexibility', 'Longevity activation'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Set initial selected stage based on current progress
    _updateSelectedStage();
  }

  @override
  void didUpdateWidget(FastingStageTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.elapsedTime != oldWidget.elapsedTime) {
      // Only auto-update if user hasn't manually selected a stage or timeline is collapsed
      if (!_isManuallySelected || !widget.isExpanded) {
        _updateSelectedStage();
      }
    }
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
        // Reset manual selection when collapsing
        _isManuallySelected = false;
      }
    }
  }

  void _updateSelectedStage() {
    final hoursElapsed = widget.elapsedTime.inHours;
    for (int i = 0; i < _stages.length; i++) {
      final stage = _stages[i];
      if (hoursElapsed >= stage['startHour'] && 
          (hoursElapsed < stage['endHour'] || i == _stages.length - 1)) {
        if (mounted) {
          setState(() {
            selectedStageIndex = i;
          });
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildCompactTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current stage info
          if (selectedStageIndex >= 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _stages[selectedStageIndex]['color'].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _stages[selectedStageIndex]['color'].withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _stages[selectedStageIndex]['color'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _stages[selectedStageIndex]['icon'],
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stages[selectedStageIndex]['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _stages[selectedStageIndex]['color'],
                                ),
                              ),
                              Text(
                                _stages[selectedStageIndex]['hours'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _stages[selectedStageIndex]['color'].withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onToggleExpanded,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Timeline progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Row(
              children: _stages.asMap().entries.map((entry) {
                final index = entry.key;
                final stage = entry.value;
                final isCurrentStage = index == selectedStageIndex;
                final isPastStage = index < selectedStageIndex;
                
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: isPastStage 
                          ? stage['color'].withOpacity(0.9)
                          : isCurrentStage 
                              ? stage['color']
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Stage indicators row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _stages.asMap().entries.map((entry) {
                final index = entry.key;
                final stage = entry.value;
                final isCurrentStage = index == selectedStageIndex;
                final isPastStage = index < selectedStageIndex;
                
                return GestureDetector(
                  onTap: () => widget.onToggleExpanded(),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPastStage 
                          ? stage['color'].withOpacity(0.3)
                          : isCurrentStage 
                              ? stage['color'].withOpacity(0.2)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentStage 
                          ? Border.all(color: stage['color'], width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stage['icon'],
                          size: 12,
                          color: isPastStage || isCurrentStage 
                              ? stage['color']
                              : Colors.white30,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stage['hours'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentStage ? FontWeight.bold : FontWeight.normal,
                            color: isPastStage || isCurrentStage 
                                ? stage['color']
                                : Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTimeline() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fasting Journey',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onToggleExpanded,
                      child: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Stage tabs
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _stages.length,
                    itemBuilder: (context, index) {
                      final stage = _stages[index];
                      final isCurrentStage = index == selectedStageIndex;
                      final isPastStage = index < selectedStageIndex;
                      final isSelected = index == (selectedStageIndex >= 0 ? selectedStageIndex : 0);
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedStageIndex = index;
                            _isManuallySelected = true;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? stage['color']
                                : isPastStage 
                                    ? stage['color'].withOpacity(0.3)
                                    : stage['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                            border: isCurrentStage && !isSelected
                                ? Border.all(color: stage['color'], width: 2)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                stage['icon'],
                                size: 16,
                                color: isSelected ? Colors.white : stage['color'],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                stage['hours'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : stage['color'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Selected stage details
                if (selectedStageIndex >= 0) _buildStageDetails(_stages[selectedStageIndex]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageDetails(Map<String, dynamic> stage) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(stage['name']),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: stage['color'].withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stage['color'].withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: stage['color'],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    stage['icon'],
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: stage['color'],
                        ),
                      ),
                      Text(
                        stage['hours'],
                        style: TextStyle(
                          fontSize: 12,
                          color: stage['color'].withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              stage['description'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Benefits
            const Text(
              'Key Benefits:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            
            ...stage['benefits'].map<Widget>((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: stage['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompactTimeline(),
        if (widget.isExpanded) _buildExpandedTimeline(),
      ],
    );
  }
}