import 'dart:async';

import 'package:currency/core/push/push_message_source.dart';

class FakePushMessageSource implements PushMessageSource {
  final taps = StreamController<Map<String, String>>.broadcast();

  /// The notification that "launched" the app, if any.
  Map<String, String>? initial;
  int starts = 0;

  @override
  Future<void> start() async => starts++;

  @override
  Stream<Map<String, String>> get opened => taps.stream;

  @override
  Future<Map<String, String>?> initialMessage() async => initial;
}
