import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../core/config/api_config.dart';
import '../core/utils/content_disposition.dart';
import '../core/utils/json_parsing.dart';
import '../core/utils/time_bucket.dart';
import '../features/association/models/association_subject_item.dart';
import '../features/association/models/ministry_subject_item.dart';
import '../features/association/models/opening_day_item.dart';
import '../features/association/tabs/opening_hours/lost_calendars.dart';
import '../features/association/models/course_item.dart';
import '../features/association/models/room_item.dart';
import '../features/association/models/school_item.dart';
import '../features/association/models/service_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/weekly_template_item.dart';
import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/home/models/month_summary_items.dart';
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
import '../features/settings/models/session_item.dart';
import 'auth_state.dart';
import 'browser_tabs.dart';
import 'client_form_factor.dart';
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

typedef ApiFile = ({Uint8List bytes, String fileName});

// What a tab tells the other tabs of its browser.
abstract final class _TabNews
{
  static const String signedIn = 'signed-in';
  static const String signedOut = 'signed-out';
  static const String peopleChanged = 'people-changed';
  static const String cataloguesChanged = 'catalogues-changed';
  static const String bandReleased = 'band-released';
}

// The session ended in another tab while this one waited its turn.
class _SessionEnded implements Exception
{
  const _SessionEnded();
}

// One list per endpoint: concurrent readers share the request, later readers
// the value, a write drops both. Copies go out, so a caller sorting in place
// cannot touch the cache.
class _ListMemo<T>
{
  List<T>? _value;
  Future<List<T>>? _inFlight;
  int _epoch = 0;

  Future<List<T>> read(Future<List<T>> Function() fetch, {bool refresh = false}) async
  {
    final Future<List<T>>? shared = _inFlight;

    if (shared != null)
    {
      return List<T>.of(await shared);
    }

    final List<T>? known = _value;

    if (!refresh && known != null)
    {
      return List<T>.of(known);
    }

    final int epoch = _epoch;
    final Future<List<T>> request = fetch();

    _inFlight = request;

    try
    {
      final List<T> value = await request;

      // A write in the meantime bumped the epoch: this result predates it.
      if (epoch == _epoch)
      {
        _value = value;
      }

      return List<T>.of(value);
    }
    finally
    {
      if (identical(_inFlight, request))
      {
        _inFlight = null;
      }
    }
  }

  void invalidate()
  {
    _value = null;
    _inFlight = null;
    _epoch++;
  }
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

  Future<void>? _refreshing;

  static const String _formFactorHeader = 'X-Client-Form-Factor';

  // A browser refuses a page-set agent and sends its own; the native apps
  // announce themselves, as the default "Dart/x.y" says nothing useful.
  static final String? _appUserAgent =
      kIsWeb ? null : 'CasaMichela/app (${defaultTargetPlatform.name.toLowerCase()})';

