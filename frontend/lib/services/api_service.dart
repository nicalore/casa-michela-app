import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/opening_day_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/service_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/association/models/weekly_template_item.dart';
import '../features/lessons/models/availability_item.dart';
import '../features/lessons/models/presence_item.dart';
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
import '../core/utils/json_parsing.dart';
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

  bool _isRefreshing = false;

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
          await _performTokenRefresh();

          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
          
          if (requestOptions.data is Map &&
              (requestOptions.data as Map).containsKey('refresh_token'))
          {
            (requestOptions.data as Map)['refresh_token'] = _refreshToken;
          }

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
    _accessToken  = null;
    _refreshToken = null;
    lastKnownIdentity = null;
    await SessionService.clear();
  }

  // Refreshes the token and updates authState from the current account state
  // (including the mandatory password reset). Used both by the 401 interceptor
  // and by restoreSession(), so the password_reset_required check always runs
  // at the exact same point regardless of how a valid token was obtained.
  Future<LoginResponse> _performTokenRefresh() async
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

    authState.value = loginResponse.passwordResetRequired
        ? AuthState.passwordChangeRequired
        : AuthState.authenticated;

    return loginResponse;
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
      await _performTokenRefresh();
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

    authState.value = loginResponse.passwordResetRequired
        ? AuthState.passwordChangeRequired
        : AuthState.authenticated;

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

  Future<void> changePassword({required String currentPassword, required String newPassword}) async
  {
    try
    {
      await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password':     newPassword,
          'refresh_token':    _refreshToken,
        },
      );

      // The password was changed successfully: the account no longer has a
      // pending reset, so the global router redirect sends the user back to the
      // dashboard automatically.
      authState.value = AuthState.authenticated;
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante il cambio password. Riprova più tardi.');
    }
  }

  Future<void> requestPasswordReset({required String username}) async
  {
    try
    {
      await _dio.post('/auth/request-password-reset', data: {'username': username});
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la richiesta di recupero password. Riprova più tardi.');
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

  Future<void> validateResetToken({required String token}) async
  {
    try
    {
      await _dio.get(
        '/auth/validate-reset-token',
        queryParameters: {'token': token},
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Token non valido o scaduto.');
    }
  }

  Future<List<AssociationSubjectItem>> getAssociationSubjects() async
  {
    final response = await _dio.get('/association-subjects/');
    return (response.data as List).map((e) => AssociationSubjectItem.fromJson(e)).toList();
  }

  Future<List<OpeningDayItem>> getOpeningDays({required DateTime dateFrom, required DateTime dateTo, required String mode}) async
  {
    final response = await _dio.get(
      '/opening-days/',
      queryParameters: {
        'date_from': formatDateOnly(dateFrom),
        'date_to': formatDateOnly(dateTo),
        'mode': mode,
      },
    );
    return (response.data as List).map((e) => OpeningDayItem.fromJson(e)).toList();
  }

  Future<List<WeeklyTemplateItem>> getWeeklyTemplates() async
  {
    final response = await _dio.get('/weekly-templates/');
    return (response.data as List).map((e) => WeeklyTemplateItem.fromJson(e)).toList();
  }

  // effectiveFrom is the date the change starts applying to the already
  // generated calendar. Omitting it leaves opening_days untouched, so the new
  // hours only show up the next time the calendar is generated.
  Future<WeeklyTemplateItem> createWeeklyTemplate({
    required int weekday,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? effectiveFrom,
  }) async
  {
    try
    {
      final response = await _dio.post('/weekly-templates/', data: {
        'weekday': weekday,
        'mode': mode,
        'start_time': formatTimeOfDay(startTime),
        'end_time': formatTimeOfDay(endTime),
        'effective_from': effectiveFrom != null ? formatDateOnly(effectiveFrom) : null,
      });
      return WeeklyTemplateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della fascia oraria. Riprova più tardi.');
    }
  }

  Future<WeeklyTemplateItem> updateWeeklyTemplate({
    required int id,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? effectiveFrom,
  }) async
  {
    try
    {
      final response = await _dio.put('/weekly-templates/$id', data: {
        'start_time': formatTimeOfDay(startTime),
        'end_time': formatTimeOfDay(endTime),
        'effective_from': effectiveFrom != null ? formatDateOnly(effectiveFrom) : null,
      });
      return WeeklyTemplateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della fascia oraria. Riprova più tardi.');
    }
  }

  Future<void> deleteWeeklyTemplate(int id, {DateTime? effectiveFrom}) async
  {
    try
    {
      await _dio.delete(
        '/weekly-templates/$id',
        queryParameters: effectiveFrom != null ? {'effective_from': formatDateOnly(effectiveFrom)} : null,
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della fascia oraria. Riprova più tardi.');
    }
  }

  Future<OpeningDayItem> createOpeningDay({
    required DateTime date,
    required String mode,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? note,
  }) async
  {
    try
    {
      final response = await _dio.post('/opening-days/', data: {
        'date': formatDateOnly(date),
        'mode': mode,
        'start_time': startTime != null ? formatTimeOfDay(startTime) : null,
        'end_time': endTime != null ? formatTimeOfDay(endTime) : null,
        'note': note,
      });
      return OpeningDayItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione dell\'apertura. Riprova più tardi.');
    }
  }

  Future<OpeningDayItem> updateOpeningDay({
    required int id,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? note,
  }) async
  {
    try
    {
      final response = await _dio.put('/opening-days/$id', data: {
        'start_time': startTime != null ? formatTimeOfDay(startTime) : null,
        'end_time': endTime != null ? formatTimeOfDay(endTime) : null,
        'note': note,
      });
      return OpeningDayItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'aggiornamento dell\'apertura. Riprova più tardi.');
    }
  }

  Future<void> deleteOpeningDay(int id) async
  {
    try
    {
      await _dio.delete('/opening-days/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione dell\'apertura. Riprova più tardi.');
    }
  }

  // Undoes a variation: the days in the range go back to the weekly template's
  // hours. Server-side because rows written through the API are always flagged
  // as overrides, so the client cannot put a standard day back on its own — and
  // plain deletion would leave those days with no hours at all.
  Future<void> restoreStandardHours({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String mode,
  }) async
  {
    try
    {
      await _dio.post('/opening-days/restore-standard', data: {
        'date_from': formatDateOnly(dateFrom),
        'date_to': formatDateOnly(dateTo),
        'mode': mode,
      });
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante il ripristino dell\'orario standard. Riprova più tardi.');
    }
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione. Riprova più tardi.');
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

  // A whole day booked in one go: the bands and the lessons of one or both
  // modes, in a single transaction. It either passes as a whole or not at all,
  // where writing one presence and one lesson per call left a half-written day
  // behind on a refusal partway through.
  Future<List<PresenceItem>> createLessonRequest({
    required String studentTaxCode,
    required DateTime date,
    required List<Map<String, dynamic>> modes,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/lesson-requests/',
        data: {
          'student_tax_code': studentTaxCode,
          'date': formatDateOnly(date),
          'modes': modes,
        },
      );

      return (response.data as List).map((e) => PresenceItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della richiesta.');
    }
  }

  // Il nome è la chiave di un servizio, e i nomi hanno spazi e accenti: vanno
  // codificati, altrimenti "Metodo di studio" arriva spezzato nel path.
  String _servicePath(String name) => '/services/${Uri.encodeComponent(name)}';

  Future<List<ServiceItem>> getServices() async
  {
    final response = await _dio.get('/services/');
    return (response.data as List).map((e) => ServiceItem.fromJson(e)).toList();
  }

  Future<ServiceItem> createService(String name, String description) async
  {
    try
    {
      final response = await _dio.post(
        '/services/',
        data: {'name': name, 'description': description},
      );
      return ServiceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione. Riprova più tardi.');
    }
  }

  // originalName is which row to rewrite, name is what it will be called
  // afterwards: the two are the same thing only until a rename.
  Future<ServiceItem> updateService(String originalName, String name, String description) async
  {
    try
    {
      final response = await _dio.put(
        _servicePath(originalName),
        data: {'name': name, 'description': description},
      );
      return ServiceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica.');
    }
  }

  Future<void> deleteService(String name) async
  {
    try
    {
      await _dio.delete(_servicePath(name));
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione.');
    }
  }

  // The identity the last answer to me() carried, kept so that a page opening
  // has something to draw its top bar with while its own request is in flight.
  // It is a memory of what was true a moment ago and nothing more: whoever uses
  // it asks the server as well and replaces it with the answer. Dropped with the
  // session, so it cannot outlive the account it belongs to.
  MeResponse? lastKnownIdentity;

  Future<MeResponse> me() async
  {
    final response = await _dio.get('/auth/me');
    final identity = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

    lastKnownIdentity = identity;

    return identity;
  }

  // How many times the profile picture has changed hands in this session. The
  // picture keeps the same address when it is replaced, so whoever draws it
  // stamps this on the URL to tell the browser cache that the bytes behind that
  // address are not the ones it is holding.
  int profileImageVersion = 0;

  Future<String> uploadProfileImage(List<int> bytes, String fileName) async
  {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    try
    {
      final response = await _dio.post('/auth/profile-image', data: formData);

      profileImageVersion++;

      return response.data['profile_image_url'];
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante il caricamento dell\'immagine.');
    }
  }

  // Mirror of uploadProfileImage: same endpoint family and error pattern.
  Future<void> deleteProfileImage() async
  {
    try
    {
      await _dio.delete('/auth/profile-image');

      profileImageVersion++;
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la rimozione dell\'immagine.');
    }
  }

  Future<List<SchoolItem>> getSchools() async
  {
    final response = await _dio.get('/schools/');

    return (response.data as List).map((e) => SchoolItem(
      id:                 e['id'],
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

  Future<SchoolItem> createSchool({String? code, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/schools/',
        data: {
          // Null when absent: the backend normalizes an empty string to null anyway.
          'mechanographic_code': (code == null || code.isEmpty) ? null : code,
          'name':                name,
          'city':                city,
          'province':            province,
          'study_program_ids':   studyProgramIds,
        },
      );

      return SchoolItem(
        id:                 response.data['id'],
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della scuola. Riprova più tardi.');
    }
  }

  Future<SchoolItem> updateSchool({required int id, String? code, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/schools/$id',
        data: {
          // Null when absent: the backend normalizes an empty string to null anyway.
          'mechanographic_code': (code == null || code.isEmpty) ? null : code,
          'name':                name,
          'city':                city,
          'province':            province,
          'study_program_ids':   studyProgramIds,
        },
      );

      return SchoolItem(
        id:                 response.data['id'],
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della scuola. Riprova più tardi.');
    }
  }

  Future<void> deleteSchool(int id) async
  {
    try
    {
      await _dio.delete('/schools/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della scuola. Riprova più tardi.');
    }
  }

  Future<List<StudyProgramItem>> getStudyPrograms() async
  {
    final response = await _dio.get('/study-programs/');

    return (response.data as List).map((e) => StudyProgramItem(
      id:               e['id'],
      name:             e['name'],
      sector:           e['sector'],
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
                  ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
                  : [],
            )).toList()
          : [],
    )).toList();
  }

  Future<StudyProgramItem> createStudyProgram({required String name, required String? sector, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/study-programs/',
        data: {
          'name':                 name,
          'sector':               sector,
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
        sector:           response.data['sector'],
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
                    ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
                    : [],
              )).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione del percorso. Riprova più tardi.');
    }
  }

  Future<StudyProgramItem> updateStudyProgram({required int id, required String name, required String? sector, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/study-programs/$id',
        data: {
          'name':                 name,
          'sector':               sector,
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
        sector:           response.data['sector'],
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
                    ? (m['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
                    : [],
              )).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica del percorso. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione del percorso. Riprova più tardi.');
    }
  }

  Future<List<MinistrySubjectItem>> getMinistrySubjects() async
  {
    final response = await _dio.get('/ministry-subjects/');

    return (response.data as List).map((e) => MinistrySubjectItem(
      id:                  e['id'],
      name:                e['name'],
      level:               e['level'],
      areas:               (e['area'] as List).cast<String>(),
      description:         e['description'],
      createdAt:           DateTime.parse(e['created_at']),
      associationSubjects: e['association_subjects'] != null
          ? (e['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
          : [],
    )).toList();
  }

  Future<MinistrySubjectItem> createMinistrySubject({required String name, required String level, required List<String> areas, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/ministry-subjects/',
        data: {
          'name':                    name,
          'level':                   level,
          'area':                    areas,
          'description':             description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return MinistrySubjectItem(
        id:                  response.data['id'],
        name:                response.data['name'],
        level:               response.data['level'],
        areas:               (response.data['area'] as List).cast<String>(),
        description:         response.data['description'],
        createdAt:           DateTime.parse(response.data['created_at']),
        associationSubjects: response.data['association_subjects'] != null
            ? (response.data['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della materia. Riprova più tardi.');
    }
  }

  Future<MinistrySubjectItem> updateMinistrySubject({required int id, required String name, required String level, required List<String> areas, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/ministry-subjects/$id',
        data: {
          'name':                    name,
          'level':                   level,
          'area':                    areas,
          'description':             description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return MinistrySubjectItem(
        id:                  response.data['id'],
        name:                response.data['name'],
        level:               response.data['level'],
        areas:               (response.data['area'] as List).cast<String>(),
        description:         response.data['description'],
        createdAt:           DateTime.parse(response.data['created_at']),
        associationSubjects: response.data['association_subjects'] != null
            ? (response.data['association_subjects'] as List).map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>)).toList()
            : [],
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della materia. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della materia. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante la creazione della persona. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile inviare la segnalazione. Riprova più tardi.');
    }
  }

  Future<void> updatePersonMemberships(
    String fiscalCode,
    bool collaboratingActive,
    List<Map<String, dynamic>> memberships,
    DateTime? expectedUpdatedAt,
  ) async
  {
    try
    {
      await _dio.put(
        '/people/$fiscalCode/memberships',
        data: {
          'collaborating_active': collaboratingActive,
          'memberships': memberships,
          if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento delle iscrizioni. Riprova più tardi.');
    }
  }

  Future<void> revokePersonMembership(String fiscalCode, String revocationType, DateTime? expectedUpdatedAt) async
  {
    try
    {
      await _dio.put(
        '/people/$fiscalCode/revoke-membership',
        data: {
          'revocation_type': revocationType,
          if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante la revoca dell\'iscrizione. Riprova più tardi.');
    }
  }

  Future<void> updatePersonSchoolEnrollments(
  String fiscalCode,
  List<Map<String, dynamic>> enrollments,
  DateTime? expectedUpdatedAt,
) async
{
  try
  {
    await _dio.put(
      '/people/$fiscalCode/school-enrollments',
      data: {
        'enrollments': enrollments,
        if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
      },
    );
  }
  on DioException catch (e)
  {
    throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto durante l\'aggiornamento degli anni scolastici. Riprova più tardi.');
  }
}

  Future<void> addParent(
    String childTaxCode,
    String parentTaxCode, {
    bool authorizedPickup = true,
    String? pickupRestrictionReason,
  }) async
  {
    try
    {
      await _dio.post(
        '/people/$childTaxCode/parents',
        data: {
          'parent_tax_code': parentTaxCode,
          'authorized_pickup': authorizedPickup,
          'pickup_restriction_reason': authorizedPickup ? null : pickupRestrictionReason,
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto. Riprova più tardi.');
    }
  }

  Future<void> updateParent(
    String childTaxCode,
    String oldParentTaxCode,
    String newParentTaxCode, {
    bool authorizedPickup = true,
    String? pickupRestrictionReason,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$childTaxCode/parents/$oldParentTaxCode',
        data: {
          'parent_tax_code': newParentTaxCode,
          'authorized_pickup': authorizedPickup,
          'pickup_restriction_reason': authorizedPickup ? null : pickupRestrictionReason,
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare i totali attuali. Riprova più tardi.');
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
          'start_year': ?startYear,
          'end_year': ?endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend degli iscritti. Riprova più tardi.');
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
          'start_year': ?startYear,
          'end_year': ?endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend dei collaboratori. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il tasso di fidelizzazione. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il tasso di fidelizzazione collaboratori. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare i totali del ruolo. Riprova più tardi.');
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
          'start_year': ?startYear,
          'end_year': ?endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend del ruolo. Riprova più tardi.');
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
          'start_year': ?startYear,
          'end_year': ?endYear,
        },
      );
      return (response.data as List<dynamic>).map((e) => MemberTrendItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare il trend collaboratori del ruolo. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la fidelizzazione del ruolo. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la fidelizzazione collaboratori. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione per città. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione per età. Riprova più tardi.');
    }
  }

  Future<void> updateTeacherCompetences(
    String taxCode,
    List<Map<String, dynamic>> competences,
    List<String> serviceNames,
    DateTime? expectedUpdatedAt,
  ) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/teacher-competences',
        data: {
          'competences': competences,
          'service_names': serviceNames,
          if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore imprevisto. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione scolastica. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare le statistiche sulle materie dei docenti. Riprova più tardi.');
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
      throw Exception(e.response?.data['detail'] ?? 'Impossibile recuperare la distribuzione dei corsi. Riprova più tardi.');
    }
  }

  Future<bool> checkFiscalCodeExists(String fiscalCode) async
  {
    try
    {
      await _dio.get('/people/$fiscalCode');
      return true;
    }
    on DioException catch (e)
    {
      if (e.response?.statusCode == 404)
      {
        return false;
      }
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la verifica del codice fiscale. Riprova più tardi.');
    }
  }

  // --- Availabilities -----------------------------------------------------

  Future<List<AvailabilityItem>> getAvailabilities() async
  {
    final response = await _dio.get('/availabilities/');
    return (response.data as List).map((e) => AvailabilityItem.fromJson(e)).toList();
  }

  Future<AvailabilityItem> createAvailability({
    required String teacherTaxCode,
    required DateTime date,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/availabilities/',
        data: {
          'teacher_tax_code': teacherTaxCode,
          'date':             formatDateOnly(date),
          'mode':             mode,
          'start_time':       formatTimeOfDay(startTime),
          'end_time':         formatTimeOfDay(endTime),
        },
      );
      return AvailabilityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della disponibilità. Riprova più tardi.');
    }
  }

  Future<AvailabilityItem> updateAvailability({
    required int id,
    required String teacherTaxCode,
    required DateTime date,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required DateTime expectedUpdatedAt,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/availabilities/$id',
        data: {
          'teacher_tax_code':    teacherTaxCode,
          'date':                formatDateOnly(date),
          'mode':                mode,
          'start_time':          formatTimeOfDay(startTime),
          'end_time':            formatTimeOfDay(endTime),
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
      return AvailabilityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della disponibilità. Riprova più tardi.');
    }
  }

  Future<void> deleteAvailability(int id) async
  {
    try
    {
      await _dio.delete('/availabilities/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della disponibilità. Riprova più tardi.');
    }
  }

  // --- Lesson requests (Presence + Booking) -----------------------------

  Future<List<PresenceItem>> getPresences() async
  {
    final response = await _dio.get('/presences/');
    return (response.data as List).map((e) => PresenceItem.fromJson(e)).toList();
  }

  // Used to refresh a single presence after a booking mutation: bookings are
  // nested read-only inside PresenceResponse, so there is no dedicated
  // endpoint to patch just that list in place.
  Future<PresenceItem> getPresence(int id) async
  {
    final response = await _dio.get('/presences/$id');
    return PresenceItem.fromJson(response.data);
  }

  // No booker_tax_code sent on either call: every Lezioni request is made by
  // a logged-in admin, and the backend already defaults an absent booker to
  // the calling identity on create, and leaves it untouched on update.
  Future<PresenceItem> createPresence({
    required String studentTaxCode,
    required DateTime date,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/presences/',
        data: {
          'student_tax_code': studentTaxCode,
          'date':             formatDateOnly(date),
          'mode':             mode,
          'start_time':       formatTimeOfDay(startTime),
          'end_time':         formatTimeOfDay(endTime),
        },
      );
      return PresenceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la creazione della richiesta. Riprova più tardi.');
    }
  }

  Future<PresenceItem> updatePresence({
    required int id,
    required String studentTaxCode,
    required DateTime date,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required DateTime expectedUpdatedAt,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/presences/$id',
        data: {
          'student_tax_code':    studentTaxCode,
          'date':                formatDateOnly(date),
          'mode':                mode,
          'start_time':          formatTimeOfDay(startTime),
          'end_time':            formatTimeOfDay(endTime),
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
      return PresenceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della richiesta. Riprova più tardi.');
    }
  }

  Future<void> deletePresence(int id) async
  {
    try
    {
      await _dio.delete('/presences/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della richiesta. Riprova più tardi.');
    }
  }

  // [subject] is the whole requested lesson, as SubjectRequestDraft.toJson()
  // writes it: the kind of request with whatever belongs to it, the duration,
  // the tags, the topic, the notes and the two teacher lists.
  //
  // Whole and not piecemeal, because the backend treats these as a complete
  // write: what does not reach it is cleared rather than left as it was.
  Future<void> createBooking({
    required int presenceId,
    required Map<String, dynamic> subject,
  }) async
  {
    try
    {
      await _dio.post(
        '/bookings/',
        data: {
          'presence_id': presenceId,
          ...subject,
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'aggiunta della materia. Riprova più tardi.');
    }
  }

  Future<void> updateBooking({
    required int id,
    required Map<String, dynamic> subject,
    required DateTime expectedUpdatedAt,
  }) async
  {
    try
    {
      await _dio.put(
        '/bookings/$id',
        data: {
          ...subject,
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante la modifica della materia. Riprova più tardi.');
    }
  }

  Future<void> deleteBooking(int id) async
  {
    try
    {
      await _dio.delete('/bookings/$id');
    }
    on DioException catch (e)
    {
      throw Exception(e.response?.data['detail'] ?? 'Errore durante l\'eliminazione della materia. Riprova più tardi.');
    }
  }
}