import 'package:dio/dio.dart';
import 'package:zuno/core/constants/api_constants.dart';

/// Knocks once on each server as the app opens.
///
/// A server that slept while nobody used it takes 20–50 s to wake on its first request. Sent now,
/// that wait passes while the user is still on the first screen, instead of when they tap
/// Marketplace or Rent. Any reply wakes a server — even a refusal — so the answer is ignored, and
/// a failure never reaches the user.
Future<void> warmUpServers(Iterable<String> baseUrls, {Dio? client}) async {
  final dio =
      client ??
      Dio(
        BaseOptions(
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          // Every status is a reply: nothing to throw about.
          validateStatus: (_) => true,
        ),
      );
  await Future.wait([
    for (final url in {...baseUrls})
      dio
          .get<void>('$url${ApiConstants.healthPath}')
          .then<void>((_) {}, onError: (Object _) {}),
  ]);
}
