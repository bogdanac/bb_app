import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import 'friend_data_models.dart';
import 'friend_service.dart';

class FriendsTabScreen extends StatefulWidget {
  const FriendsTabScreen({super.key});

  @override
  State<FriendsTabScreen> createState() => FriendsTabScreenState();
}

class FriendsTabScreenState extends State<FriendsTabScreen> {
  List<Friend> _friends = [];
  bool _isLoading = true;
  bool _showArchived = false; // Toggle for showing archived friends

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
    // Refresh battery levels based on decay
    await FriendService.refreshAllBatteries(friends);

    if (mounted) {
      setState(() {
        // Filter based on archived state
        _friends = friends.where((friend) =>
          _showArchived ? friend.isArchived : !friend.isArchived
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                  final updatedFriend = friend.copyWith(
                    name: name,
                    color: selectedColor,
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
          child: TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'Personal Notes',
              border: const OutlineInputBorder(),
              hintText: 'Add personal notes about ${friend.name}...',
              alignLabelWithHint: true,
            ),
            maxLines: null,
            expands: true,
            autofocus: true,
            textAlignVertical: TextAlignVertical.top,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.name} archived'),
            backgroundColor: AppColors.purple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _unarchiveFriend(Friend friend) {
    final updatedFriend = friend.copyWith(isArchived: false);
    FriendService.updateFriend(updatedFriend, _friends).then((_) {
      _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.name} restored to active friends'),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _rechargeBattery(Friend friend) {
    FriendService.updateFriendBattery(friend.id, 1.0, _friends).then((_) {
      _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.name}\'s friendship battery recharged to 100%!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Filter toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Active'),
                      icon: Icon(Icons.people_rounded, size: 20),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Archived'),
                      icon: Icon(Icons.archive_rounded, size: 20),
                    ),
                  ],
                  selected: {_showArchived},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showArchived = newSelection.first;
                    });
                    _loadFriends();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _showArchived ? AppColors.purple : AppColors.successGreen;
                      }
                      return AppColors.greyText.withValues(alpha: 0.1);
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Friends list
        Expanded(
          child: _buildFriendsList(),
        ),
      ],
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showArchived ? Icons.archive_outlined : Icons.people_outline_rounded,
              size: 80,
              color: AppColors.greyText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _showArchived ? 'No archived friends' : 'No friends added yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.greyText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showArchived
                  ? 'Archived friends will appear here'
                  : 'Add friends to track your friendships',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyText,
              ),
            ),
            if (!_showArchived) ...[
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
      padding: const EdgeInsets.all(16),
      itemCount: _friends.length,
      onReorder: _showArchived
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
              _swipeOffsets[friend.id] = (swipeOffset + details.delta.dx).clamp(-150.0, 150.0);
            });

            final offset = _swipeOffsets[friend.id]!;
            // Start hold timer if swiped far enough
            if ((offset < -100 || offset > 100) && _holdTimers[friend.id] == null) {
              _startHoldTimer(friend);
            } else if (offset.abs() < 100) {
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
                            : (_showArchived ? AppColors.successGreen : AppColors.purple),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: swipeOffset < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            swipeOffset < 0
                                ? Icons.delete_rounded
                                : (_showArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            swipeOffset < 0
                                ? 'Delete'
                                : (_showArchived ? 'Unarchive' : 'Archive'),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Reset swipe state before editing
                        setState(() {
                          _swipeOffsets[friend.id] = 0.0;
                        });
                        _editFriend(friend);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                  Row(
                    children: [
                      // Drag handle for reordering (only show for active friends)
                      if (!_showArchived) ...[
                        Icon(
                          Icons.drag_handle_rounded,
                          color: AppColors.greyText.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
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
                      if (!_showArchived)
                        IconButton(
                          onPressed: () => _rechargeBattery(friend),
                          icon: const Icon(Icons.favorite_rounded),
                          color: Colors.red,
                          tooltip: 'Met today!',
                          iconSize: 28,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Battery progress bar with percentage text
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                  // Last updated info
                  Text(
                    'Last updated: ${_formatLastUpdated(friend.lastUpdated)}',
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${friend.name} deleted'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        } else {
          // Swiped right - archive or unarchive depending on current view
          if (_showArchived) {
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

  String _formatLastUpdated(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }
}
