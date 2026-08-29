import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../core/config/api_config.dart';
import '../core/utils/json_parsing.dart';
import '../core/utils/time_bucket.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/association/models/opening_day_item.dart';
import '../features/association/tabs/opening_hours/lost_calendars.dart';
import '../features/association/models/room_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/service_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/weekly_template_item.dart';
import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/lessons/models/activity_item.dart';
import '../features/lessons/models/availability_item.dart';
import '../features/lessons/models/calendar_lock_item.dart';
import '../features/lessons/models/calendar_publication_item.dart';
import '../features/lessons/models/lesson_item.dart';
import '../features/lessons/models/presence_item.dart';
import '../features/lessons/models/room_supervision_item.dart';
import '../features/lessons/models/teacher_room_assignment_item.dart';
import '../features/people/models/age_distribution_item.dart';
import '../features/people/models/certification_distribution_item.dart';
import '../features/people/models/city_distribution_item.dart';
import '../features/people/models/course_distribution_item.dart';
import '../features/people/models/current_totals_item.dart';
import '../features/people/models/education_distribution_item.dart';
import '../features/people/models/member_trend_item.dart';
import '../features/people/models/person_item.dart';
import '../features/people/models/retention_rate_item.dart';
import '../features/people/models/personal_statistics_items.dart';
import '../features/people/models/student_presence_statistics_item.dart';
import '../features/people/models/teacher_appreciation_item.dart';
import '../features/people/models/teacher_availability_statistics_item.dart';
import '../features/people/models/teacher_subjects_statistics_item.dart';
import 'auth_state.dart';
import 'session_service.dart';

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

List<AssociationSubjectOption> _associationSubjectOptions(dynamic value)
{
  return value == null
      ? []
      : ((value as List)
          .map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => _byName(a.name, b.name)));
}

SchoolStudyProgramOption _schoolStudyProgramOption(dynamic json)
{
  return SchoolStudyProgramOption(
    id: json['id'],
    name: json['name'],
    level: json['level'] ?? '',
  );
}

SchoolItem _schoolFromJson(dynamic json)
{
  return SchoolItem(
    id: json['id'],
    mechanographicCode: json['mechanographic_code'],
    name: json['name'],
    city: json['city'],
    province: json['province'],
    createdAt: DateTime.parse(json['created_at']),
    studyPrograms: json['study_programs'] != null
        ? ((json['study_programs'] as List).map(_schoolStudyProgramOption).toList()
          ..sort((a, b) => _byName(a.name, b.name)))
        : [],
  );
}

MinistrySubjectOption _ministrySubjectOption(dynamic json)
{
  return MinistrySubjectOption(
    id: json['id'],
    name: json['name'],
    associationSubjects: _associationSubjectOptions(json['association_subjects']),
  );
}

StudyProgramItem _studyProgramFromJson(dynamic json)
{
  return StudyProgramItem(
    id: json['id'],
    name: json['name'],
    sector: json['sector'],
    description: json['description'] ?? '',
    level: json['level'],
    highSchoolTrack: json['high_school_track'],
    minYear: json['min_year'],
    maxYear: json['max_year'],
    createdAt: DateTime.parse(json['created_at']),
    ministrySubjects: json['ministry_subjects'] != null
        ? ((json['ministry_subjects'] as List).map(_ministrySubjectOption).toList()
          ..sort((a, b) => _byName(a.name, b.name)))
        : [],
  );
}

