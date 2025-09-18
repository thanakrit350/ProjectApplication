// utils/time_helper.dart

String formatTime(String? timeString) {
  if (timeString == null || timeString.isEmpty) return 'ไม่ระบุ';

  try {
    final dateTime = DateTime.parse(timeString);
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;

    return '$hour:$minute $period';
  } catch (e) {
    return 'ไม่ระบุ';
  }
}
