
import 'package:unity_message_ui/src/extensions/int_extension.dart';

extension DateTimeExtension on DateTime {
  String get formatTime {
    return "${hour.formatTimeUnit}:"
        "${minute.formatTimeUnit}:"
        "${second.formatTimeUnit}:"
        "${millisecond.formatTimeUnit}";
  }
}