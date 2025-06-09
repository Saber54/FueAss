import 'package:intl/intl.dart';

class DateUtils {
  static String formatTimestamp(DateTime timestamp) {
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} Jahre';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} Monate';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} Tage';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} Stunden';
    } else {
      return '${difference.inMinutes} Minuten';
    }
  }

  static DateTime parseApiDate(String dateString) {
    return DateTime.parse(dateString).toLocal();
  }
}