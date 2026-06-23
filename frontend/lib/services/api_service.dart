import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/people/models/person_item.dart';

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
  late final Dio _tokenDio;

  static String? _accessToken;
  static String? _refreshToken;

  static bool forcePasswordChangeCompleted = false;
  bool        _isRefreshing                = false;

  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.loading);

  ApiService._internal()
  {
    final options = BaseOptions(
      baseUrl:        'http://localhost:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    _dio      = Dio(options);
    _tokenDio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler)
        {
          if (_accessToken != null)
          {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async
        {
          final statusCode = error.response?.statusCode;

          if (statusCode != 401 || _refreshToken == null)
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
            final refreshResponse = await _tokenDio.post(
              '/auth/refresh',
              data: {'refresh_token': _refreshToken},
            );

            final loginResponse = LoginResponse.fromJson(refreshResponse.data);

            _accessToken  = loginResponse.accessToken;
            _refreshToken = loginResponse.refreshToken;

            await SessionService.saveTokens(
              accessToken:  loginResponse.accessToken,
              refreshToken: loginResponse.refreshToken,
            );

            final requestOptions = error.requestOptions;
            requestOptions.headers['Authorization'] = 'Bearer $_accessToken';

            final retryResponse = await _dio.fetch(requestOptions);
            return handler.resolve(retryResponse);
          }
          catch (_)
          {
            await _clearSession();
            authState.value = AuthState.unauthenticated;
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

  Future<void> _clearSession() async
  {
    _accessToken                 = null;
    _refreshToken                = null;
    forcePasswordChangeCompleted = false;
    await SessionService.clear();
  }

  Future<bool> restoreSession() async
  {
    _accessToken  = await SessionService.getAccessToken();
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
    catch (_)
    {
      await _clearSession();
      authState.value = AuthState.unauthenticated;
      return false;
    }
  }

  Future<LoginResponse> login({required String username, required String password}) async
  {
    final response = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );

    final loginResponse = LoginResponse.fromJson(response.data);

    _accessToken  = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;

    await SessionService.saveTokens(
      accessToken:  loginResponse.accessToken,
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
        await _tokenDio.post(
          '/auth/logout',
          data: {'refresh_token': _refreshToken},
        );
      }
    }
    catch (_) {}

    await _clearSession();
    authState.value = AuthState.unauthenticated;
  }

  Future<void> changePassword({required String currentPassword, required String newPassword, required String refreshToken}) async
  {
    try
    {
      await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password':     newPassword,
          'refresh_token':    refreshToken,
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante il cambio password');
    }
  }

  Future<void> requestPasswordReset({required String email}) async
  {
    try
    {
      await _dio.post('/auth/request-password-reset', data: {'email': email});
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la richiesta di recupero password');
    }
  }

  Future<void> confirmPasswordReset({required String token, required String newPassword}) async
  {
    try
    {
      await _dio.post(
        '/auth/reset-password',
        data: {'token': token, 'new_password': newPassword},
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la reimpostazione della password.');
    }
  }

  Future<List<AssociationSubjectItem>> getAssociationSubjects() async
  {
    final response = await _dio.get('/association-subjects/');
    return (response.data as List).map((e) => AssociationSubjectItem.fromJson(e)).toList();
  }

  Future<AssociationSubjectItem> createAssociationSubject(String name, String area, String description) async
  {
    try
    {
      final response = await _dio.post(
        '/association-subjects/',
        data: {'name': name, 'area': area, 'description': description},
      );
      return AssociationSubjectItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<AssociationSubjectItem> updateAssociationSubject(int id, String name, String area, String description) async
  {
    try
    {
      final response = await _dio.put(
        '/association-subjects/$id',
        data: {'name': name, 'area': area, 'description': description},
      );
      return AssociationSubjectItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteAssociationSubject(int id) async
  {
    try
    {
      await _dio.delete('/association-subjects/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }

  Future<MeResponse> me() async
  {
    final response = await _dio.get('/auth/me');
    return MeResponse.fromJson(Map<String, dynamic>.from(response.data));
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

  Future<List<SchoolItem>> getSchools() async
  {
    final response = await _dio.get('/schools/');

    return (response.data as List).map((e) => SchoolItem(
      mechanographicCode: e['mechanographic_code'],
      name:               e['name'],
      city:               e['city'],
      province:           e['province'],
      createdAt:          DateTime.parse(e['created_at']),
      studyPrograms:      e['study_programs'] != null
          ? (e['study_programs'] as List).map((p) => SchoolStudyProgramOption(
              id:    p['id'],
              name:  p['name'],
              level: p['level'] ?? '',
            )).toList()
          : [],
    )).toList();
  }

  Future<SchoolItem> createSchool({required bool isPrivate, required String code, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/schools/',
        data: {
          'is_private':          isPrivate,
          'mechanographic_code': code,
          'name':                name,
          'city':                city,
          'province':            province,
          'study_program_ids':   studyProgramIds,
        },
      );

      return SchoolItem(
        mechanographicCode: response.data['mechanographic_code'],
        name:               response.data['name'],
        city:               response.data['city'],
        province:           response.data['province'],
        createdAt:          DateTime.parse(response.data['created_at']),
        studyPrograms:      response.data['study_programs'] != null
            ? (response.data['study_programs'] as List).map((p) => SchoolStudyProgramOption(
                id:    p['id'],
                name:  p['name'],
                level: p['level'] ?? '',
              )).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della scuola.');
    }
  }

  Future<SchoolItem> updateSchool({required String oldCode, required bool isPrivate, required String newCode, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/schools/$oldCode',
        data: {
          'is_private':          isPrivate,
          'mechanographic_code': newCode,
          'name':                name,
          'city':                city,
          'province':            province,
          'study_program_ids':   studyProgramIds,
        },
      );

      return SchoolItem(
        mechanographicCode: response.data['mechanographic_code'],
        name:               response.data['name'],
        city:               response.data['city'],
        province:           response.data['province'],
        createdAt:          DateTime.parse(response.data['created_at']),
        studyPrograms:      response.data['study_programs'] != null
            ? (response.data['study_programs'] as List).map((p) => SchoolStudyProgramOption(
                id:    p['id'],
                name:  p['name'],
                level: p['level'] ?? '',
              )).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della scuola.');
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
      id:               e['id'],
      name:             e['name'],
      description:      e['description'] ?? '',
      level:            e['level'],
      minYear:          e['min_year'],
      maxYear:          e['max_year'],
      createdAt:        DateTime.parse(e['created_at']),
      ministrySubjects: e['ministry_subjects'] != null
          ? (e['ministry_subjects'] as List).map((m) => MinistrySubjectOption(
              id:                  m['id'],
              name:                m['name'],
              associationSubjects: m['association_subjects'] != null
                  ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption(
                      id:   a['id'],
                      name: a['name'],
                    )).toList()
                  : [],
            )).toList()
          : [],
    )).toList();
  }

  Future<StudyProgramItem> createStudyProgram({required String name, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/study-programs/',
        data: {
          'name':                 name,
          'description':          description,
          'level':                level,
          'min_year':             minYear,
          'max_year':             maxYear,
          'ministry_subject_ids': ministrySubjectIds,
        },
      );

      return StudyProgramItem(
        id:               response.data['id'],
        name:             response.data['name'],
        description:      response.data['description'] ?? '',
        level:            response.data['level'],
        minYear:          response.data['min_year'],
        maxYear:          response.data['max_year'],
        createdAt:        DateTime.parse(response.data['created_at']),
        ministrySubjects: response.data['ministry_subjects'] != null
            ? (response.data['ministry_subjects'] as List).map((m) => MinistrySubjectOption(
                id:                  m['id'],
                name:                m['name'],
                associationSubjects: m['association_subjects'] != null
                    ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption(
                        id:   a['id'],
                        name: a['name'],
                      )).toList()
                    : [],
              )).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<StudyProgramItem> updateStudyProgram({required int id, required String name, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/study-programs/$id',
        data: {
          'name':                 name,
          'description':          description,
          'level':                level,
          'min_year':             minYear,
          'max_year':             maxYear,
          'ministry_subject_ids': ministrySubjectIds,
        },
      );

      return StudyProgramItem(
        id:               response.data['id'],
        name:             response.data['name'],
        description:      response.data['description'] ?? '',
        level:            response.data['level'],
        minYear:          response.data['min_year'],
        maxYear:          response.data['max_year'],
        createdAt:        DateTime.parse(response.data['created_at']),
        ministrySubjects: response.data['ministry_subjects'] != null
            ? (response.data['ministry_subjects'] as List).map((m) => MinistrySubjectOption(
                id:                  m['id'],
                name:                m['name'],
                associationSubjects: m['association_subjects'] != null
                    ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption(
                        id:   a['id'],
                        name: a['name'],
                      )).toList()
                    : [],
              )).toList()
            : [],
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

  Future<List<MinistrySubjectItem>> getMinistrySubjects() async
  {
    final response = await _dio.get('/ministry-subjects/');

    return (response.data as List).map((e) => MinistrySubjectItem(
      id:                  e['id'],
      name:                e['name'],
      level:               e['level'],
      area:                e['area'],
      description:         e['description'],
      createdAt:           DateTime.parse(e['created_at']),
      associationSubjects: e['association_subjects'] != null
          ? (e['association_subjects'] as List).map((a) => AssociationSubjectOption(
              id:   a['id'],
              name: a['name'],
            )).toList()
          : [],
    )).toList();
  }

  Future<MinistrySubjectItem> createMinistrySubject({required String name, required String level, required String area, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/ministry-subjects/',
        data: {
          'name':                    name,
          'level':                   level,
          'area':                    area,
          'description':             description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return MinistrySubjectItem(
        id:                  response.data['id'],
        name:                response.data['name'],
        level:               response.data['level'],
        area:                response.data['area'],
        description:         response.data['description'],
        createdAt:           DateTime.parse(response.data['created_at']),
        associationSubjects: response.data['association_subjects'] != null
            ? (response.data['association_subjects'] as List).map((a) => AssociationSubjectOption(id: a['id'], name: a['name'])).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione.');
    }
  }

  Future<MinistrySubjectItem> updateMinistrySubject({required int id, required String name, required String level, required String area, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/ministry-subjects/$id',
        data: {
          'name':                    name,
          'level':                   level,
          'area':                    area,
          'description':             description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return MinistrySubjectItem(
        id:                  response.data['id'],
        name:                response.data['name'],
        level:               response.data['level'],
        area:                response.data['area'],
        description:         response.data['description'],
        createdAt:           DateTime.parse(response.data['created_at']),
        associationSubjects: response.data['association_subjects'] != null
            ? (response.data['association_subjects'] as List).map((a) => AssociationSubjectOption(id: a['id'], name: a['name'])).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteMinistrySubject(int id) async
  {
    try
    {
      await _dio.delete('/ministry-subjects/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }

  Future<List<PersonItem>> getPeople() async
  {
    final response = await _dio.get('/people/');
    return (response.data as List).map((json) => PersonItem.fromJson(json)).toList();
  }

  Future<void> createPersonFromWizard(Map<String, dynamic> payload, {Uint8List? imageBytes}) async
  {
    try
    {
      final response = await _dio.post(
        '/people/wizard/',
        data: payload,
      );

      if (imageBytes != null)
      {
        final taxCode  = response.data['tax_code'];
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(imageBytes, filename: '${taxCode}_profile.jpg'),
        });

        await _dio.post('/people/$taxCode/image', data: formData);
      }
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante la creazione della persona.');
    }
  }
}