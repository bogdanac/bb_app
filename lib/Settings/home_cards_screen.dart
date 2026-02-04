import 'package:flutter/material.dart';
import 'app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class HomeCardsScreen extends StatefulWidget {
  const HomeCardsScreen({super.key});

  @override
  State<HomeCardsScreen> createState() => _HomeCardsScreenState();
}

class _HomeCardsScreenState extends State<HomeCardsScreen> {
  Map<String, bool> _cardStates = {};
  Map<String, bool> _moduleStates = {};
  List<String> _cardOrder = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final cardStates = await AppCustomizationService.loadAllCardStates();
    final moduleStates = await AppCustomizationService.loadAllModuleStates();
    final cardOrder = await AppCustomizationService.loadCardOrder();

    if (mounted) {
      setState(() {
        _cardStates = cardStates;
        _moduleStates = moduleStates;
        _cardOrder = cardOrder;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCard(String cardKey, bool value) async {
    await AppCustomizationService.setCardVisible(cardKey, value);
    setState(() {
      _cardStates[cardKey] = value;
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _cardOrder.removeAt(oldIndex);
      _cardOrder.insert(newIndex, item);
    });
    await AppCustomizationService.saveCardOrder(_cardOrder);
  }

  bool _isModuleEnabledForCard(CardInfo card) {
    if (card.dependsOnModule == null) return true;
    return _moduleStates[card.dependsOnModule] ?? true;
  }

  String _getModuleLabelForCard(CardInfo card) {
    if (card.dependsOnModule == null) return '';
    final module = AppCustomizationService.allModules.firstWhere(
      (m) => m.key == card.dependsOnModule,
      orElse: () => AppCustomizationService.allModules.first,
    );
    return module.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page Cards'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Drag to reorder cards. Toggle to show or hide them on the Home page.',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cardOrder.length,
                    onReorder: _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 4,
                            shadowColor: AppColors.black.withValues(alpha: 0.3),
                            borderRadius: AppStyles.borderRadiusLarge,
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final cardKey = _cardOrder[index];
                      final cardInfo = AppCustomizationService.allCards.firstWhere(
                        (c) => c.key == cardKey,
                        orElse: () => AppCustomizationService.allCards.first,
                      );
                      return _buildCardItem(cardInfo, index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardItem(CardInfo card, int index) {
    final isEnabled = _cardStates[card.key] ?? true;
    final moduleEnabled = _isModuleEnabledForCard(card);
    final effectivelyEnabled = isEnabled && moduleEnabled;

    return Container(
      key: ValueKey(card.key),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: effectivelyEnabled
              ? card.color.withValues(alpha: 0.3)
              : AppColors.normalCardBackground,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            // Drag handle
            Icon(
              Icons.drag_handle_rounded,
              color: AppColors.greyText.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 8),
            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: effectivelyEnabled ? 0.1 : 0.05),
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: Icon(
                card.icon,
                color: card.color.withValues(alpha: effectivelyEnabled ? 1.0 : 0.3),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            // Label and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: effectivelyEnabled ? null : AppColors.greyText,
                    ),
                  ),
                  if (!moduleEnabled && card.hasModuleDependency)
                    Text(
                      'Enable ${_getModuleLabelForCard(card)} in App Features',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.error.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    Text(
                      card.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText,
                      ),
                    ),
                ],
              ),
            ),
            // Switch
            Switch(
              value: isEnabled,
              activeThumbColor: card.color,
              onChanged: moduleEnabled
                  ? (value) => _toggleCard(card.key, value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
