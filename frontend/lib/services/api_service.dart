import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/people/models/person_item.dart';
import '../features/people/models/member_trend_item.dart';
import '../features/people/models/retention_rate_item.dart';
import '../features/people/models/current_totals_item.dart';
import '../features/people/models/city_distribution_item.dart';
import '../features/people/models/age_distribution_item.dart';
import '../features/people/models/education_distribution_item.dart';
import '../features/people/models/teacher_subjects_statistics_item.dart';
import '../features/people/models/course_distribution_item.dart';

import '../core/config/api_config.dart';
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
      baseUrl:        ApiConfig.baseUrl,
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la reimpostazione della password. Riprova più tardi.');
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

  Future<PersonItem> getPerson(String fiscalCode) async 
  {
    final response = await _dio.get('/people/$fiscalCode');
    return PersonItem.fromJson(response.data);
  }

  Future<String> updatePerson(String fiscalCode, Map<String, dynamic> payload, {Uint8List? imageBytes}) async 
  {
    try 
    {
      final response   = await _dio.put('/people/$fiscalCode', data: payload);
      final newTaxCode = response.data['new_tax_code'] ?? fiscalCode;
      
      if (imageBytes != null) 
      {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(imageBytes, filename: '${newTaxCode}_profile.jpg'),
        });
        await _dio.post('/people/$newTaxCode/image', data: formData);
      }
      
      return newTaxCode;
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento: ');
    }
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

  Future<void> sendAnagraphicErrorReport(String fiscalCode, Map<String, String> corrections) async 
  {
    try 
    {
      await _dio.post(
        '/people/$fiscalCode/report-error',
        data: corrections,
      );
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile inviare la segnalazione errore al server.');
    }
  }

  Future<void> updatePersonMemberships(String fiscalCode, bool collaboratingActive, List<Map<String, dynamic>> memberships) async 
  {
    try 
    {
      await _dio.put(
        '/people/$fiscalCode/memberships',
        data: {
          'collaborating_active': collaboratingActive,
          'memberships': memberships,
        },
      );
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento delle iscrizioni.');
    }
  }

  Future<void> revokePersonMembership(String fiscalCode, String revocationType) async 
  {
    try 
    {
      await _dio.put(
        '/people/$fiscalCode/revoke-membership',
        data: {
          'revocation_type': revocationType,
        },
      );
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante la revoca dell\'iscrizione.');
    }
  }

  Future<void> updatePersonSchoolEnrollments(String fiscalCode, List<Map<String, dynamic>> enrollments) async 
  {
    try 
    {
      await _dio.put(
        '/people/$fiscalCode/school-enrollments',
        data: {
          'enrollments': enrollments,
        },
      );
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento degli anni scolastici.');
    }
  }

  Future<void> addParent(String childTaxCode, String parentTaxCode) async 
  {
    try 
    {
      await _dio.post('/people/$childTaxCode/parents', data: {'parent_tax_code': parentTaxCode});
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto.');
    }
  }

  Future<void> updateParent(String childTaxCode, String oldParentTaxCode, String newParentTaxCode) async 
  {
    try 
    {
      await _dio.put('/people/$childTaxCode/parents/$oldParentTaxCode', data: {'parent_tax_code': newParentTaxCode});
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto.');
    }
  }

  Future<void> removeParent(String childTaxCode, String parentTaxCode) async 
  {
    try 
    {
      await _dio.delete('/people/$childTaxCode/parents/$parentTaxCode');
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto.');
    }
  }

  Future<CurrentTotalsItem> getCurrentTotals() async
  {
    try 
    {
      final response = await _dio.get('/statistics/general/current-totals');
      return CurrentTotalsItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare i totali attuali.');
    }
  }

  Future<List<MemberTrendItem>> getMembersTrend({required String resolution, int? startYear, int? endYear}) async
  {
    try 
    {
      final response = await _dio.get(
        '/statistics/general/members-trend',
        queryParameters: {
          'resolution': resolution,
          if (startYear != null) 'start_year': startYear,
          if (endYear != null) 'end_year': endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend degli iscritti.');
    }
  }

  Future<List<MemberTrendItem>> getCollaboratingTrend({required String resolution, int? startYear, int? endYear}) async
  {
    try 
    {
      final response = await _dio.get(
        '/statistics/general/collaborating-trend',
        queryParameters: {
          'resolution': resolution,
          if (startYear != null) 'start_year': startYear,
          if (endYear != null) 'end_year': endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend dei collaboratori.');
    }
  }

  Future<RetentionRateItem> getRetentionRate(int year) async
  {
    try 
    {
      final response = await _dio.get('/statistics/general/retention-rate', queryParameters: {'year': year});
      return RetentionRateItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il tasso di retention.');
    }
  }

  Future<RetentionRateItem> getCollaboratingRetentionRate(int year, int month) async
  {
    try 
    {
      final response = await _dio.get('/statistics/general/collaborating-retention', queryParameters: {'year': year, 'month': month});
      return RetentionRateItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il tasso di retention collaboratori.');
    }
  }

  Future<CurrentTotalsItem> getRoleCurrentTotals(String role) async
  {
    try 
    {
      final response = await _dio.get('/statistics/role/current-totals', queryParameters: {'role': role});
      return CurrentTotalsItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare i totali del ruolo.');
    }
  }

  Future<List<MemberTrendItem>> getRoleMembersTrend({required String role, required String resolution, int? startYear, int? endYear}) async
  {
    try 
    {
      final response = await _dio.get(
        '/statistics/role/members-trend',
        queryParameters: {
          'role': role,
          'resolution': resolution,
          if (startYear != null) 'start_year': startYear,
          if (endYear != null) 'end_year': endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend del ruolo.');
    }
  }

  Future<List<MemberTrendItem>> getRoleCollaboratingTrend({required String role, required String resolution, int? startYear, int? endYear}) async
  {
    try 
    {
      final response = await _dio.get(
        '/statistics/role/collaborating-trend',
        queryParameters: {
          'role': role,
          'resolution': resolution,
          if (startYear != null) 'start_year': startYear,
          if (endYear != null) 'end_year': endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend collaboratori del ruolo.');
    }
  }

  Future<RetentionRateItem> getRoleRetentionRate(String role, int year) async
  {
    try 
    {
      final response = await _dio.get('/statistics/role/retention-rate', queryParameters: {'role': role, 'year': year});
      return RetentionRateItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la retention del ruolo.');
    }
  }

  Future<RetentionRateItem> getRoleCollaboratingRetentionRate(String role, int year, int month) async
  {
    try 
    {
      final response = await _dio.get('/statistics/role/collaborating-retention', queryParameters: {'role': role, 'year': year, 'month': month});
      return RetentionRateItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la retention collaboratori del ruolo.');
    }
  }

  Future<List<CityDistributionItem>> getRoleCityDistribution(String role) async
  {
    try 
    {
      final response = await _dio.get('/statistics/role/city-distribution', queryParameters: {'role': role});
      return (response.data as List<dynamic>).map((e) => CityDistributionItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione per città.');
    }
  }

  Future<List<AgeDistributionItem>> getRoleAgeDistribution(String role) async
  {
    try 
    {
      final response = await _dio.get('/statistics/role/age-distribution', queryParameters: {'role': role});
      return (response.data as List<dynamic>).map((e) => AgeDistributionItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione per età.');
    }
  }

  Future<void> updateTeacherCompetences(String taxCode, List<Map<String, dynamic>> competences) async 
  {
    try 
    {
      await _dio.put(
        '/people/$taxCode/teacher-competences', 
        data: {'competences': competences},
      );
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto.');
    }
  }

  Future<List<EducationDistributionItem>> getStudentEducationDistribution(String type) async
  {
    try 
    {
      final response = await _dio.get('/statistics/students/education-distribution', queryParameters: {'distribution_type': type});
      return (response.data as List<dynamic>).map((e) => EducationDistributionItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione scolastica.');
    }
  }

  Future<TeacherSubjectsStatisticsItem> getTeacherSubjectsStatistics(String rankingMode) async
  {
    try 
    {
      final response = await _dio.get('/statistics/teachers/subjects-statistics', queryParameters: {'ranking_mode': rankingMode});
      return TeacherSubjectsStatisticsItem.fromJson(response.data);
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare le statistiche materie docenti.');
    }
  }

  Future<List<CourseDistributionItem>> getCourseParticipantDistribution() async
  {
    try 
    {
      final response = await _dio.get('/statistics/course-participants/course-distribution');
      return (response.data as List<dynamic>).map((e) => CourseDistributionItem.fromJson(e)).toList();
    } 
    on DioException catch (e) 
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione corsi.');
    }
  }
}