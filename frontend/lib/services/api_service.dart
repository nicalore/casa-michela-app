import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import 'auth_state.dart';
import 'session_service.dart';

class ApiService
{
  static final ApiService _instance = ApiService._internal();

  factory ApiService()
  {
    return _instance;
  }

  late final Dio _dio;

  static String? _accessToken;
  static String? _refreshToken;

  static bool forcePasswordChangeCompleted = false;
  bool _isRefreshing = false;

  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.loading);

  ApiService._internal()
  {
    //InitializeDio
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:8000',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler)
        {
          //RequestInterceptor
          if (_accessToken != null)
          {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }

          return handler.next(options);
        },
        onError: (error, handler) async
        {
          //ErrorInterceptor
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isRefreshRequest = path == '/auth/refresh';

          if (statusCode != 401 || isRefreshRequest || _refreshToken == null)
          {
            return handler.next(error);
          }

          if (_isRefreshing)
          {
            return handler.next(error);
          }

          _isRefreshing = true;

          try
          {
            //TokenRefreshLogic
            await refreshSession();

            final requestOptions = error.requestOptions;
            
            requestOptions.headers['Authorization'] = 'Bearer $_accessToken';

            final response = await _dio.fetch(requestOptions);

            return handler.resolve(response);
          }
          catch (_)
          {
            await logout();
            
            return handler.next(error);
          }
          finally
          {
            _isRefreshing = false;
          }
        },
      ),
    );
  }

  bool get isAuthenticated
  {
    return _accessToken != null && _refreshToken != null;
  }

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async
  {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );

    final loginResponse = LoginResponse.fromJson(response.data);

    _accessToken = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;

    await SessionService.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    authState.value = AuthState.authenticated;

    return loginResponse;
  }

  Future<void> logout() async
  {
    try
    {
      if (_refreshToken != null)
      {
        await _dio.post(
          '/auth/logout',
          data: {
            'refresh_token': _refreshToken,
          },
        );
      }
    }
    catch (_)
    {
      //IgnoredError
    }

    _accessToken = null;
    _refreshToken = null;

    forcePasswordChangeCompleted = false;

    authState.value = AuthState.unauthenticated;

    await SessionService.clear();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String refreshToken,
  }) async
  {
    try
    {
      await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'refresh_token': refreshToken,
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(
        e.response?.data['detail'] ?? 'Errore durante il cambio password',
      );
    }
  }

  Future<MeResponse> me() async
  {
    final response = await _dio.get('/auth/me');

    return MeResponse.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  Future<void> refreshSession() async
  {
    if (_refreshToken == null)
    {
      throw Exception('Refresh token mancante');
    }

    debugPrint('REFRESH TOKEN REQUEST');

    final response = await _dio.post(
      '/auth/refresh',
      data: {
        'refresh_token': _refreshToken,
      },
    );

    final loginResponse = LoginResponse.fromJson(response.data);

    _accessToken = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;

    await SessionService.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    debugPrint('REFRESH SUCCESS');
  }

  Future<bool> restoreSession() async
  {
    //RestoreSessionLogic
    _accessToken = await SessionService.getAccessToken();
    _refreshToken = await SessionService.getRefreshToken();

    if (_accessToken == null || _refreshToken == null)
    {
      authState.value = AuthState.unauthenticated;
      
      return false;
    }

    try
    {
      await me();

      authState.value = AuthState.authenticated;

      return true;
    }
    on DioException
    {
      try
      {
        await refreshSession();

        await me();

        authState.value = AuthState.authenticated;

        return true;
      }
      catch (_)
      {
        await logout();

        authState.value = AuthState.unauthenticated;

        return false;
      }
    }
  }
}