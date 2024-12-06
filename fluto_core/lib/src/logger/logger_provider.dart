import 'dart:async';
import 'dart:developer';
import 'package:fluto_core/src/extension/fluto_log_extension.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fluto_core/src/model/fluto_log_model.dart';
import 'package:fluto_core/src/model/fluto_log_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlutoLoggerProvider with ChangeNotifier {
  static const String _hiveBoxName = 'fluto_logs';
  Box<FlutoLogModel>? _logBox;
  List<FlutoLogModel> _localLogData = [];
  List<FlutoLogModel> get localLogData => List.unmodifiable(_localLogData);
  Timer? _debounce;
  DateTimeRange? dateTimeRange;
  Supabase? supabase;
  FlutoLogType selectedLogType = FlutoLogType.print;

  set selectLogType(FlutoLogType logType) {
    selectedLogType = logType;
    notifyListeners();
    getAllLogs();
  }

  Future<void> initHive({
    Supabase? supabase,
  }) async {
    _logBox = await Hive.openBox<FlutoLogModel>(_hiveBoxName);
    this.supabase = supabase;
    syncLocalLogs();
  }

  Future<void> removeLog(FlutoLogModel logModel) async {
    final key = _logBox?.keys.firstWhere(
      (key) => _logBox?.get(key)?.logTime == logModel.logTime,
      orElse: () => null,
    );
    if (key != null) {
      await _logBox?.delete(key);
      _localLogData.remove(logModel);
      notifyListeners();
    }
  }

  void onDateRangeChange(DateTimeRange range, {String message = ""}) {
    dateTimeRange = range;
    onSearchLogs(
      dateTime: range,
      logMessage: message,
    );
    notifyListeners();
  }

  void clearDateRange({String logMessage = ""}) {
    _localLogData = [..._localLogData].map(
      (element) {
        bool isMessageMatch = element.logMessage.contains(logMessage);
        if (element.logType == FlutoLogType.error.toString()) {
          isMessageMatch = isMessageMatch &&
              ((element.stackTraceString ?? "").contains(logMessage) ||
                  (element.errorString ?? "").contains(logMessage));
        }

        return element.copyWith(
          canShow: isMessageMatch,
        );
      },
    ).toList();
    dateTimeRange = null;
    notifyListeners();
  }

  Future<void> showPicker(
    BuildContext context,
    TextEditingController logSearchController,
  ) async {
    // Show Date Range Picker
    DateTimeRange? dateTimeRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(
        const Duration(days: 100),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 100),
      ),
      initialDateRange: this.dateTimeRange,
    );

    if (dateTimeRange != null) {
      // Show Time Picker for Start Time
      TimeOfDay? startTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: "Select Start Time",
      );

      if (startTime == null) return; // User canceled the start time picker

      // Show Time Picker for End Time
      TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: startTime,
        helpText: "Select End Time",
      );

      if (endTime == null) return; // User canceled the end time picker

      // Combine date range with start and end times
      DateTime startDateTime = DateTime(
        dateTimeRange.start.year,
        dateTimeRange.start.month,
        dateTimeRange.start.day,
        startTime.hour,
        startTime.minute,
      );

      DateTime endDateTime = DateTime(
        dateTimeRange.end.year,
        dateTimeRange.end.month,
        dateTimeRange.end.day,
        endTime.hour,
        endTime.minute,
      );

      // Notify the provider with the new date and time range
      onDateRangeChange(
        DateTimeRange(start: startDateTime, end: endDateTime),
        message: logSearchController.text.trim(),
      );
    }
  }

  void clearSearch() {
    _localLogData = [..._localLogData].map(
      (element) {
        final isDateMatch = dateTimeRange.inRange(
          dateTime: element.logTime,
        );

        return element.copyWith(
          canShow: isDateMatch,
        );
      },
    ).toList();
    notifyListeners();
  }

  void onSearchLogs({
    String logMessage = "",
    DateTimeRange? dateTime,
  }) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      filterLogs(
        logMessage: logMessage,
      );
    });
  }

  void filterLogs({String logMessage = ""}) {
    _localLogData = [..._localLogData].map(
      (element) {
        bool isMessageMatch = element.logMessage.contains(logMessage);
        if (element.logType == FlutoLogType.error.toString()) {
          isMessageMatch = isMessageMatch &&
              ((element.stackTraceString ?? "").contains(logMessage) ||
                  (element.errorString ?? "").contains(logMessage));
        }
        final isDateMatch = dateTimeRange.inRange(dateTime: element.logTime);
        return element.copyWith(
          canShow: isMessageMatch && isDateMatch,
        );
      },
    ).toList();
    notifyListeners();
  }

  void syncLocalLogs() {
    _localLogData = (_logBox?.values ?? []).toList().cast<FlutoLogModel>();
    _localLogData.sort(
      (a, b) => b.logTime.compareTo(a.logTime),
    );
    notifyListeners();
  }

  Future<void> _insertLog(
    String message, {
    required FlutoLogType type,
    Object? error,
    StackTrace? stackTrace,
    bool printLog = true,
  }) async {
    final logEntry = FlutoLogModel(
      logMessage: message,
      logType: type.name,
      logTime: DateTime.now(),
      errorString: error?.toString() ?? '',
      stackTraceString: stackTrace?.getFormattedError ?? '',
    );
    try {
      await supabase!.client.from('fluto_logs').insert(
        {
          'log_name': message,
          'log_type': type.name,
          'created_at': logEntry.logTime.toIso8601String(),
          'error': logEntry.errorString,
          'stacktrace': logEntry.stackTraceString,
        },
      );
      if (logEntry.logType == selectedLogType.name) {
        _localLogData = [logEntry, ..._localLogData];
        notifyListeners();
      }
    } catch (e) {
      log("Error in insert: $e");
    }
    await _logBox?.add(logEntry);
    if (printLog) {
      log(message, name: type.name, error: error, stackTrace: stackTrace);
    }
  }

  Future<void> insertDebugLog(String message) async {
    await _insertLog(message, type: FlutoLogType.debug);
  }

  Future<void> insertInfoLog(String message) async {
    await _insertLog(message, type: FlutoLogType.info);
  }

  Future<void> insertWarningLog(String message) async {
    await _insertLog(message, type: FlutoLogType.warning);
  }

  Future<void> insertErrorLog(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final formattedStackTrace =
        stackTrace?.toString().split('\n').take(5).join('\n') ?? '';
    final errorMessage = "Error: $error\nStackTrace:\n$formattedStackTrace";
    await _insertLog(
      errorMessage,
      type: FlutoLogType.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> insertPrintLog(String message) async {
    await _insertLog(
      message,
      type: FlutoLogType.print,
      printLog: false,
    );
  }

  Future<void> clearLogs() async {
    final keysToDelete = (_logBox?.keys ?? [])
        .where((key) => _logBox?.get(key)?.logType == selectedLogType.name)
        .toList();
    for (final key in keysToDelete) {
      await _logBox?.delete(key);
    }
    syncLocalLogs();
  }

  List<FlutoLogModel> getAllLogs() {
    return _localLogData
        .where(
          (element) => element.logType == selectedLogType.name,
        )
        .toList();
  }

  Map<Object?, Object?>? get getLogZones => {
        #logDebug: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          insertDebugLog(message);
        },
        #logInfo: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          insertInfoLog(message);
        },
        #logWarning: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          insertWarningLog(message);
        },
        #logError: (
          String message, {
          Object? error,
          StackTrace? stackTrace,
        }) {
          insertErrorLog(
            message,
            error: error,
            stackTrace: stackTrace,
          );
        },
      };
}
