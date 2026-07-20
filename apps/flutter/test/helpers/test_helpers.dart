import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void registerTestFallbacks() {
  registerFallbackValue(RequestOptions(path: ''));
  registerFallbackValue(Options());
  registerFallbackValue(CancelToken());
}

Response<T> buildResponse<T>({
  required String path,
  required T data,
  int statusCode = 200,
}) {
  return Response<T>(
    requestOptions: RequestOptions(path: path),
    data: data,
    statusCode: statusCode,
  );
}
