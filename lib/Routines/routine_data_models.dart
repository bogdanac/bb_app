// ROUTINE DATA MODELS
class Routine {
  final String id;
  String title;
  List<RoutineItem> items;

  Routine({
    required this.id,
    required this.title,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
  };

  static Routine fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'],
    title: json['title'],
    items: (json['items'] as List)
        .map((item) => RoutineItem.fromJson(item))
        .toList(),
  );
}

class RoutineItem {
  final String id;
  String text;
  bool isCompleted;

  RoutineItem({
    required this.id,
    required this.text,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isCompleted': isCompleted,
  };

  static RoutineItem fromJson(Map<String, dynamic> json) => RoutineItem(
    id: json['id'],
    text: json['text'],
    isCompleted: json['isCompleted'],
  );
}