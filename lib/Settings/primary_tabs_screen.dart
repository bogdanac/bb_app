import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_customization_service.dart';

/// Screen for selecting which modules appear as primary tabs on bottom navigation.
/// Primary tabs are immediately accessible, while secondary tabs go in the drawer.
class PrimaryTabsScreen extends StatefulWidget {
  const PrimaryTabsScreen({super.key});

  @override
  State<PrimaryTabsScreen> createState() => _PrimaryTabsScreenState();
}

class _PrimaryTabsScreenState extends State<PrimaryTabsScreen> {
  List<String> _primaryTabs = [];
  List<String> _secondaryTabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final primary = await AppCustomizationService.loadPrimaryTabs();
    final secondary = await AppCustomizationService.loadSecondaryTabsOrder();

    setState(() {
      _primaryTabs = primary;
      _secondaryTabs = secondary;
      _isLoading = false;
    });
  }

  Future<void> _togglePrimary(String moduleKey, bool isPrimary) async {
    final newPrimaryList = List<String>.from(_primaryTabs);
    final newSecondaryList = List<String>.from(_secondaryTabs);

    if (isPrimary) {
      // Moving from secondary to primary
      // Check if we've reached the limit
      if (newPrimaryList.length >= AppCustomizationService.maxPrimaryTabs - 1) {
        _showLimitReachedDialog();
        return;
      }
      newPrimaryList.add(moduleKey);
      newSecondaryList.remove(moduleKey);
    } else {
      // Moving from primary to secondary
      newPrimaryList.remove(moduleKey);
      newSecondaryList.add(moduleKey);
    }

    await AppCustomizationService.savePrimaryTabs(newPrimaryList);
    await AppCustomizationService.saveSecondaryTabsOrder(newSecondaryList);

    setState(() {
      _primaryTabs = newPrimaryList;
      _secondaryTabs = newSecondaryList;
    });
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.grey800,
        title: const Text('Maximum Reached', style: TextStyle(color: AppColors.white)),
        content: Text(
          'You can have up to ${AppCustomizationService.maxPrimaryTabs - 1} modules on the bottom navigation bar (plus Home). Uncheck another module first.',
          style: const TextStyle(color: AppColors.grey300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.lightPink)),
          ),
        ],
      ),
    );
  }

  void _onReorderPrimary(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _primaryTabs.removeAt(oldIndex);
      _primaryTabs.insert(newIndex, item);
    });
    AppCustomizationService.savePrimaryTabs(_primaryTabs);
  }

  void _onReorderSecondary(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _secondaryTabs.removeAt(oldIndex);
      _secondaryTabs.insert(newIndex, item);
    });
    AppCustomizationService.saveSecondaryTabsOrder(_secondaryTabs);
  }

  ModuleInfo _getModuleInfo(String moduleKey) {
    return AppCustomizationService.allModules.firstWhere(
      (m) => m.key == moduleKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.grey900,
        title: const Text('Primary Tabs', style: TextStyle(color: AppColors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_primaryTabs.isEmpty && _secondaryTabs.isEmpty)
              ? const Center(
                  child: Text(
                    'No modules enabled.\nEnable modules in App Features.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.grey300, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.grey800,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightPink.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.lightPink, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Tab Organization',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Primary tabs appear on bottom nav. Secondary tabs go in the drawer. '
                              'Drag to reorder within each section.',
                              style: TextStyle(color: AppColors.grey300, fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                      // Primary Tabs Section
                      _buildPrimaryTabsSection(),

                      const SizedBox(height: 24),

                      // Secondary Tabs Section
                      if (_secondaryTabs.isNotEmpty) _buildSecondaryTabsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPrimaryTabsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.yellow, size: 20),
              const SizedBox(width: 8),
              Text(
                'Primary Tabs (${_primaryTabs.length + 1}/${AppCustomizationService.maxPrimaryTabs})',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Bottom navigation bar • ${AppCustomizationService.maxPrimaryTabs - 1 - _primaryTabs.length} slots available',
            style: const TextStyle(color: AppColors.grey300, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _primaryTabs.length,
          onReorder: _onReorderPrimary,
          itemBuilder: (context, index) {
            final moduleKey = _primaryTabs[index];
            final moduleInfo = _getModuleInfo(moduleKey);
            return _buildModuleItem(
              moduleInfo,
              isPrimary: true,
              orderIndex: index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryTabsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.menu_rounded, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Secondary Tabs (${_secondaryTabs.length})',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Drawer menu • Drag to reorder',
            style: TextStyle(color: AppColors.grey300, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _secondaryTabs.length,
          onReorder: _onReorderSecondary,
          itemBuilder: (context, index) {
            final moduleKey = _secondaryTabs[index];
            final moduleInfo = _getModuleInfo(moduleKey);
            return _buildModuleItem(
              moduleInfo,
              isPrimary: false,
              orderIndex: index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildModuleItem(
    ModuleInfo moduleInfo, {
    required bool isPrimary,
    required int orderIndex,
  }) {
    return Container(
      key: ValueKey(moduleInfo.key),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.grey800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? moduleInfo.color.withValues(alpha: 0.5)
              : AppColors.grey700,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_handle, color: AppColors.grey300, size: 20),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: moduleInfo.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(moduleInfo.icon, color: moduleInfo.color, size: 24),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              moduleInfo.label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: moduleInfo.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: moduleInfo.color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '#${orderIndex + 1}',
                  style: TextStyle(
                    color: moduleInfo.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            isPrimary ? 'Bottom nav • ${moduleInfo.description}' : 'Drawer • ${moduleInfo.description}',
            style: TextStyle(
              color: isPrimary ? AppColors.grey300 : AppColors.grey300,
              fontSize: 13,
            ),
          ),
        ),
        trailing: Switch(
          value: isPrimary,
          onChanged: (value) => _togglePrimary(moduleInfo.key, value),
          activeThumbColor: moduleInfo.color,
          activeTrackColor: moduleInfo.color.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
