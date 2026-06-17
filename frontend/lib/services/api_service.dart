import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/association/models/subject_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/teaching_offering_item.dart';

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

  Future<List<SubjectItem>> getSubjects() async
  {
    final response = await _dio.get('/subjects/');
    return (response.data as List).map((e) => SubjectItem(
      discipline: e['discipline'],
      areas: List<String>.from(e['areas']),
    )).toList();
  }

  Future<void> createSubject(String discipline, List<String> areas) async
  {
    try
    {
      await _dio.post(
        '/subjects/',
        data: {'discipline': discipline, 'areas': areas},
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<void> updateSubject(String oldDiscipline, String newDiscipline, List<String> areas) async
  {
    try
    {
      await _dio.put(
        '/subjects/$oldDiscipline',
        data: {'discipline': newDiscipline, 'areas': areas},
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteSubject(String discipline) async
  {
    try
    {
      await _dio.delete('/subjects/$discipline');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }

  Future<MeResponse> me() async
  {
    final response = await _dio.get('/auth/me');

    return MeResponse.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  Future<String> uploadProfileImage(List<int> bytes, String fileName) async
  {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    try
    {
      final response = await _dio.post('/auth/profile-image', data: formData);
      return response.data['profile_image_url'];
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'upload dell\'immagine');
    }
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

  Future<List<SchoolItem>> getSchools() async
  {
    final response = await _dio.get('/schools/');
    return (response.data as List).map((e) => SchoolItem(
      mechanographicCode: e['mechanographic_code'],
      name: e['name'],
      city: e['city'],
      province: e['province'],
    )).toList();
  }

  Future<SchoolItem> createSchool({
    required String code,
    required String name,
    required String city,
    required String province,
    required bool isPrivate,
  }) async
  {
    try
    {
      final response = await _dio.post('/schools/', data: {
        'mechanographic_code': code,
        'name': name,
        'city': city,
        'province': province,
        'is_private': isPrivate,
      });
      return SchoolItem(
        mechanographicCode: response.data['mechanographic_code'],
        name: response.data['name'],
        city: response.data['city'],
        province: response.data['province'],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<SchoolItem> updateSchool({
    required String oldCode,
    required String newCode,
    required String name,
    required String city,
    required String province,
    required bool isPrivate,
  }) async
  {
    try
    {
      final response = await _dio.put('/schools/$oldCode', data: {
        'mechanographic_code': newCode,
        'name': name,
        'city': city,
        'province': province,
        'is_private': isPrivate,
      });
      return SchoolItem(
        mechanographicCode: response.data['mechanographic_code'],
        name: response.data['name'],
        city: response.data['city'],
        province: response.data['province'],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteSchool(String code) async
  {
    try
    {
      await _dio.delete('/schools/$code');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della scuola.');
    }
  }

  Future<List<StudyProgramItem>> getStudyPrograms() async
  {
    final response = await _dio.get('/study-programs/');
    return (response.data as List).map((e) => StudyProgramItem(
      id: e['id'],
      name: e['name'],
      description: e['description'] ?? '',
    )).toList();
  }

  Future<StudyProgramItem> createStudyProgram({
    required String name,
    required String description,
  }) async
  {
    try
    {
      final response = await _dio.post('/study-programs/', data: {
        'name': name,
        'description': description,
      });
      return StudyProgramItem(
        id: response.data['id'],
        name: response.data['name'],
        description: response.data['description'] ?? '',
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<StudyProgramItem> updateStudyProgram({
    required int id,
    required String name,
    required String description,
  }) async
  {
    try
    {
      final response = await _dio.put('/study-programs/$id', data: {
        'name': name,
        'description': description,
      });
      return StudyProgramItem(
        id: response.data['id'],
        name: response.data['name'],
        description: response.data['description'] ?? '',
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteStudyProgram(int id) async
  {
    try
    {
      await _dio.delete('/study-programs/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }

  Future<OfferingOptions> getOfferingOptions() async
  {
    final response = await _dio.get('/teaching-offerings/options');
    return OfferingOptions(
      schools: (response.data['schools'] as List).map((e) => SchoolOption(mechanographicCode: e['mechanographic_code'], name: e['name'])).toList(),
      studyPrograms: (response.data['study_programs'] as List).map((e) => StudyProgramOption(id: e['id'], name: e['name'])).toList(),
      subjects: (response.data['subjects'] as List).map((e) => SubjectOption(id: e['id'], discipline: e['discipline'], specialization: e['specialization'])).toList(),
    );
  }

  Future<List<TeachingOfferingItem>> getTeachingOfferings() async
  {
    final response = await _dio.get('/teaching-offerings/');
    return (response.data as List).map((e) => TeachingOfferingItem(
      id: e['id'],
      schoolCode: e['school_mechanographic_code'],
      schoolName: e['school_name'],
      studyProgramId: e['study_program_id'],
      studyProgramName: e['study_program_name'],
      level: e['level'],
      years: List<int>.from(e['years']),
      subjectIds: List<int>.from(e['subject_ids']),
      subjects: (e['subjects'] as List).map((s) => SubjectOption(id: s['id'], discipline: s['discipline'], specialization: s['specialization'])).toList(),
    )).toList();
  }

  Future<TeachingOfferingItem> createTeachingOffering({
    required String schoolCode,
    required int studyProgramId,
    required String level,
    required List<int> years,
    required List<int> subjectIds,
  }) async
  {
    try
    {
      final response = await _dio.post('/teaching-offerings/', data: {
        'school_mechanographic_code': schoolCode,
        'study_program_id': studyProgramId,
        'level': level,
        'years': years,
        'subject_ids': subjectIds,
      });
      return TeachingOfferingItem(
        id: response.data['id'], schoolCode: response.data['school_mechanographic_code'], schoolName: response.data['school_name'], studyProgramId: response.data['study_program_id'], studyProgramName: response.data['study_program_name'], level: response.data['level'], years: List<int>.from(response.data['years']), subjectIds: List<int>.from(response.data['subject_ids']), subjects: (response.data['subjects'] as List).map((s) => SubjectOption(id: s['id'], discipline: s['discipline'], specialization: s['specialization'])).toList(),
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<void> deleteTeachingOffering(int id) async
  {
    try
    {
      await _dio.delete('/teaching-offerings/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }
  
  Future<TeachingOfferingItem> updateTeachingOffering({
    required int id,
    required String schoolCode,
    required int studyProgramId,
    required String level,
    required List<int> years,
    required List<int> subjectIds,
  }) async
  {
    try
    {
      final response = await _dio.put('/teaching-offerings/$id', data: {
        'school_mechanographic_code': schoolCode,
        'study_program_id': studyProgramId,
        'level': level,
        'years': years,
        'subject_ids': subjectIds,
      });
      return TeachingOfferingItem(
        id: response.data['id'],
        schoolCode: response.data['school_mechanographic_code'],
        schoolName: response.data['school_name'],
        studyProgramId: response.data['study_program_id'],
        studyProgramName: response.data['study_program_name'],
        level: response.data['level'],
        years: List<int>.from(response.data['years']),
        subjectIds: List<int>.from(response.data['subject_ids']),
        subjects: (response.data['subjects'] as List).map((s) => SubjectOption(id: s['id'], discipline: s['discipline'], specialization: s['specialization'])).toList(),
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }
}