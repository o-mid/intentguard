import 'package:dio/dio.dart';

import '../../features/auth/data/auth_api.dart';
import '../constants.dart';

class ApiClient {
  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? kApiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    authApi = AuthApi(dio);
  }

  late final Dio dio;
  late final AuthApi authApi;
}
