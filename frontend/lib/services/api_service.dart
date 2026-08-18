import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../core/config/api_config.dart';
import '../core/utils/json_parsing.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/association/models/opening_day_item.dart';
import '../features/association/models/room_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/service_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/weekly_template_item.dart';
import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/lessons/models/availability_item.dart';
import '../features/lessons/models/lesson_item.dart';
import '../features/lessons/models/presence_item.dart';
import '../features/lessons/models/room_supervision_item.dart';
import '../features/lessons/models/teacher_room_assignment_item.dart';
import '../features/people/models/age_distribution_item.dart';
import '../features/people/models/city_distribution_item.dart';
import '../features/people/models/course_distribution_item.dart';
import '../features/people/models/current_totals_item.dart';
import '../features/people/models/education_distribution_item.dart';
import '../features/people/models/member_trend_item.dart';
import '../features/people/models/person_item.dart';
import '../features/people/models/retention_rate_item.dart';
import '../features/people/models/teacher_subjects_statistics_item.dart';
import 'auth_state.dart';
import 'session_service.dart';

// Three models of the association carry no fromJson of their own, unlike every
// other model in the app, so their parsing lives here. One function each rather
// than the same block written out in the list, the create and the update: three
// copies of a shape are three places to forget a field.
//
// Untyped on purpose, the way the call sites were: a cast added here would be a
// new way to fail on a payload that used to get through.

List<AssociationSubjectOption> _associationSubjectOptions(dynamic value)
{
  return value == null
      ? []
      : (value as List)
          .map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>))
          .toList();
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
        ? (json['study_programs'] as List).map(_schoolStudyProgramOption).toList()
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
    minYear: json['min_year'],
    maxYear: json['max_year'],
    createdAt: DateTime.parse(json['created_at']),
    ministrySubjects: json['ministry_subjects'] != null
        ? (json['ministry_subjects'] as List).map(_ministrySubjectOption).toList()
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
          // A refresh already in flight is not waited on: the call that hit the
          // 401 fails, and whatever raised it retries once the session is back.
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

            // The refresh call carries the old token in its own body, so
            // replaying it verbatim would send the one just spent.
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

  // The sentence the server sent with its refusal, or [fallback] where it sent
  // none — a timeout, or anything that never reached the API's own handler.
  //
  // Every call in this file ends a `on DioException` this way, so how a refusal
  // is unwrapped is decided here once instead of at seventy-five call sites.
  // [Never] is what lets it stand alone in a catch: the analyzer knows nothing
  // follows it, so the caller needs no unreachable return after it.
  Never _refused(DioException error, String fallback)
  {
    throw Exception(error.response?.data['detail'] ?? fallback);
  }

  // Takes the pair of tokens a login or a refresh came back with, stores them,
  // and moves the app to whatever state the account is in.
  //
  // The mandatory password reset is decided here and nowhere else, so it is
  // read at the same point however a valid token was obtained.
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

  // Trades the refresh token for a fresh pair. Used both by the 401 interceptor
  // and by [restoreSession].
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

      // The password was changed successfully: the account no longer has a
      // pending reset, so the global router redirect sends the user back to the
      // dashboard automatically.
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
      _refused(e, 'Errore durante la creazione della fascia oraria. Riprova più tardi.');
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
      _refused(e, 'Errore durante la modifica della fascia oraria. Riprova più tardi.');
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
      _refused(e, 'Errore durante l\'eliminazione della fascia oraria. Riprova più tardi.');
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

  Future<void> deleteOpeningDay(int id) async
  {
    try
    {
      await _dio.delete('/opening-days/$id');
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione dell\'apertura. Riprova più tardi.');
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

      return parseList(response.data, PresenceItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione della richiesta.');
    }
  }

  // Il nome è la chiave di un servizio, e i nomi hanno spazi e accenti: vanno
  // codificati, altrimenti "Metodo di studio" arriva spezzato nel path.
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

  // The capacity travels as null where it was left blank, and not as zero: the
  // backend refuses a zero, and a room nobody has counted is not a room with no
  // seats in it.
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

  // --- Teacher room assignments ---------------------------------------------

  // A day at a time and never a range: rooms are handed out once a day's
  // lessons are settled, and the window that does it is looking at one day.

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

  // Moving a teacher to another room, not writing a second assignment: there is
  // one room per teacher per day, and the supervision shifts follow the teacher
  // across by cascade.
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

  // --- Room supervisions ----------------------------------------------------

  // Written and thrown away rather than moved: a shift is a stretch of hours and
  // nothing else, so changing who covers what is the same work either way, and
  // there is no third verb here for that reason.

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
      _refused(e, 'Errore durante il caricamento dell\'immagine.');
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
          // Null when absent: the backend normalizes an empty string to null anyway.
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
          // Null when absent: the backend normalizes an empty string to null anyway.
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

  Future<StudyProgramItem> createStudyProgram({required String name, required String? sector, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
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

  Future<StudyProgramItem> updateStudyProgram({required int id, required String name, required String? sector, required String description, required String level, required int minYear, required int maxYear, required List<int> ministrySubjectIds}) async
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

  // --- Availabilities -----------------------------------------------------

  // The whole list where no dates are given, which is what the lessons page asks
  // for when it opens. A range is for one day at a time: the calendar can be
  // walked past the booking window, and out there the day has to be fetched.
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

  // --- Lesson requests (Presence + Booking) -----------------------------

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

  // --- Lessons ------------------------------------------------------------

  // The whole booking window in one answer, the way the availabilities and the
  // presences beside it are asked for: the calendar walks its days without
  // going back to the network, and what it draws is the same three lists.
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

  // The bookings and the disciplines travel as whole lists on both the create
  // and the update: a lesson is written entire, and what does not reach the
  // server is unlinked rather than left as it was.
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

  // Moving a lesson to another teacher is a change of availability and nothing
  // else: the identity of the hour is the row, not the person on it.
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
}

// Formats a date only where there is one, so that an absent filter can be
// dropped from the query with the null-aware spread instead of being spelled
// out over three lines above every call.
extension _OptionalDate on DateTime?
{
  String? let(String Function(DateTime) format)
  {
    final value = this;

    return value == null ? null : format(value);
  }
}
