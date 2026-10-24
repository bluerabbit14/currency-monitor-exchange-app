import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

class FeedbackRemoteDataSource {
  const FeedbackRemoteDataSource(this._client);

  /// The authenticated client.
  final ApiClient _client;

  static const _path = '/api/v1/feedback';

  /// At least one of [rating] / [message] must be given.
  Future<void> submit({int? rating, String? message}) async {
    await _client.post(
      _path,
      data: {
        'rating': ?rating,
        'message': ?message,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'IOS'
            : 'ANDROID',
      },
    );
  }
}