  // Resolved on first use: a native view has no size before its first frame.
  String? _formFactor;

  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.loading);

  // The router's redirect is synchronous and needs the active role, so the identity lives in a notifier.
  final ValueNotifier<MeResponse?> identity = ValueNotifier(null);

  final _ListMemo<PersonItem> _peopleMemo = _ListMemo();
  final _ListMemo<PersonItem> _teachersMemo = _ListMemo();
  final _ListMemo<SchoolItem> _schoolsMemo = _ListMemo();
  final _ListMemo<StudyProgramItem> _studyProgramsMemo = _ListMemo();
  final _ListMemo<AssociationSubjectItem> _associationSubjectsMemo = _ListMemo();
  final _ListMemo<MinistrySubjectItem> _ministrySubjectsMemo = _ListMemo();
  final _ListMemo<ServiceItem> _servicesMemo = _ListMemo();
  final _ListMemo<CourseItem> _coursesMemo = _ListMemo();
  final _ListMemo<RoomItem> _roomsMemo = _ListMemo();

  Future<MeResponse>? _meInFlight;

  // The band lock belongs to the account, not the tab: bumped when another
  // tab lets one go, so a tab still editing takes it back.
  final ValueNotifier<int> calendarLocksReleasedElsewhere = ValueNotifier(0);

  static const String _sessionLock = 'casa-michela-session';

  void _dropPeople()
  {
    _peopleMemo.invalidate();
    _teachersMemo.invalidate();
  }

  // A renamed subject, service or school shows up in the register too.
  void _dropCatalogues()
  {
    _schoolsMemo.invalidate();
    _studyProgramsMemo.invalidate();
    _associationSubjectsMemo.invalidate();
    _ministrySubjectsMemo.invalidate();
    _servicesMemo.invalidate();
    _coursesMemo.invalidate();
    _roomsMemo.invalidate();
    _dropPeople();
  }

  // After a write: the other tabs of the browser drop their copies too.
  void _forgetPeople()
  {
    _dropPeople();
    tellOtherTabs({'news': _TabNews.peopleChanged});
  }

  void _forgetCatalogues()
  {
    _dropCatalogues();
    tellOtherTabs({'news': _TabNews.cataloguesChanged});
  }

  void _forgetAll()
  {
    _dropCatalogues();
    _meInFlight = null;
  }

  void _hearFromOtherTab(Map<String, String> message)
  {
    switch (message['news'])
    {
      case _TabNews.signedIn:
        // A tab waiting at the sign-in page follows the one that signed in.
        if (authState.value == AuthState.unauthenticated)
        {
          unawaited(restoreSession());
        }

      case _TabNews.signedOut:
        final String? own = _refreshToken;

        if (own != null && _sessionOf(own) == message['session'])
        {
          _leaveSession();
        }

      case _TabNews.peopleChanged:
        _dropPeople();

      case _TabNews.cataloguesChanged:
        _dropCatalogues();

      case _TabNews.bandReleased:
        calendarLocksReleasedElsewhere.value++;
    }
  }

  ApiService._internal()
  {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    _dio = Dio(options);
    _tokenDio = Dio(options);

    _tokenDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler)
        {
          _describeClient(options);

          return handler.next(options);
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler)
        {
          _describeClient(options);

          if (_accessToken != null)
          {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }

          return handler.next(options);
        },
        onError: (error, handler) async
        {
          final RequestOptions request = error.requestOptions;

          if (error.response?.statusCode != 401 ||
              _refreshToken == null ||
              request.extra['retried'] == true)
          {
            return handler.next(error);
          }

          // A request that failed on an older token retries with the one in hand.
          if (request.headers['Authorization'] == 'Bearer $_accessToken')
          {
            try
            {
              await _refreshOnce();
            }
            catch (refreshError)
            {
              if (_sessionRefused(refreshError))
              {
                _leaveSession();

                return handler.next(error);
              }

              // No answer: the session stays, the next request renews it.
              return handler.next(
                refreshError is DioException
                    ? refreshError.copyWith(requestOptions: request)
                    : DioException(requestOptions: request, error: refreshError),
              );
            }
          }

          request.headers['Authorization'] = 'Bearer $_accessToken';
          request.extra['retried'] = true;

          if (request.data is Map && (request.data as Map).containsKey('refresh_token'))
          {
            (request.data as Map)['refresh_token'] = _refreshToken;
          }

          // A FormData can be sent only once: the retry needs a fresh copy.
          if (request.data is FormData)
          {
            request.data = (request.data as FormData).clone();
          }

          try
          {
            return handler.resolve(await _dio.fetch(request));
          }
          on DioException catch (retryError)
          {
            return handler.next(retryError);
          }
        },
      ),
    );

    listenToOtherTabs(_hearFromOtherTab);
  }

  // The request that opens or renews a session says what device it is on, so
  // the sessions list can name it.
  void _describeClient(RequestOptions options)
  {
    if (options.path != '/auth/login' && options.path != '/auth/refresh')
    {
      return;
    }

    _formFactor ??= clientFormFactor();

    if (_formFactor != null)
    {
      options.headers[_formFactorHeader] = _formFactor;
    }

    if (_appUserAgent != null)
    {
      options.headers['User-Agent'] = _appUserAgent;
    }
  }

  bool get isAuthenticated
  {
    return _accessToken != null && _refreshToken != null;
  }

  // Every 401 during a refresh waits for the same one instead of failing.
  Future<void> _refreshOnce()
  {
    return _refreshing ??= _renewTokens().whenComplete(() => _refreshing = null);
  }

  // The tabs of one browser share a session: they renew it in turn, and a tab
  // finding it already renewed by another adopts that pair instead. Tokens
  // only, no /auth/me: a renewal started by a refused /auth/me would
  // otherwise wait on that very request, and neither would ever finish.
  Future<void> _renewTokens()
  {
    return inTurnWithOtherTabs(_sessionLock, () async
    {
      if (await _catchUpWithOtherTabs() && _secondsLeft(_accessToken!) > 60)
      {
        return;
      }

      final String? spent = _refreshToken;

      if (spent == null)
      {
        throw const _SessionEnded();
      }

      try
      {
        await _adoptTokens(await _performTokenRefresh());
      }
      catch (error)
      {
        if (_sessionRefused(error))
        {
          await SessionService.clearIfHolding(spent);
          tellOtherTabs({'news': _TabNews.signedOut, 'session': _sessionOf(spent) ?? ''});
        }

        rethrow;
      }
    });
  }

  // A pair stored by another tab for the same account is newer than the one
  // in memory: renewals take turns and each stores its pair before the next.
  Future<bool> _catchUpWithOtherTabs() async
  {
    final String? own = _refreshToken;
    final StoredSession stored = await SessionService.read();
    final String? storedAccess = stored.accessToken;
    final String? storedRefresh = stored.refreshToken;

    if (own == null || storedAccess == null || storedRefresh == null || storedRefresh == own)
    {
      return false;
    }

    final String? account = _accountOf(own);

    if (account == null || _accountOf(storedRefresh) != account)
    {
      return false;
    }

    _accessToken = storedAccess;
    _refreshToken = storedRefresh;

    return true;
  }

  // Read unverified, to choose between tokens: the server verifies them.
  static Map<String, dynamic> _claims(String token)
  {
    final List<String> parts = token.split('.');

    if (parts.length != 3)
    {
      return const {};
    }

    try
    {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
      );
    }
    catch (_)
    {
      return const {};
    }
  }

  // Seconds before the token expires; zero when it cannot be read.
  static int _secondsLeft(String token)
  {
    final Object? expiry = _claims(token)['exp'];

    if (expiry is! num)
    {
      return 0;
    }

    return expiry.toInt() - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static String? _accountOf(String token)
  {
    final Object? subject = _claims(token)['sub'];

    return subject is String ? subject : null;
  }

  // Tokens issued before sessions were tracked carry no id: the account
  // stands in for it.
  static String? _sessionOf(String token)
  {
    final Object? session = _claims(token)['sid'];

    return session is String ? session : _accountOf(token);
  }

  // Only the server turning the tokens down ends a session.
  static bool _sessionRefused(Object error)
  {
    return error is _SessionEnded || (error is DioException && error.response?.statusCode == 401);
  }

  static bool _passwordResetRequired(Object error)
  {
    if (error is! DioException || error.response?.statusCode != 403)
    {
      return false;
    }

    final data = error.response?.data;

    return data is Map && data['detail'] == 'PASSWORD_RESET_REQUIRED';
  }

  Never _refused(DioException error, String fallback)
  {
    final detail = error.response?.data is Map ? error.response?.data['detail'] : null;

    // A destructive write is refused with a typed cost, so callers can confirm instead of erroring.
    if (detail is Map && detail['error'] == WriteWouldTakeAway.code)
    {
      throw WriteWouldTakeAway.fromJson(detail.cast<String, dynamic>());
    }

    throw Exception(detail ?? fallback);
  }

  // With responseType bytes the refusal body arrives as bytes too, which _refused cannot read.
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
    await _adoptTokens(loginResponse);

    if (!loginResponse.passwordResetRequired)
    {
      await _announceAuthenticated();
    }
  }

  Future<void> _adoptTokens(LoginResponse loginResponse) async
  {
    _accessToken = loginResponse.accessToken;
    _refreshToken = loginResponse.refreshToken;

    await SessionService.saveTokens(
      accessToken: loginResponse.accessToken,
      refreshToken: loginResponse.refreshToken,
    );

    if (loginResponse.passwordResetRequired)
    {
      authState.value = AuthState.passwordChangeRequired;
    }
  }

  // Identity must be in hand before the session is announced: the router reads the active role synchronously.
  Future<void> _announceAuthenticated() async
  {
    if (identity.value == null)
    {
      try
      {
        await me();
      }
      catch (e)
      {
        // Refused until the forced password change is done, like a login is.
        if (_passwordResetRequired(e))
        {
          authState.value = AuthState.passwordChangeRequired;

          return;
        }

        _leaveSession();

        return;
      }
    }

    authState.value = AuthState.authenticated;
  }

  // Memory only: a refused pair left storage with the renewal that met the
  // refusal, and one without an answer stays there for the next start.
  void _leaveSession()
  {
    _forgetSession();
    authState.value = AuthState.unauthenticated;
  }

  void _forgetSession()
  {
    _forgetAll();
    _accessToken = null;
    _refreshToken = null;
    identity.value = null;
  }

  Future<LoginResponse> _performTokenRefresh() async
  {
    final refreshResponse = await _tokenDio.post(
      '/auth/refresh',
      data: {'refresh_token': _refreshToken},
    );

    return LoginResponse.fromJson(refreshResponse.data);
  }

  Future<bool> restoreSession() async
  {
    final StoredSession stored = await SessionService.read();

    _accessToken = stored.accessToken;
    _refreshToken = stored.refreshToken;

    if (_accessToken == null || _refreshToken == null)
    {
      authState.value = AuthState.unauthenticated;
      return false;
    }

    try
    {
      // A token with time left skips the refresh: one round trip, not two.
      if (_secondsLeft(_accessToken!) <= 60)
      {
        await _renewTokens();
      }

      await _announceAuthenticated();

      return isAuthenticated;
    }
    catch (_)
    {
      _leaveSession();
      return false;
    }
  }

  Future<LoginResponse> login({required String username, required String password}) async
  {
    _forgetAll();

    final response = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );

    final loginResponse = LoginResponse.fromJson(response.data);

    await _adoptSession(loginResponse);

    tellOtherTabs({'news': _TabNews.signedIn});

    return loginResponse;
  }

  // In turn with renewals, so the server gets the pair another tab may have
  // just renewed rather than the spent one in memory.
  Future<void> logout() async
  {
    final String? ended = await inTurnWithOtherTabs(_sessionLock, () async
    {
      await _catchUpWithOtherTabs();

      final String? refreshToken = _refreshToken;

      if (refreshToken == null)
      {
        return null;
      }

      try
      {
        await _tokenDio.post(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
      catch (_) {}

      await SessionService.clearIfHolding(refreshToken);

      return refreshToken;
    });

    if (ended != null)
    {
      tellOtherTabs({'news': _TabNews.signedOut, 'session': _sessionOf(ended) ?? ''});
    }

    _leaveSession();
  }

  Future<List<SessionItem>> getSessions() async
  {
    try
    {
      final response = await _dio.get('/auth/sessions');

      return (response.data as List)
          .map((item) => SessionItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile caricare le sessioni.');
    }
  }

  Future<void> revokeSession(String sessionId) async
  {
    try
    {
      await _dio.delete('/auth/sessions/$sessionId');
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile disattivare la sessione.');
    }
  }

  // Every session but this one; the tokens in hand stay valid.
  Future<void> revokeOtherSessions() async
  {
    try
    {
      await _dio.delete('/auth/sessions');
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile disattivare le altre sessioni.');
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async
  {
    // The body names the session to keep: the pair another tab renewed.
    await _catchUpWithOtherTabs();

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

      await _announceAuthenticated();
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
      // No response means no server was reached: callers tell that apart from a refusal.
      if (e.response == null)
      {
        rethrow;
      }

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

  Future<List<AssociationSubjectItem>> getAssociationSubjects({bool refresh = false})
  {
    return _associationSubjectsMemo.read(() async
    {
      final response = await _dio.get('/association-subjects/');
      return parseList(response.data, AssociationSubjectItem.fromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<void> reportMissingSubject(String name, String? description) async
  {
    try
    {
      await _dio.post(
        '/association-subjects/report-missing',
        data: {'name': name, 'description': description},
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile inviare la segnalazione. Riprova più tardi.');
    }
  }

  Future<void> reportProblem(String description) async
  {
    try
    {
      await _dio.post('/support/report-problem', data: {'description': description});
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile inviare la segnalazione. Riprova più tardi.');
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

  Future<List<ServiceItem>> getServices({bool refresh = false})
  {
    return _servicesMemo.read(() async
    {
      final response = await _dio.get('/services/');
      return parseList(response.data, ServiceItem.fromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
    }
  }

  String _coursePath(String name) => '/courses/${Uri.encodeComponent(name)}';

  Future<List<CourseItem>> getCourses({bool refresh = false})
  {
    return _coursesMemo.read(() async
    {
      final response = await _dio.get('/courses/');
      return parseList(response.data, CourseItem.fromJson);
    }, refresh: refresh);
  }

  Future<CourseItem> createCourse(String name, String cost, String description) async
  {
    try
    {
      final response = await _dio.post(
        '/courses/',
        data: {'name': name, 'cost': cost, 'description': description},
      );
      return CourseItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la creazione. Riprova più tardi.');
    }
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<CourseItem> updateCourse(String originalName, String name, String cost, String description) async
  {
    try
    {
      final response = await _dio.put(
        _coursePath(originalName),
        data: {'name': name, 'cost': cost, 'description': description},
      );
      return CourseItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante la modifica.');
    }
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<void> deleteCourse(String name) async
  {
    try
    {
      await _dio.delete(_coursePath(name));
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante l\'eliminazione.');
    }
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<List<RoomItem>> getRooms({bool refresh = false})
  {
    return _roomsMemo.read(() async
    {
      final response = await _dio.get('/rooms/');

      return parseList(response.data, RoomItem.fromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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

  MeResponse? get lastKnownIdentity => identity.value;

  // Concurrent callers share one round trip; the value itself is never cached.
  Future<MeResponse> me()
  {
    return _meInFlight ??= _fetchMe().whenComplete(() => _meInFlight = null);
  }

  Future<MeResponse> _fetchMe() async
  {
    final response = await _dio.get('/auth/me');
    final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

    identity.value = me;

    return me;
  }

  Future<MeResponse> completeOnboarding() async
  {
    try
    {
      final response = await _dio.post('/auth/complete-onboarding');
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il completamento del primo accesso. Riprova più tardi.');
    }
  }

  Future<MeResponse> setActiveRole(String role) async
  {
    try
    {
      final response = await _dio.put('/auth/active-role', data: {'role': role});
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il cambio di ruolo. Riprova più tardi.');
    }
  }

  Future<void> updateContacts({
    required String taxCode,
    required String email,
    required String phoneNumber,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/contacts',
        data: {'email': email, 'phone': phoneNumber},
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il salvataggio dei contatti. Riprova più tardi.');
    }
    finally
    {
      _forgetPeople();
    }
  }

  Future<void> updateTeacherEducation({
    required String taxCode,
    required bool isHighSchoolStudent,
    String? schoolEducation,
    String? universityEducation,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/teacher-education',
        data: {
          'is_high_school_student': isHighSchoolStudent,
          'school_education': schoolEducation,
          'university_education': universityEducation,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il salvataggio degli studi. Riprova più tardi.');
    }
    finally
    {
      _forgetPeople();
    }
  }

  int profileImageVersion = 0;

  // On the web one deadline (connect + receive) also covers sending the file.
  static const Duration _uploadTimeout = Duration(seconds: 60);

  Future<String> uploadProfileImage(List<int> bytes, String fileName) async
  {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    try
    {
      final response = await _dio.post(
        '/auth/profile-image',
        data: formData,
        options: Options(receiveTimeout: _uploadTimeout),
      );

      profileImageVersion++;

      return response.data['profile_image_url'];
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore durante il caricamento dell\'immagine.');
    }
    finally
    {
      _forgetPeople();
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
    finally
    {
      _forgetPeople();
    }
  }

  Future<List<SchoolItem>> getSchools({bool refresh = false})
  {
    return _schoolsMemo.read(() async
    {
      final response = await _dio.get('/schools/');

      return parseList(response.data, _schoolFromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<List<StudyProgramItem>> getStudyPrograms({bool refresh = false})
  {
    return _studyProgramsMemo.read(() async
    {
      final response = await _dio.get('/study-programs/');

      return parseList(response.data, _studyProgramFromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<List<MinistrySubjectItem>> getMinistrySubjects({bool refresh = false})
  {
    return _ministrySubjectsMemo.read(() async
    {
      final response = await _dio.get('/ministry-subjects/');

      return parseList(response.data, _ministrySubjectFromJson);
    }, refresh: refresh);
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
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
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<List<PersonItem>> getPeople({bool refresh = false})
  {
    return _peopleMemo.read(() async
    {
      final response = await _dio.get('/people/');
      return parseList(response.data, PersonItem.fromJson);
    }, refresh: refresh);
  }

  Future<List<PersonItem>> getTeachers({bool refresh = false})
  {
    return _teachersMemo.read(() async
    {
      final response = await _dio.get('/people/teachers');
      return parseList(response.data, PersonItem.fromJson);
    }, refresh: refresh);
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
        await _dio.post(
          '/people/$newTaxCode/image',
          data: formData,
          options: Options(receiveTimeout: _uploadTimeout),
        );
        profileImageVersion++;
      }

      return newTaxCode;
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore imprevisto durante l\'aggiornamento. Riprova più tardi.');
    }
    finally
    {
      _forgetPeople();
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

        await _dio.post(
          '/people/$taxCode/image',
          data: formData,
          options: Options(receiveTimeout: _uploadTimeout),
        );
        profileImageVersion++;
      }
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore imprevisto durante la creazione della persona. Riprova più tardi.');
    }
    finally
    {
      _forgetPeople();
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

  // Same payload as the enrolment form: the template reads the student block.
  Future<Uint8List> generateEarlyExitForm(Map<String, dynamic> payload) async
  {
    try
    {
      final response = await _dio.post<List<int>>(
        '/people/wizard/early-exit-form',
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

  Future<ApiFile> fetchRegulation() async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/documents/regulation',
        options: Options(responseType: ResponseType.bytes),
      );

      return (
        bytes: Uint8List.fromList(response.data!),
        fileName: fileNameOf(response.headers.value('content-disposition')) ?? 'Regolamento.pdf',
      );
    }
    on DioException catch (e)
    {
      _refusedBytes(e, 'Errore imprevisto durante il recupero del regolamento. Riprova più tardi.');
    }
  }

  Future<Uint8List> fetchEarlyExitForm(String fiscalCode) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/people/$fiscalCode/early-exit-form',
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
    finally
    {
      _forgetPeople();
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
    finally
    {
      _forgetPeople();
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

    _forgetPeople();
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
    finally
    {
      _forgetPeople();
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
    finally
    {
      _forgetPeople();
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
    finally
    {
      _forgetPeople();
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
    finally
    {
      _forgetPeople();
    }
  }

  // Replaces the whole list.
  Future<void> updateNotPreferredTeachers(
    String taxCode,
    List<String> teacherTaxCodes,
    DateTime? expectedUpdatedAt,
  ) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/not-preferred-teachers',
        data: {
          'teacher_tax_codes': teacherTaxCodes,
          if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, 'Errore imprevisto. Riprova più tardi.');
    }
    finally
    {
      _forgetPeople();
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

  Future<TeacherAppreciationStatisticsItem> getTeacherAppreciationStatistics(String taxCode, {int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/$taxCode/appreciation-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return TeacherAppreciationStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare il gradimento del docente. Riprova più tardi.');
    }
  }

  Future<TeacherAppreciationStudentsItem> getTeacherAppreciationStudents(String taxCode, {int? months, int? year, int? month}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/$taxCode/appreciation-students',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
        },
      );
      return TeacherAppreciationStudentsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, 'Impossibile recuperare gli studenti. Riprova più tardi.');
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

  // Separate from the presence statistics: the discipline is chosen after the page has loaded.
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

    tellOtherTabs({'news': _TabNews.bandReleased});
  }

  // The caller's own month; gated on role server-side.
  Future<TeacherMonthSummaryItem> getTeacherMonth() async
  {
    final response = await _dio.get('/home/teacher-month');

    return TeacherMonthSummaryItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StudentMonthSummaryItem> getStudentMonth() async
  {
    final response = await _dio.get('/home/student-month');

    return StudentMonthSummaryItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ParentMonthSummaryItem> getParentMonth() async
  {
    final response = await _dio.get('/home/parent-month');

    return ParentMonthSummaryItem.fromJson(response.data as Map<String, dynamic>);
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
