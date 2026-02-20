import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/date_picker_utils.dart';
import 'friend_data_models.dart';
import 'friend_service.dart';
import '../shared/snackbar_utils.dart';

class FriendsTabScreen extends StatefulWidget {
  final bool showArchived;
  final VoidCallback? onFriendArchiveChanged;

  const FriendsTabScreen({
    super.key,
    this.showArchived = false,
    this.onFriendArchiveChanged,
  });

  @override
  State<FriendsTabScreen> createState() => FriendsTabScreenState();
}

class FriendsTabScreenState extends State<FriendsTabScreen> {
  List<Friend> _friends = [];
  bool _isLoading = true;

  /// Public method to refresh friends list from outside
  void refresh() {
    _loadFriends();
  }

  // Track swipe state for each friend
  final Map<String, double> _swipeOffsets = {};
  final Map<String, Timer?> _holdTimers = {};
  final Map<String, double> _holdProgress = {};

  // Available colors for friends
  final List<Color> _availableColors = [
    Colors.pink,
    Colors.purple,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    // Cancel all hold timers
    for (var timer in _holdTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await FriendService.loadFriends();
    // Do NOT call refreshAllBatteries here - it stores decayed battery without updating
    // lastUpdated, causing double-decay on every load. currentBattery getter computes dynamically.

    if (mounted) {
      setState(() {
        // Filter based on archived state
        _friends = friends.where((friend) =>
          widget.showArchived ? friend.isArchived : !friend.isArchived
        ).toList();
        _isLoading = false;
      });
    }
  }

  void addFriend() {
    final nameController = TextEditingController();
    Color selectedColor = _availableColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
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
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newFriend = Friend(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    color: selectedColor,
                    battery: 1.0, // Start at 100%
                    lastUpdated: DateTime.now(),
                    createdAt: DateTime.now(),
                  );

                  final navigator = Navigator.of(context);
                  FriendService.addFriend(newFriend, _friends).then((_) {
                    _loadFriends();
                    if (mounted) {
                      navigator.pop();
                    }
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _editFriend(Friend friend) {
    final nameController = TextEditingController(text: friend.name);
    Color selectedColor = friend.color;
    DateTime? selectedBirthday = friend.birthday;
    bool notifyLowBattery = friend.notifyLowBattery;
    bool notifyBirthday = friend.notifyBirthday;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Friend'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    final isSelected = color == selectedColor;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Birthday picker
                const Text('Birthday:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await DatePickerUtils.showStyledDatePicker(
                      context: context,
                      initialDate: selectedBirthday ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedBirthday = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.greyText),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_rounded, color: selectedBirthday != null ? selectedColor : AppColors.greyText),
                        const SizedBox(width: 12),
                        Text(
                          selectedBirthday != null
                              ? '${_months[selectedBirthday!.month - 1]} ${selectedBirthday!.day}'
                              : 'Not set',
                          style: TextStyle(
                            color: selectedBirthday != null ? null : AppColors.greyText,
                          ),
                        ),
                        const Spacer(),
                        if (selectedBirthday != null)
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedBirthday = null;
                              });
                            },
                            child: Icon(Icons.close, size: 20, color: AppColors.greyText),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Notification toggles
                const Text('Notifications:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Low battery reminder'),
                  subtitle: Text('Notify when below 30%', style: TextStyle(fontSize: 12, color: AppColors.greyText)),
                  value: notifyLowBattery,
                  onChanged: (value) {
                    setDialogState(() {
                      notifyLowBattery = value;
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Birthday reminder'),
                  subtitle: Text('Notify 3 days before', style: TextStyle(fontSize: 12, color: AppColors.greyText)),
                  value: notifyBirthday,
                  onChanged: selectedBirthday != null ? (value) {
                    setDialogState(() {
                      notifyBirthday = value;
                    });
                  } : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final updatedFriend = friend.copyWith(
                    name: name,
                    color: selectedColor,
                    birthday: selectedBirthday,
                    notifyLowBattery: notifyLowBattery,
                    notifyBirthday: notifyBirthday,
                  );

                  final navigator = Navigator.of(context);
                  FriendService.updateFriend(updatedFriend, _friends).then((_) {
                    _loadFriends();
                    if (mounted) {
                      navigator.pop();
                    }
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  void _editNotes(Friend friend) {
    final notesController = TextEditingController(text: friend.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.note_alt_outlined, color: friend.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notes - ${friend.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save details to remember for your next meeting: children\'s names, topics discussed, things to follow up on, or anything useful.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'e.g., Has 2 kids: Emma and Jack. Works at...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final notes = notesController.text.trim();
              final updatedFriend = friend.copyWith(
                notes: notes.isNotEmpty ? notes : null,
              );

              final navigator = Navigator.of(context);
              FriendService.updateFriend(updatedFriend, _friends).then((_) {
                _loadFriends();
                if (mounted) {
                  navigator.pop();
                }
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  void _archiveFriend(Friend friend) {
    final updatedFriend = friend.copyWith(isArchived: true);
    FriendService.updateFriend(updatedFriend, _friends).then((_) {
      _loadFriends();
      widget.onFriendArchiveChanged?.call(); // Refresh both tabs
      if (mounted) {
        SnackBarUtils.showCustom(context, '${friend.name} archived', backgroundColor: AppColors.purple, duration: const Duration(seconds: 2));
      }
    });
  }

  void _unarchiveFriend(Friend friend) {
    final updatedFriend = friend.copyWith(isArchived: false);
    FriendService.updateFriend(updatedFriend, _friends).then((_) {
      _loadFriends();
      widget.onFriendArchiveChanged?.call(); // Refresh both tabs
      if (mounted) {
        SnackBarUtils.showSuccess(context, '${friend.name} restored to active friends', duration: const Duration(seconds: 2));
      }
    });
  }

  void _showMeetingTypeDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text('Log Interaction')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How did you connect with ${friend.name}?',
              style: TextStyle(color: AppColors.greyText),
            ),
            const SizedBox(height: 16),
            ...MeetingType.values.map((type) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: type.color.withValues(alpha: 0.2),
                  child: Icon(type.icon, color: type.color),
                ),
                title: Text(type.label),
                subtitle: Text(
                  type == MeetingType.metInPerson
                      ? 'Full recharge — pick a date'
                      : '+${(type.batteryBoost * 100).toInt()}% added to current battery',
                  style: TextStyle(fontSize: 12, color: AppColors.greyText),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.greyText.withValues(alpha: 0.3)),
                ),
                onTap: () async {
                  if (type == MeetingType.metInPerson) {
                    // Close dialog first, then show date picker from screen context
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    final picked = await DatePickerUtils.showStyledDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      final meeting = Meeting(date: picked, type: type);
                      friend.addMeeting(meeting);
                      await FriendService.updateFriend(friend, _friends);
                      _loadFriends();
                      if (mounted) {
                        SnackBarUtils.showSuccess(
                          context,
                          '${friend.name}\'s battery recharged to ${friend.batteryPercentage}%!',
                          duration: const Duration(seconds: 2),
                        );
                      }
                    }
                  } else {
                    // For call/text: add boost to current battery
                    final meeting = Meeting(date: DateTime.now(), type: type);
                    friend.addMeeting(meeting);
                    final newBattery = friend.batteryPercentage;
                    final nav = Navigator.of(dialogContext);
                    await FriendService.updateFriend(friend, _friends);
                    _loadFriends();
                    if (mounted) {
                      nav.pop();
                      SnackBarUtils.showSuccess(
                        context,
                        '${friend.name}\'s battery boosted to $newBattery%!',
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
                },
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Directly show friends list - tabs handle the filtering now
    return _buildFriendsList();
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.showArchived ? Icons.archive_outlined : Icons.people_outline_rounded,
              size: 80,
              color: AppColors.greyText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.showArchived ? 'No archived friends' : 'No friends added yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.greyText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.showArchived
                  ? 'Archived friends will appear here'
                  : 'Add friends to track your friendships',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
            if (!widget.showArchived) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: addFriend,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Friend'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for FAB
      itemCount: _friends.length,
      onReorder: widget.showArchived
          ? (oldIndex, newIndex) {} // Disable reordering for archived friends
          : (oldIndex, newIndex) {
              FriendService.reorderFriends(oldIndex, newIndex, _friends).then((_) {
                _loadFriends();
              });
            },
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final batteryLevel = friend.currentBattery;
        final batteryPercentage = friend.batteryPercentage;
        final swipeOffset = _swipeOffsets[friend.id] ?? 0.0;
        final holdProgress = _holdProgress[friend.id] ?? 0.0;

        return GestureDetector(
          key: ValueKey(friend.id),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _swipeOffsets[friend.id] = (swipeOffset + details.delta.dx).clamp(-200.0, 200.0);
            });

            final offset = _swipeOffsets[friend.id]!;
            // Start hold timer if swiped far enough
            if ((offset < -150 || offset > 150) && _holdTimers[friend.id] == null) {
              _startHoldTimer(friend);
            } else if (offset.abs() < 150) {
              _cancelHoldTimer(friend.id);
            }
          },
          onHorizontalDragEnd: (details) {
            if (_holdTimers[friend.id] == null) {
              // No hold timer active, reset swipe
              setState(() {
                _swipeOffsets[friend.id] = 0.0;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                // Background indicators
                if (swipeOffset != 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: swipeOffset < 0
                            ? Colors.red
                            : (widget.showArchived ? AppColors.successGreen : AppColors.purple),
                        borderRadius: AppStyles.borderRadiusLarge,
                      ),
                      alignment: swipeOffset < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            swipeOffset < 0
                                ? Icons.delete_rounded
                                : (widget.showArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            swipeOffset < 0
                                ? 'Delete'
                                : (widget.showArchived ? 'Unarchive' : 'Archive'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (holdProgress > 0) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: holdProgress,
                                strokeWidth: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                // Sliding card
                Transform.translate(
                  offset: Offset(swipeOffset, 0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusLarge,
                    ),
                    child: InkWell(
                      onTap: () {
                        // Reset swipe state before editing
                        setState(() {
                          _swipeOffsets[friend.id] = 0.0;
                        });
                        _editFriend(friend);
                      },
                      borderRadius: AppStyles.borderRadiusLarge,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                  Row(
                    children: [
                      // Friend color indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: friend.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Friend name
                      Expanded(
                        child: Text(
                          friend.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Notes button
                      IconButton(
                        onPressed: () => _editNotes(friend),
                        icon: Icon(
                          friend.notes != null && friend.notes!.isNotEmpty
                              ? Icons.note_alt
                              : Icons.note_alt_outlined,
                          color: friend.color,
                        ),
                        tooltip: 'Notes',
                        iconSize: 24,
                      ),
                      // Recharge button (only show for active friends)
                      if (!widget.showArchived)
                        IconButton(
                          onPressed: () => _showMeetingTypeDialog(friend),
                          icon: const Icon(Icons.favorite_rounded),
                          color: Colors.red,
                          tooltip: 'Met today!',
                          iconSize: 28,
                        ),
                      if (!widget.showArchived)
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: AppColors.greyText.withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Battery progress bar with percentage text
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: AppStyles.borderRadiusSmall,
                        child: LinearProgressIndicator(
                          value: batteryLevel,
                          minHeight: 24,
                          backgroundColor: AppColors.greyText.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            friend.batteryColor,
                          ),
                        ),
                      ),
                      Text(
                        '$batteryPercentage%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: batteryLevel > 0.3
                              ? AppColors.white
                              : AppColors.greyText,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Last seen info (in-person only)
                  Text(
                    friend.lastSeenInPersonDate != null
                        ? 'Last seen: ${_formatLastSeen(friend.lastSeenInPersonDate!)}'
                        : 'Never met in person',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startHoldTimer(Friend friend) {
    const holdDuration = Duration(seconds: 2);
    const updateInterval = Duration(milliseconds: 50);
    int elapsed = 0;

    _holdTimers[friend.id] = Timer.periodic(updateInterval, (timer) {
      elapsed += updateInterval.inMilliseconds;
      final progress = elapsed / holdDuration.inMilliseconds;

      if (progress >= 1.0) {
        timer.cancel();
        _holdTimers[friend.id] = null;

        // Perform action based on swipe direction
        final offset = _swipeOffsets[friend.id] ?? 0.0;
        if (offset < 0) {
          // Swiped left - delete
          FriendService.deleteFriend(friend.id, _friends).then((_) {
            _loadFriends();
            if (mounted) {
              SnackBarUtils.showError(context, '${friend.name} deleted', duration: const Duration(seconds: 2));
            }
          });
        } else {
          // Swiped right - archive or unarchive depending on current view
          if (widget.showArchived) {
            _unarchiveFriend(friend);
          } else {
            _archiveFriend(friend);
          }
        }

        setState(() {
          _swipeOffsets[friend.id] = 0.0;
          _holdProgress[friend.id] = 0.0;
        });
      } else {
        setState(() {
          _holdProgress[friend.id] = progress;
        });
      }
    });
  }

  void _cancelHoldTimer(String friendId) {
    _holdTimers[friendId]?.cancel();
    _holdTimers[friendId] = null;
    setState(() {
      _holdProgress[friendId] = 0.0;
    });
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      // Show actual date for older entries
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}${date.year != now.year ? ', ${date.year}' : ''}';
    }
  }
}