MinistrySubjectItem _ministrySubjectFromJson(dynamic json)
{
  return MinistrySubjectItem(
    id: json['id'],
    name: json['name'],
    level: json['level'],
    areas: (json['area'] as List).cast<String>(),
    description: json['description'],
    createdAt: DateTime.parse(json['created_at']),
    associationSubjects: _associationSubjectOptions(json['association_subjects']),
  );
}

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
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    _dio = Dio(options);
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
          if (error.response?.statusCode != 401 || _refreshToken == null || _isRefreshing)
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

  Never _refused(DioException error, String fallback)
  {
    final detail = error.response?.data is Map ? error.response?.data['detail'] : null;

    // A destructive write is refused with a typed cost, so callers can confirm
    // instead of showing an error.
    if (detail is Map && detail['error'] == WriteWouldTakeAway.code)
    {
      throw WriteWouldTakeAway.fromJson(detail.cast<String, dynamic>());
    }

    throw Exception(detail ?? fallback);
  }

  // With responseType bytes the refusal body arrives as bytes too, which
  // _refused cannot read.
  Never _refusedBytes(DioException error, String fallback)
  {
    final data = error.response?.data;

    if (data is List<int>)
    {
      try
      {
        final decoded = jsonDecode(utf8.decode(data));

        if (decoded is Map && decoded['detail'] != null)
        {
          throw Exception(decoded['detail'].toString());
        }
      }
      on FormatException
      {
        // Binary or truncated body: fall back to the generic message.
      }
    }

    _refused(error, fallback);
  }

  Future<void> _adoptSession(LoginResponse loginResponse) async
  {
    _accessToken = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;

    await SessionService.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    authState.value = loginResponse.passwordResetRequired
        ? AuthState.passwordChangeRequired
        : AuthState.authenticated;
  }

  Future<void> _clearSession() async
  {
    _accessToken = null;
    _refreshToken = null;
    lastKnownIdentity = null;
    await SessionService.clear();
  }

  Future<LoginResponse> _performTokenRefresh() async
  {
    final refreshResponse = await _tokenDio.post(
      '/auth/refresh',
      data: {'refresh_token': _refreshToken},
    );

    final loginResponse = LoginResponse.fromJson(refreshResponse.data);

    await _adoptSession(loginResponse);

    return loginResponse;
  }

  Future<bool> restoreSession() async
  {
    _accessToken = await SessionService.getAccessToken();
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

    await _adoptSession(loginResponse);

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
          'new_password': newPassword,
          'refresh_token': _refreshToken,
        },
      );

      authState.value = AuthState.authenticated;
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il cambio password. Riprova più tardi.');
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
      _refused(e, 'Errore durante la richiesta di recupero password. Riprova più tardi.');
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
      _refused(e, 'Errore durante la reimpostazione della password. Riprova più tardi.');
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
      _refused(e, 'Token non valido o scaduto.');
    }
  }

  Future<List<AssociationSubjectItem>> getAssociationSubjects() async
  {
    final response = await _dio.get('/association-subjects/');
    return parseList(response.data, AssociationSubjectItem.fromJson);
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
    return parseList(response.data, OpeningDayItem.fromJson);
  }

  Future<List<WeeklyTemplateItem>> getWeeklyTemplates() async
  {
    final response = await _dio.get('/weekly-templates/');
    return parseList(response.data, WeeklyTemplateItem.fromJson);
  }

  Future<WeeklyTemplateItem> createWeeklyTemplate({
    required int weekday,
    required String mode,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? effectiveFrom,
    bool confirm = false,
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
        'confirm': confirm,
      });
      return WeeklyTemplateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione dell\'orario. Riprova più tardi.');
    }
  }

  Future<WeeklyTemplateItem> updateWeeklyTemplate({
    required int id,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    DateTime? effectiveFrom,
    bool confirm = false,
  }) async
  {
    try
    {
      final response = await _dio.put('/weekly-templates/$id', data: {
        'start_time': formatTimeOfDay(startTime),
        'end_time': formatTimeOfDay(endTime),
        'effective_from': effectiveFrom != null ? formatDateOnly(effectiveFrom) : null,
        'confirm': confirm,
      });
      return WeeklyTemplateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica dell\'orario. Riprova più tardi.');
    }
  }

  Future<void> deleteWeeklyTemplate(int id, {DateTime? effectiveFrom, bool confirm = false}) async
  {
    try
    {
      await _dio.delete(
        '/weekly-templates/$id',
        queryParameters: {
          if (effectiveFrom != null) 'effective_from': formatDateOnly(effectiveFrom),
          if (confirm) 'confirm': true,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione dell\'orario. Riprova più tardi.');
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
      _refused(e, 'Errore durante la creazione dell\'apertura. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'aggiornamento dell\'apertura. Riprova più tardi.');
    }
  }

  // One call, not delete+create: a day left without hours loses its lessons.
  Future<List<OpeningDayItem>> replaceOpeningDay({
    required DateTime date,
    required String mode,
    required List<(TimeOfDay, TimeOfDay)> bands,
    String? note,
    bool confirm = false,
  }) async
  {
    try
    {
      final response = await _dio.put('/opening-days/day', data: {
        'date': formatDateOnly(date),
        'mode': mode,
        'note': note,
        'confirm': confirm,
        'bands': [
          for (final band in bands)
            {
              'start_time': formatTimeOfDay(band.$1),
              'end_time': formatTimeOfDay(band.$2),
            },
        ],
      });

      return parseList(response.data, OpeningDayItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il salvataggio degli orari. Riprova più tardi.');
    }
  }

  Future<void> deleteOpeningDay(int id, {bool confirm = false}) async
  {
    try
    {
      await _dio.delete(
        '/opening-days/$id',
        queryParameters: {if (confirm) 'confirm': true},
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione dell\'apertura. Riprova più tardi.');
    }
  }

  Future<void> restoreStandardHours({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String mode,
    bool confirm = false,
  }) async
  {
    try
    {
      await _dio.post('/opening-days/restore-standard', data: {
        'confirm': confirm,
        'date_from': formatDateOnly(dateFrom),
        'date_to': formatDateOnly(dateTo),
        'mode': mode,
      });
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il ripristino dell\'orario standard. Riprova più tardi.');
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
      _refused(e, 'Errore durante la creazione. Riprova più tardi.');
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
      _refused(e, 'Errore durante la modifica.');
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
      _refused(e, 'Errore durante l\'eliminazione.');
    }
  }

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

      return parseList(response.data, PresenceItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della richiesta.');
    }
  }

  String _servicePath(String name) => '/services/${Uri.encodeComponent(name)}';

  Future<List<ServiceItem>> getServices() async
  {
    final response = await _dio.get('/services/');
    return parseList(response.data, ServiceItem.fromJson);
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
      _refused(e, 'Errore durante la creazione. Riprova più tardi.');
    }
  }

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
      _refused(e, 'Errore durante la modifica.');
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
      _refused(e, 'Errore durante l\'eliminazione.');
    }
  }

  Future<List<RoomItem>> getRooms() async
  {
    final response = await _dio.get('/rooms/');

    return parseList(response.data, RoomItem.fromJson);
  }

  Future<RoomItem> createRoom({required String name, required String description, int? capacity}) async
  {
    try
    {
      final response = await _dio.post(
        '/rooms/',
        data: {'name': name, 'description': description, 'capacity': capacity},
      );

      return RoomItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della stanza. Riprova più tardi.');
    }
  }

  Future<RoomItem> updateRoom({required int id, required String name, required String description, int? capacity}) async
  {
    try
    {
      final response = await _dio.put(
        '/rooms/$id',
        data: {'name': name, 'description': description, 'capacity': capacity},
      );

      return RoomItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della stanza.');
    }
  }

  Future<void> deleteRoom(int id) async
  {
    try
    {
      await _dio.delete('/rooms/$id');
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione della stanza.');
    }
  }

  String _assignmentPath(DateTime day, String teacherTaxCode)
  {
    return '/teacher-room-assignments/${formatDateOnly(day)}/$teacherTaxCode';
  }

  Future<List<TeacherRoomAssignmentItem>> getTeacherRoomAssignments(DateTime day) async
  {
    final response = await _dio.get(
      '/teacher-room-assignments/',
      queryParameters: {'day': formatDateOnly(day)},
    );

    return parseList(response.data, TeacherRoomAssignmentItem.fromJson);
  }

  Future<TeacherRoomAssignmentItem> assignTeacherRoom({
    required DateTime day,
    required String teacherTaxCode,
    required int roomId,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/teacher-room-assignments/',
        data: {
          'date': formatDateOnly(day),
          'teacher_tax_code': teacherTaxCode,
          'room_id': roomId,
        },
      );

      return TeacherRoomAssignmentItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'assegnazione della stanza.');
    }
  }

  Future<TeacherRoomAssignmentItem> moveTeacherRoom({
    required DateTime day,
    required String teacherTaxCode,
    required int roomId,
    DateTime? expectedUpdatedAt,
  }) async
  {
    try
    {
      final response = await _dio.put(
        _assignmentPath(day, teacherTaxCode),
        data: {
          'room_id': roomId,
          'expected_updated_at': expectedUpdatedAt?.toIso8601String(),
        },
      );

      return TeacherRoomAssignmentItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante lo spostamento di stanza.');
    }
  }

  Future<void> unassignTeacherRoom({required DateTime day, required String teacherTaxCode}) async
  {
    try
    {
      await _dio.delete(_assignmentPath(day, teacherTaxCode));
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la rimozione dell\'assegnazione.');
    }
  }

  Future<List<RoomSupervisionItem>> getRoomSupervisions(DateTime day) async
  {
    final response = await _dio.get(
      '/room-supervisions/',
      queryParameters: {'day': formatDateOnly(day)},
    );

    return parseList(response.data, RoomSupervisionItem.fromJson);
  }

  Future<RoomSupervisionItem> createRoomSupervision({
    required DateTime day,
    required String teacherTaxCode,
    required int roomId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/room-supervisions/',
        data: {
          'date': formatDateOnly(day),
          'teacher_tax_code': teacherTaxCode,
          'room_id': roomId,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
        },
      );

      return RoomSupervisionItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'assegnazione del responsabile.');
    }
  }

  Future<void> deleteRoomSupervision(int id) async
  {
    try
    {
      await _dio.delete('/room-supervisions/$id');
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la rimozione del responsabile.');
    }
  }

  MeResponse? lastKnownIdentity;

  Future<MeResponse> me() async
  {
    final response = await _dio.get('/auth/me');
    final identity = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

    lastKnownIdentity = identity;

    return identity;
  }

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
      _refused(e, 'Errore durante il caricamento dell\'immagine.');
    }
  }

  Future<void> deleteProfileImage() async
  {
    try
    {
      await _dio.delete('/auth/profile-image');

      profileImageVersion++;
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la rimozione dell\'immagine.');
    }
  }

  Future<List<SchoolItem>> getSchools() async
  {
    final response = await _dio.get('/schools/');

    return parseList(response.data, _schoolFromJson);
  }

  Future<SchoolItem> createSchool({String? code, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/schools/',
        data: {
          'mechanographic_code': (code == null || code.isEmpty) ? null : code,
          'name': name,
          'city': city,
          'province': province,
          'study_program_ids': studyProgramIds,
        },
      );

      return _schoolFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della scuola. Riprova più tardi.');
    }
  }

  Future<SchoolItem> updateSchool({required int id, String? code, required String name, required String city, required String province, required List<int> studyProgramIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/schools/$id',
        data: {
          'mechanographic_code': (code == null || code.isEmpty) ? null : code,
          'name': name,
          'city': city,
          'province': province,
          'study_program_ids': studyProgramIds,
        },
      );

      return _schoolFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della scuola. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della scuola. Riprova più tardi.');
    }
  }

  Future<List<StudyProgramItem>> getStudyPrograms() async
  {
    final response = await _dio.get('/study-programs/');

    return parseList(response.data, _studyProgramFromJson);
  }

  Future<StudyProgramItem> createStudyProgram({required String name, required String? sector, required String description, required String level, required String? highSchoolTrack, required int? minYear, required int? maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/study-programs/',
        data: {
          'name': name,
          'sector': sector,
          'description': description,
          'level': level,
          // Null for high school: the server derives the years from the track.
          'high_school_track': highSchoolTrack,
          'min_year': minYear,
          'max_year': maxYear,
          'ministry_subject_ids': ministrySubjectIds,
        },
      );

      return _studyProgramFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione del percorso. Riprova più tardi.');
    }
  }

  Future<StudyProgramItem> updateStudyProgram({required int id, required String name, required String? sector, required String description, required String level, required String? highSchoolTrack, required int? minYear, required int? maxYear, required List<int> ministrySubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/study-programs/$id',
        data: {
          'name': name,
          'sector': sector,
          'description': description,
          'level': level,
          // Null for high school: the server derives the years from the track.
          'high_school_track': highSchoolTrack,
          'min_year': minYear,
          'max_year': maxYear,
          'ministry_subject_ids': ministrySubjectIds,
        },
      );

      return _studyProgramFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica del percorso. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione del percorso. Riprova più tardi.');
    }
  }

  Future<List<MinistrySubjectItem>> getMinistrySubjects() async
  {
    final response = await _dio.get('/ministry-subjects/');

    return parseList(response.data, _ministrySubjectFromJson);
  }

  Future<MinistrySubjectItem> createMinistrySubject({required String name, required String level, required List<String> areas, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.post(
        '/ministry-subjects/',
        data: {
          'name': name,
          'level': level,
          'area': areas,
          'description': description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return _ministrySubjectFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della materia. Riprova più tardi.');
    }
  }

  Future<MinistrySubjectItem> updateMinistrySubject({required int id, required String name, required String level, required List<String> areas, required String description, required List<int> associationSubjectIds}) async
  {
    try
    {
      final response = await _dio.put(
        '/ministry-subjects/$id',
        data: {
          'name': name,
          'level': level,
          'area': areas,
          'description': description,
          'association_subject_ids': associationSubjectIds,
        },
      );

      return _ministrySubjectFromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della materia. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della materia. Riprova più tardi.');
    }
  }

  Future<List<PersonItem>> getPeople() async
  {
    final response = await _dio.get('/people/');
    return parseList(response.data, PersonItem.fromJson);
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
      _refused(e, 'Errore imprevisto durante l\'aggiornamento. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto durante la creazione della persona. Riprova più tardi.');
    }
  }

  // Nothing is stored: the server stamps a copy of the template and returns it.
  Future<Uint8List> generateEnrollmentForm(Map<String, dynamic> payload) async
  {
    try
    {
      final response = await _dio.post<List<int>>(
        '/people/wizard/enrollment-form',
        data: payload,
        options: Options(responseType: ResponseType.bytes),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, 'Errore imprevisto durante la generazione del modulo. Riprova più tardi.');
    }
  }

  // The server rebuilds the payload from the register, so only the tax code is sent.
  Future<Uint8List> fetchEnrollmentForm(String fiscalCode) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/people/$fiscalCode/enrollment-form',
        options: Options(responseType: ResponseType.bytes),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, 'Errore imprevisto durante la generazione del modulo. Riprova più tardi.');
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
      _refused(e, 'Impossibile inviare la segnalazione. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto durante l\'aggiornamento delle iscrizioni. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto durante la revoca dell\'iscrizione. Riprova più tardi.');
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
    _refused(e, 'Errore imprevisto durante l\'aggiornamento degli anni scolastici. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare i totali attuali. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il trend degli iscritti. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il trend dei collaboratori. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il tasso di fidelizzazione. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il tasso di fidelizzazione collaboratori. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare i totali del ruolo. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il trend del ruolo. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare il trend collaboratori del ruolo. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare la fidelizzazione del ruolo. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare la fidelizzazione collaboratori. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare la distribuzione per città. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare la distribuzione per età. Riprova più tardi.');
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
      _refused(e, 'Errore imprevisto. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare la distribuzione scolastica. Riprova più tardi.');
    }
  }

  Future<List<CertificationDistributionItem>> getStudentCertificationDistribution() async
  {
    try
    {
      final response = await _dio.get('/statistics/students/certification-distribution');
      return (response.data as List<dynamic>).map((e) => CertificationDistributionItem.fromJson(e)).toList();
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare la distribuzione delle certificazioni. Riprova più tardi.');
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
      _refused(e, 'Impossibile recuperare le statistiche sulle materie dei docenti. Riprova più tardi.');
    }
  }

  Future<TeacherAppreciationRankingItem> getTeacherAppreciationRanking({int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/appreciation-ranking',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return TeacherAppreciationRankingItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare il gradimento dei docenti. Riprova più tardi.');
    }
  }

  Future<TeacherAvailabilityStatisticsItem> getTeacherAvailabilityStatistics({int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/availability-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return TeacherAvailabilityStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare le statistiche sulle disponibilità. Riprova più tardi.');
    }
  }

  Future<StudentPresenceStatisticsItem> getStudentPresenceStatistics({int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/presence-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return StudentPresenceStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare le statistiche sulle presenze. Riprova più tardi.');
    }
  }

  Future<TeacherPersonalStatisticsItem> getTeacherPersonalStatistics(String taxCode, {int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/$taxCode/personal-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return TeacherPersonalStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare le statistiche personali. Riprova più tardi.');
    }
  }

  Future<StudentPersonalStatisticsItem> getStudentPersonalStatistics(String taxCode, {int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/$taxCode/personal-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return StudentPersonalStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare le statistiche personali. Riprova più tardi.');
    }
  }

  // Separate from the presence statistics: the discipline is chosen after the
  // page has loaded.
  Future<List<MemberTrendItem>> getDisciplineRequestTrend(int associationSubjectId) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/discipline-trend',
        queryParameters: {'association_subject_id': associationSubjectId},
      );
      return monthlyTrendPoints(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, "Impossibile recuperare l'andamento della disciplina. Riprova più tardi.");
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
      _refused(e, 'Impossibile recuperare la distribuzione dei corsi. Riprova più tardi.');
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
      _refused(e, 'Errore durante la verifica del codice fiscale. Riprova più tardi.');
    }
  }

  Future<List<AvailabilityItem>> getAvailabilities({DateTime? dateFrom, DateTime? dateTo}) async
  {
    final response = await _dio.get(
      '/availabilities/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, AvailabilityItem.fromJson);
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
          'date': formatDateOnly(date),
          'mode': mode,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
        },
      );
      return AvailabilityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della disponibilità. Riprova più tardi.');
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
          'teacher_tax_code': teacherTaxCode,
          'date': formatDateOnly(date),
          'mode': mode,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
      return AvailabilityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della disponibilità. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della disponibilità. Riprova più tardi.');
    }
  }

  Future<List<PresenceItem>> getPresences({DateTime? dateFrom, DateTime? dateTo}) async
  {
    final response = await _dio.get(
      '/presences/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, PresenceItem.fromJson);
  }

  Future<PresenceItem> getPresence(int id) async
  {
    final response = await _dio.get('/presences/$id');
    return PresenceItem.fromJson(response.data);
  }

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
          'date': formatDateOnly(date),
          'mode': mode,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
        },
      );
      return PresenceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della richiesta. Riprova più tardi.');
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
          'student_tax_code': studentTaxCode,
          'date': formatDateOnly(date),
          'mode': mode,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
      return PresenceItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della richiesta. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della richiesta. Riprova più tardi.');
    }
  }

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
      _refused(e, 'Errore durante l\'aggiunta della materia. Riprova più tardi.');
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
      _refused(e, 'Errore durante la modifica della materia. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della materia. Riprova più tardi.');
    }
  }

  Future<List<LessonItem>> getLessons({DateTime? dateFrom, DateTime? dateTo}) async
  {
    final response = await _dio.get(
      '/lessons/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, LessonItem.fromJson);
  }

  Future<LessonItem> createLesson({
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/lessons/',
        data: {
          'availability_id': availabilityId,
          'booking_ids': bookingIds,
          'association_subject_ids': associationSubjectIds,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
        },
      );

      return LessonItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della lezione. Riprova più tardi.');
    }
  }

  Future<LessonItem> updateLesson({
    required int id,
    required int availabilityId,
    required List<int> bookingIds,
    required List<int> associationSubjectIds,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required DateTime expectedUpdatedAt,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/lessons/$id',
        data: {
          'availability_id': availabilityId,
          'booking_ids': bookingIds,
          'association_subject_ids': associationSubjectIds,
          'start_time': formatTimeOfDay(startTime),
          'end_time': formatTimeOfDay(endTime),
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );

      return LessonItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica della lezione. Riprova più tardi.');
    }
  }

  Future<void> deleteLesson(int id) async
  {
    try
    {
      await _dio.delete('/lessons/$id');
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione della lezione. Riprova più tardi.');
    }
  }

  Future<List<ActivityItem>> getCalendarActivities({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async
  {
    final response = await _dio.get(
      '/calendar-activities/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, ActivityItem.fromJson);
  }

  Future<ActivityItem> createCalendarActivity({
    required DateTime day,
    required TimeBucket band,
    required String name,
    String? description,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/calendar-activities/',
        data: {
          'date': formatDateOnly(day),
          'band': LessonItem.formatBand(band),
          'name': name,
          'description': description,
        },
      );

      return ActivityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione dell\'attività. Riprova più tardi.');
    }
  }

  Future<ActivityItem> updateCalendarActivity({
    required int id,
    required String name,
    String? description,
    int? availabilityId,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    required DateTime expectedUpdatedAt,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/calendar-activities/$id',
        data: {
          'name': name,
          'description': description,
          'assignment': availabilityId == null || startTime == null || endTime == null
              ? null
              : {
                  'availability_id': availabilityId,
                  'start_time': formatTimeOfDay(startTime),
                  'end_time': formatTimeOfDay(endTime),
                },
          'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );

      return ActivityItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica dell\'attività. Riprova più tardi.');
    }
  }

  Future<void> deleteCalendarActivity(int id) async
  {
    try
    {
      await _dio.delete('/calendar-activities/$id');
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione dell\'attività. Riprova più tardi.');
    }
  }

  String _publicationPath(DateTime day, TimeBucket band)
  {
    return '/calendar-publications/${formatDateOnly(day)}/${LessonItem.formatBand(band)}';
  }

  Future<List<CalendarPublicationItem>> getCalendarPublications({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async
  {
    final response = await _dio.get(
      '/calendar-publications/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, CalendarPublicationItem.fromJson);
  }

  Future<CalendarPublicationItem> publishBand({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/calendar-publications/',
        data: {
          'date': formatDateOnly(day),
          'band': LessonItem.formatBand(band),
        },
      );

      return CalendarPublicationItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la pubblicazione del calendario.');
    }
  }

  Future<CalendarPublicationItem> reopenBand({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    try
    {
      final response = await _dio.post('${_publicationPath(day, band)}/draft');

      return CalendarPublicationItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il ritorno in bozza.');
    }
  }

  Future<({CalendarPublicationItem publication, int lost})> discardDraft({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    try
    {
      final response = await _dio.post('${_publicationPath(day, band)}/discard');

      return (
        publication: CalendarPublicationItem.fromJson(
          response.data['publication'] as Map<String, dynamic>,
        ),
        lost: response.data['lost'] as int,
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'uscita dalla bozza.');
    }
  }

  Future<({CalendarPublicationItem publication, bool resent})> closeDraft({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    try
    {
      final response = await _dio.delete('${_publicationPath(day, band)}/draft');

      return (
        publication: CalendarPublicationItem.fromJson(
          response.data['publication'] as Map<String, dynamic>,
        ),
        resent: response.data['resent'] as bool,
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la pubblicazione delle modifiche.');
    }
  }

  Future<Set<String>> getExcludedTeachers({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    final response = await _dio.get(
      '/calendar-teacher-exclusions/',
      queryParameters: {
        'exclusion_date': formatDateOnly(day),
        'band': LessonItem.formatBand(band),
      },
    );

    return {
      for (final row in (response.data as List).cast<Map<String, dynamic>>())
        row['teacher_tax_code'] as String,
    };
  }

  Future<({int lessons, int activities})> excludeTeacher({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
  }) async
  {
    try
    {
      final response = await _dio.post(
        '/calendar-teacher-exclusions/',
        data: {
          'date': formatDateOnly(day),
          'band': LessonItem.formatBand(band),
          'teacher_tax_code': teacherTaxCode,
        },
      );

      return (
        lessons: response.data['unplanned_lessons'] as int,
        activities: response.data['unassigned_activities'] as int,
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'esclusione del docente.');
    }
  }

  Future<void> readmitTeacher({
    required DateTime day,
    required TimeBucket band,
    required String teacherTaxCode,
  }) async
  {
    try
    {
      await _dio.delete(
        '/calendar-teacher-exclusions/${formatDateOnly(day)}/'
        '${LessonItem.formatBand(band)}/$teacherTaxCode',
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il reinserimento del docente.');
    }
  }

  String _lockPath(DateTime day, TimeBucket band)
  {
    return '/calendar-locks/${formatDateOnly(day)}/${LessonItem.formatBand(band)}';
  }

  Future<List<CalendarLockItem>> getCalendarLocks({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async
  {
    final response = await _dio.get(
      '/calendar-locks/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
      },
    );

    return parseList(response.data, CalendarLockItem.fromJson);
  }

  Future<CalendarLockState> heartbeatCalendarLock({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    final response = await _dio.post('${_lockPath(day, band)}/heartbeat');

    return CalendarLockState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> releaseCalendarLock({
    required DateTime day,
    required TimeBucket band,
  }) async
  {
    await _dio.delete(_lockPath(day, band));
  }
}

extension _OptionalDate on DateTime?
{
  String? let(String Function(DateTime) format)
  {
    final value = this;

    return value == null ? null : format(value);
  }
}
