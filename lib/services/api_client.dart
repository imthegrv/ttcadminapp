import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient({required String Function() tokenProvider})
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      (await _dio.get(path, queryParameters: query)).data;

  Future<dynamic> post(String path, {dynamic data}) async =>
      (await _dio.post(path, data: data)).data;

  Future<dynamic> patch(String path, {dynamic data}) async =>
      (await _dio.patch(path, data: data)).data;

  Future<dynamic> put(String path, {dynamic data}) async =>
      (await _dio.put(path, data: data)).data;

  Future<dynamic> delete(String path, {dynamic data}) async =>
      (await _dio.delete(path, data: data)).data;
}
