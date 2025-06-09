class LogEntry {
  final String id;
  final String text;
  final String authorDeviceId;
  final DateTime timestamp;
  final bool isEditable;

  LogEntry({
    required this.id,
    required this.text,
    required this.authorDeviceId,
    DateTime? timestamp,
    this.isEditable = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'],
      text: json['text'],
      authorDeviceId: json['authorDeviceId'],
      timestamp: DateTime.parse(json['timestamp']),
      isEditable: json['isEditable'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'authorDeviceId': authorDeviceId,
    'timestamp': timestamp.toIso8601String(),
    'isEditable': isEditable,
  };
}