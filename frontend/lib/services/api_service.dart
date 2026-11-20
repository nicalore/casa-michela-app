import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show AppLifecycleListener, TimeOfDay;

import '../core/config/api_config.dart';
import '../core/language/app_language.dart';
import '../core/theme/theme_choice.dart';
import '../core/theme/theme_colours.dart';
import '../core/utils/alphabetical_order.dart';
import '../core/utils/content_disposition.dart';
import '../core/utils/error_message.dart';
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
import '../features/association/models/standard_tariffs_item.dart';
import '../features/association/models/study_program_item.dart';
import '../features/association/models/weekly_template_item.dart';
import '../features/association/notices/notice_item.dart';
import '../features/auth/models/login_response.dart';
import '../features/auth/models/me_response.dart';
import '../features/home/models/month_summary_items.dart';
import '../features/lessons/models/activity_item.dart';
import '../features/lessons/models/availability_item.dart';
import '../features/lessons/models/calendar_lock_item.dart';
import '../features/lessons/models/calendar_publication_item.dart';
import '../features/lessons/models/calendar_teacher_note_item.dart';
import '../features/lessons/models/lesson_item.dart';
import '../features/lessons/models/presence_item.dart';
import '../features/lessons/models/room_supervision_item.dart';
import '../features/lessons/models/teacher_room_assignment_item.dart';
import '../features/notifications/notification_item.dart';
import '../features/people/models/age_distribution_item.dart';
import '../features/people/models/certification_distribution_item.dart';
import '../features/people/models/city_distribution_item.dart';
import '../features/people/models/booking_history_items.dart';
import '../features/people/models/compensation_items.dart';
import '../features/accounting/models/accounting_stats_items.dart';
import '../features/accounting/models/opening_items.dart';
import '../features/accounting/models/student_hours_items.dart';
import '../features/accounting/models/payments_month_items.dart';
import '../features/accounting/models/student_month_items.dart';
import '../features/accounting/models/to_settle_items.dart';
import '../features/accounting/models/teacher_hours_items.dart';
import '../features/accounting/models/teacher_month_items.dart';
import '../features/people/models/course_distribution_item.dart';
import '../features/people/models/current_totals_item.dart';
import '../features/people/models/daily_trend_items.dart';
import '../features/people/models/education_distribution_item.dart';
import '../features/people/models/member_trend_item.dart';
import '../features/people/models/person_account_item.dart';
import '../features/people/models/person_item.dart';
import '../features/people/models/retention_rate_item.dart';
import '../features/people/models/personal_statistics_items.dart';
import '../features/people/models/student_note_item.dart';
import '../features/people/models/student_payments_item.dart';
import '../features/people/models/student_presence_statistics_item.dart';
import '../features/people/models/teacher_appreciation_item.dart';
import '../features/people/models/teacher_availability_statistics_item.dart';
import '../features/people/models/teacher_subjects_statistics_item.dart';
import '../features/reports/report_item.dart';
import '../features/settings/models/session_item.dart';
import '../features/updates/update_item.dart';
import 'auth_state.dart';
import 'browser_tabs.dart';
import 'client_device_key.dart';
import 'client_form_factor.dart';
import 'session_service.dart';

List<AssociationSubjectOption> _associationSubjectOptions(dynamic value)
{
  return value == null
      ? []
      : ((value as List)
          .map((a) => AssociationSubjectOption.fromJson(a as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => compareAlphabetically(a.name, b.name)));
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
          ..sort((a, b) => compareAlphabetically(a.name, b.name)))
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
          ..sort((a, b) => compareAlphabetically(a.name, b.name)))
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

// Per endpoint: concurrent reads share the request; any write drops it. Callers get copies.
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
  static const String _deviceKeyHeader = 'X-Client-Device';
  static const String _activeRoleHeader = 'X-Active-Role';

  // Long enough for a phone to settle on its new network after a switch.
  static const Duration _resendPause = Duration(seconds: 1);

  // Browsers ignore a page-set User-Agent; native apps replace the useless "Dart/x.y".
  static final String? _appUserAgent =
      kIsWeb ? null : 'CasaMichela/app (${defaultTargetPlatform.name.toLowerCase()})';

  // Resolved on first use: a native view has no size before its first frame.
  String? _formFactor;

  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.loading);

  // The router's synchronous redirect needs the active role: the identity lives in a notifier.
  final ValueNotifier<MeResponse?> identity = ValueNotifier(null);

  // Why the identity of a kept session could not be read; null once it is.
  final ValueNotifier<Object?> identityFailure = ValueNotifier(null);

  // The role worn before the identity arrives: read from storage at start.
  String? _wornRole;

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

  DateTime? _identityRecheckedAt;
  static const Duration _identityRecheckPause = Duration(seconds: 5);

  // Band locks are per account: bumped when another tab releases one, so an editing tab retakes it.
  final ValueNotifier<int> calendarLocksReleasedElsewhere = ValueNotifier(0);

  static const String _sessionLock = 'casa-michela-session';

  // Mirrored by backend/app/api/auth.py.
  static const String _passwordChangeExpiredCode = 'PASSWORD_CHANGE_EXPIRED';

  static String get _passwordChangeExpiredNotice => tr(
    'Per scegliere la nuova password, accedi di nuovo con quella provvisoria.',
    'To choose your new password, sign in again with the temporary one.',
  );

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

  // After a write: other tabs drop their copies too.
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

          // The role this app is showing: the server's stored one follows a switch on any device.
          if (identity.value?.activeRole ?? _wornRole case final String role)
          {
            options.headers[_activeRoleHeader] = role;
          }

          return handler.next(options);
        },
        onError: (error, handler) async
        {
          final RequestOptions request = error.requestOptions;

          // Unanswered GETs (idempotent) are resent once, hiding a phone's network blip.
          if (request.method == 'GET' &&
              error.type == DioExceptionType.connectionError &&
              request.extra['resent'] != true)
          {
            request.extra['resent'] = true;
            await Future<void>.delayed(_resendPause);

            try
            {
              return handler.resolve(await _dio.fetch(request));
            }
            on DioException catch (resendError)
            {
              return handler.next(resendError);
            }
          }

          if (error.response?.statusCode == 403 && !request.path.startsWith('/auth/'))
          {
            unawaited(_recheckIdentity());
          }

          if (error.response?.statusCode != 401 ||
              _refreshToken == null ||
              request.extra['retried'] == true)
          {
            return handler.next(error);
          }

          // Refresh only if the 401 came on the current token; an older one just retries.
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
    identity.addListener(_rememberRole);
  }

  // Kept per device, so a start or a return to the app opens where this device left off.
  void _rememberRole()
  {
    final String? role = identity.value?.activeRole;

    if (role == null || role == _wornRole)
    {
      return;
    }

    _wornRole = role;
    unawaited(SessionService.saveRole(role));
  }

  // Login and refresh name the device for the sessions list; every request names the language for the server's texts.
  void _describeClient(RequestOptions options)
  {
    options.headers['Accept-Language'] = AppLanguages.current.value.key;

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

    final String? deviceKey = ClientDeviceKey.value;

    if (deviceKey != null)
    {
      options.headers[_deviceKeyHeader] = deviceKey;
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

  // Tabs share one session and renew in turn, adopting a pair another tab already renewed.
  // Tokens only: awaiting /auth/me here would deadlock a renewal it triggered.
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
          if (_passwordChangeExpired(error))
          {
            _signInNotice = _passwordChangeExpiredNotice;
          }

          await SessionService.clearIfHolding(spent);
          tellOtherTabs({'news': _TabNews.signedOut, 'session': _sessionOf(spent) ?? ''});
        }

        rethrow;
      }
    });
  }

  // A different stored pair for the same account is newer: renewals take turns and store first.
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

  // Pre-session tokens carry no sid: the account stands in.
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

  // The short session opened for a forced password change expired.
  static bool _passwordChangeExpired(Object error)
  {
    if (error is! DioException || error.response?.statusCode != 401)
    {
      return false;
    }

    final data = error.response?.data;

    return data is Map && data['detail'] == _passwordChangeExpiredCode;
  }

  Never _refused(DioException error, String fallback)
  {
    if (error.response == null)
    {
      throw const ServerUnreachable();
    }

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

  // Identity before announcing, if the server answers: the router reads the role synchronously.
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
        // Refused until the forced password change, like a login.
        if (_passwordResetRequired(e))
        {
          authState.value = AuthState.passwordChangeRequired;

          return;
        }

        // Only a refusal ends the session; no answer keeps the pair and retries the identity.
        if (_sessionRefused(e))
        {
          _leaveSession();

          return;
        }

        identityFailure.value = e;
        unawaited(_recoverIdentity());
      }
    }

    authState.value = AuthState.authenticated;
  }

  // Backoff until answered or refused; the identity moves the router off the placeholder home.
  Future<void> _recoverIdentity() async
  {
    for (var attempt = 0; identity.value == null && isAuthenticated; attempt++)
    {
      await Future<void>.delayed(Duration(seconds: 2 << (attempt < 4 ? attempt : 4)));

      try
      {
        await me();
      }
      catch (e)
      {
        if (!_heardOfIdentity(e))
        {
          return;
        }
      }
    }
  }

  // The placeholder home's retry: reads the identity now instead of at the next backoff.
  Future<void> retryIdentity() async
  {
    try
    {
      await me();
    }
    catch (e)
    {
      _heardOfIdentity(e);
    }
  }

  // False when the failure ended the wait for the identity (password change or session refused).
  bool _heardOfIdentity(Object error)
  {
    if (_passwordResetRequired(error))
    {
      authState.value = AuthState.passwordChangeRequired;

      return false;
    }

    if (_sessionRefused(error))
    {
      _leaveSession();

      return false;
    }

    identityFailure.value = error;

    return true;
  }

  // A refusal may mean a role was revoked: the identity is re-read; a burst of refusals asks once.
  Future<void> _recheckIdentity({bool now = false}) async
  {
    final DateTime at = DateTime.now();
    final DateTime? last = _identityRecheckedAt;

    if (identity.value == null || (!now && last != null && at.difference(last) < _identityRecheckPause))
    {
      return;
    }

    _identityRecheckedAt = at;

    try
    {
      await me();
    }
    catch (_)
    {
      // Session refusals are handled where the request failed.
    }
  }

  // Memory only: a refused pair already left storage; an unanswered one stays for the next start.
  void _leaveSession()
  {
    _forgetSession();
    _useDemoServer(false);
    unawaited(SessionService.saveDemo(false));
    authState.value = AuthState.unauthenticated;
  }

  void _useDemoServer(bool demo)
  {
    ApiConfig.demo = demo;
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _tokenDio.options.baseUrl = ApiConfig.baseUrl;
  }

  void _forgetSession()
  {
    _forgetAll();
    _accessToken = null;
    _refreshToken = null;
    _wornRole = null;
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

  // Back in front: a session ended from another device meanwhile goes to the login now.
  AppLifecycleListener? _resumes;

  Future<bool> restoreSession() async
  {
    await ClientDeviceKey.load();
    _resumes ??= AppLifecycleListener(onResume: () => unawaited(_recheckIdentity(now: true)));

    final StoredSession stored = await SessionService.read();

    _accessToken = stored.accessToken;
    _refreshToken = stored.refreshToken;

    if (_accessToken == null || _refreshToken == null)
    {
      authState.value = AuthState.unauthenticated;
      return false;
    }

    _useDemoServer(await SessionService.readDemo());
    _wornRole = await SessionService.readRole();

    try
    {
      // A token with time left skips the refresh: one round trip, not two.
      if (_secondsLeft(_accessToken!) <= 60)
      {
        await _renewTokens();
      }
    }
    catch (error)
    {
      // As the interceptor does: no answer keeps the pair for the next request.
      if (_sessionRefused(error))
      {
        _leaveSession();

        return false;
      }
    }

    await _announceAuthenticated();

    return isAuthenticated;
  }

  Future<LoginResponse> login({required String username, required String password}) async
  {
    _forgetAll();

    final bool demo = ApiConfig.isDemoUsername(username);

    _useDemoServer(demo);

    final LoginResponse loginResponse;

    try
    {
      final response = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      loginResponse = LoginResponse.fromJson(response.data);
    }
    catch (_)
    {
      // A refused demo sign-in must not send the next request to the demo server.
      _useDemoServer(false);
      rethrow;
    }

    await SessionService.saveDemo(demo);
    await _adoptSession(loginResponse);

    tellOtherTabs({'news': _TabNews.signedIn});

    return loginResponse;
  }

  // Runs before a sign-out, while the session still opens the API.
  Future<void> Function()? beforeSignOut;

  // In turn with renewals, so the server gets the pair another tab may have just renewed.
  Future<void> logout() async
  {
    try
    {
      await beforeSignOut?.call();
    }
    catch (_) {}

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
      _refused(e, tr('Impossibile caricare le sessioni.', "Couldn't load the sessions."));
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
      _refused(e, tr('Impossibile disattivare la sessione.', "Couldn't sign out the session."));
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
      _refused(e, tr('Impossibile disattivare le altre sessioni.', "Couldn't sign out the other sessions."));
    }
  }

  // No current password for the change forced right after the sign-in.
  Future<void> changePassword({String? currentPassword, required String newPassword}) async
  {
    // The body names the session to keep: the pair another tab renewed.
    await _catchUpWithOtherTabs();

    try
    {
      await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': ?currentPassword,
          'new_password': newPassword,
          'refresh_token': _refreshToken,
        },
      );

      await _announceAuthenticated();
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il cambio password. Riprova più tardi.',
          "Couldn't change the password. Please try again later.",
        ),
      );
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

      _refused(
        e,
        tr(
          'Errore durante la richiesta di recupero password. Riprova più tardi.',
          "Couldn't request password recovery. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la reimpostazione della password. Riprova più tardi.',
          "Couldn't reset the password. Please try again later.",
        ),
      );
    }
  }

  Future<void> validateResetToken({required String token}) async
  {
    try
    {
      // In the body, not the address: request lines end up in access logs.
      await _dio.post(
        '/auth/validate-reset-token',
        data: {'token': token},
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Token non valido o scaduto.', 'Invalid or expired token.'));
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

  // Both modes when [mode] is null.
  Future<List<OpeningDayItem>> getOpeningDays({required DateTime dateFrom, required DateTime dateTo, String? mode}) async
  {
    final response = await _dio.get(
      '/opening-days/',
      queryParameters: {
        'date_from': formatDateOnly(dateFrom),
        'date_to': formatDateOnly(dateTo),
        'mode': ?mode,
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
      _refused(
        e,
        tr(
          'Errore durante la creazione dell\'orario. Riprova più tardi.',
          "Couldn't create the hours. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica dell\'orario. Riprova più tardi.',
          "Couldn't change the hours. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione dell\'orario. Riprova più tardi.',
          "Couldn't delete the hours. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la creazione dell\'apertura. Riprova più tardi.',
          "Couldn't create the opening. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'aggiornamento dell\'apertura. Riprova più tardi.',
          "Couldn't update the opening. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante il salvataggio degli orari. Riprova più tardi.',
          "Couldn't save the hours. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione dell\'apertura. Riprova più tardi.',
          "Couldn't delete the opening. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante il ripristino dell\'orario standard. Riprova più tardi.',
          "Couldn't restore the standard hours. Please try again later.",
        ),
      );
    }
  }

  // Once a variation is saved or removed: one notice to everyone for all its days.
  Future<void> announceOpeningHours({required DateTime dateFrom, required DateTime dateTo}) async
  {
    await _dio.post('/opening-days/announce', data: {
      'date_from': formatDateOnly(dateFrom),
      'date_to': formatDateOnly(dateTo),
    });
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
      _refused(e, tr('Errore durante la creazione. Riprova più tardi.', "Couldn't create it. Please try again later."));
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
      _refused(e, tr('Errore durante la modifica.', "Couldn't save the changes."));
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
      _refused(e, tr('Errore durante l\'eliminazione.', "Couldn't delete it."));
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
      _refused(
        e,
        tr(
          'Impossibile inviare la segnalazione. Riprova più tardi.',
          "Couldn't send the report. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile inviare la segnalazione. Riprova più tardi.',
          "Couldn't send the report. Please try again later.",
        ),
      );
    }
  }

  // Newest first, the unresolved ones of the kinds the caller receives.
  Future<List<ReportItem>> getReports() async
  {
    try
    {
      final response = await _dio.get('/reports');

      return parseList(response.data, ReportItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare le segnalazioni.', "Couldn't load the reports."));
    }
  }

  // Opening one reads it, for the caller alone.
  Future<ReportItem> openReport(int id) async
  {
    try
    {
      final response = await _dio.get('/reports/$id');

      return ReportItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _throwIfResolved(e);
      _refused(e, tr('Impossibile aprire la segnalazione.', "Couldn't open the report."));
    }
  }

  Future<void> resolveReport(int id) async
  {
    try
    {
      await _dio.put('/reports/$id/resolve');
    }
    on DioException catch (e)
    {
      _throwIfResolved(e);
      _refused(e, tr('Impossibile segnare la segnalazione come risolta.', "Couldn't mark the report as resolved."));
    }
  }

  void _throwIfResolved(DioException error)
  {
    final Object? detail = error.response?.data is Map ? error.response?.data['detail'] : null;

    if (error.response?.statusCode == 409 && detail is String)
    {
      throw ReportAlreadyResolved(detail);
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
      _refused(e, tr('Errore durante la creazione della richiesta.', "Couldn't create the request."));
    }
  }

  // The day's hours and subjects in the given modes, as they are to be; done in one go.
  Future<List<PresenceItem>> replaceLessonRequest({
    required String studentTaxCode,
    required DateTime date,
    required List<Map<String, dynamic>> modes,
  }) async
  {
    try
    {
      final response = await _dio.put(
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
      _refused(e, tr("Errore durante l'aggiornamento della richiesta.", "Couldn't update the request."));
    }
  }

  // A band's note on its own; the day's presences come back. Null or blank clears it.
  Future<List<PresenceItem>> writeBandNotes({
    required String studentTaxCode,
    required DateTime date,
    required TimeBucket band,
    required String? notes,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/lesson-requests/notes',
        data: {
          'student_tax_code': studentTaxCode,
          'date': formatDateOnly(date),
          'band': LessonItem.formatBand(band),
          'notes': notes,
        },
      );

      return parseList(response.data, PresenceItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr("Errore durante l'aggiornamento della richiesta.", "Couldn't update the request."));
    }
  }

  // A move: the days it touches, each as it is to be, in one transaction.
  Future<List<PresenceItem>> replaceLessonRequestDays({
    required String studentTaxCode,
    required List<Map<String, dynamic>> days,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/lesson-requests/days',
        data: {
          'student_tax_code': studentTaxCode,
          'days': days,
        },
      );

      return parseList(response.data, PresenceItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr("Errore durante l'aggiornamento della richiesta.", "Couldn't update the request."));
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
      _refused(e, tr('Errore durante la creazione. Riprova più tardi.', "Couldn't create it. Please try again later."));
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
      _refused(e, tr('Errore durante la modifica.', "Couldn't save the changes."));
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
      _refused(e, tr('Errore durante l\'eliminazione.', "Couldn't delete it."));
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
      _refused(e, tr('Errore durante la creazione. Riprova più tardi.', "Couldn't create it. Please try again later."));
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
      _refused(e, tr('Errore durante la modifica.', "Couldn't save the changes."));
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
      _refused(e, tr('Errore durante l\'eliminazione.', "Couldn't delete it."));
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
      _refused(
        e,
        tr(
          'Errore durante la creazione della stanza. Riprova più tardi.',
          "Couldn't create the room. Please try again later.",
        ),
      );
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
      _refused(e, tr('Errore durante la modifica della stanza.', "Couldn't change the room."));
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
      _refused(e, tr('Errore durante l\'eliminazione della stanza.', "Couldn't delete the room."));
    }
    finally
    {
      _forgetCatalogues();
    }
  }

  Future<List<NoticeSummaryItem>> getNotices() async
  {
    try
    {
      final response = await _dio.get('/notices/');

      return parseList(response.data, NoticeSummaryItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare le comunicazioni.', "Couldn't load the announcements."));
    }
  }

  // The role is the home's: each home lists only what was sent to its role.
  Future<List<NoticeHeadlineItem>> getHomeNotices(String role) async
  {
    try
    {
      final response = await _dio.get('/notices/home', queryParameters: {'role': role});

      return parseList(response.data, NoticeHeadlineItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare le comunicazioni.', "Couldn't load the announcements."));
    }
  }

  // Everything sent to the role, for its own Associazione page.
  Future<List<NoticeSummaryItem>> getReceivedNotices(String role) async
  {
    try
    {
      final response = await _dio.get('/notices/received', queryParameters: {'role': role});

      return parseList(response.data, NoticeSummaryItem.fromReceivedJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare le comunicazioni.', "Couldn't load the announcements."));
    }
  }

  // The reader's copy, for anyone who did not write notices from Associazione.
  Future<NoticeItem> readNotice(int id) async
  {
    try
    {
      final response = await _dio.get('/notices/$id');

      return NoticeItem.fromReadingJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare la comunicazione.', "Couldn't load the announcement."));
    }
  }

  Future<NoticeItem> getNotice(int id) async
  {
    try
    {
      final response = await _dio.get('/notices/$id');

      return NoticeItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare la comunicazione.', "Couldn't load the announcement."));
    }
  }

  Future<NoticeRecipientCount> countNoticeRecipients(List<NoticeRole> recipients) async
  {
    try
    {
      final response = await _dio.get(
        '/notices/recipients',
        queryParameters: {'recipients': [for (final role in recipients) role.code]},
        options: Options(listFormat: ListFormat.multi),
      );

      return (people: response.data['people'] as int, emails: response.data['emails'] as int);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile contare i destinatari.', "Couldn't count the recipients."));
    }
  }

  MultipartFile _multipart(NoticeUpload upload, {required String fileName})
  {
    final String? mimeType = upload.mimeType;

    return MultipartFile.fromBytes(
      upload.bytes,
      filename: fileName,
      contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
    );
  }

  // Repeated keys without brackets: the server reads a form list that way.
  FormData _noticeForm(NoticeDraft draft, {DateTime? expectedUpdatedAt})
  {
    return FormData()
      ..fields.addAll([
        MapEntry('title', draft.title),
        MapEntry('message', draft.message),
        for (final role in draft.recipients) MapEntry('recipients', role.code),
        for (final id in draft.keptAttachmentIds) MapEntry('kept_attachment_ids', '$id'),
        if (expectedUpdatedAt != null) MapEntry('expected_updated_at', expectedUpdatedAt.toUtc().toIso8601String()),
      ])
      ..files.addAll([
        for (final entry in draft.images.entries)
          MapEntry('images', _multipart(entry.value, fileName: entry.key)),
        for (final file in draft.attachments)
          MapEntry('attachments', _multipart(file, fileName: file.fileName)),
      ]);
  }

  Future<NoticeItem> createNotice(NoticeDraft draft) async
  {
    try
    {
      final response = await _dio.post(
        '/notices/',
        data: _noticeForm(draft),
        options: Options(receiveTimeout: _uploadTimeout),
      );

      return NoticeItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante l\'invio della comunicazione. Riprova più tardi.',
          "Couldn't send the announcement. Please try again later.",
        ),
      );
    }
  }

  Future<NoticeItem> updateNotice(NoticeItem notice, NoticeDraft draft) async
  {
    try
    {
      final response = await _dio.put(
        '/notices/${notice.id}',
        data: _noticeForm(draft, expectedUpdatedAt: notice.updatedAt),
        options: Options(receiveTimeout: _uploadTimeout),
      );

      return NoticeItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la modifica della comunicazione. Riprova più tardi.',
          "Couldn't change the announcement. Please try again later.",
        ),
      );
    }
  }

  // A null day pins it until someone unpins it.
  Future<NoticeSummaryItem> pinNotice(int id, DateTime? until) async
  {
    try
    {
      final response = await _dio.put(
        '/notices/$id/pin',
        data: {'until': until == null ? null : formatDateOnly(until)},
      );

      return NoticeSummaryItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile fissare la comunicazione.', "Couldn't pin the announcement."));
    }
  }

  Future<void> unpinNotice(int id) async
  {
    try
    {
      await _dio.delete('/notices/$id/pin');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile togliere la comunicazione dalla cima.', "Couldn't unpin the announcement."));
    }
  }

  Future<void> deleteNotice(int id) async
  {
    try
    {
      await _dio.delete('/notices/$id');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore durante l\'eliminazione della comunicazione.', "Couldn't delete the announcement."));
    }
  }

  Future<ApiFile> fetchNoticeAttachment(int noticeId, NoticeAttachmentItem attachment) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/notices/$noticeId/attachments/${attachment.id}',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: _uploadTimeout),
      );

      return (bytes: Uint8List.fromList(response.data!), fileName: attachment.fileName);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, tr('Impossibile scaricare l\'allegato.', "Couldn't download the attachment."));
    }
  }

  Future<Uint8List> fetchNoticeImage(int noticeId, String key) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/notices/$noticeId/images/$key',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: _uploadTimeout),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, tr('Impossibile caricare l\'immagine.', "Couldn't load the image."));
    }
  }

  Future<List<UpdateSummaryItem>> getUpdates() async
  {
    try
    {
      final response = await _dio.get('/app-updates/');

      return parseList(response.data, UpdateSummaryItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare gli aggiornamenti.', "Couldn't load the updates."));
    }
  }

  Future<UpdateItem> getUpdate(int id) async
  {
    try
    {
      final response = await _dio.get('/app-updates/$id');

      return UpdateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare l\'aggiornamento.', "Couldn't load the update."));
    }
  }

  // People who can sign in holding one of the roles.
  Future<int> countUpdateRecipients(List<UpdateRole> recipients) async
  {
    try
    {
      final response = await _dio.get(
        '/app-updates/recipients',
        queryParameters: {'recipients': [for (final role in recipients) role.code]},
        options: Options(listFormat: ListFormat.multi),
      );

      return response.data['people'] as int;
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile contare i destinatari.', "Couldn't count the recipients."));
    }
  }

  // Repeated keys without brackets: the server reads a form list that way.
  FormData _updateForm(UpdateDraft draft, {String? version, DateTime? expectedUpdatedAt})
  {
    return FormData()
      ..fields.addAll([
        MapEntry('title', draft.title),
        MapEntry('message', draft.message),
        for (final role in draft.recipients) MapEntry('recipients', role.code),
        if (version != null) MapEntry('version', version),
        if (expectedUpdatedAt != null) MapEntry('expected_updated_at', expectedUpdatedAt.toUtc().toIso8601String()),
      ])
      ..files.addAll([
        for (final entry in draft.images.entries)
          MapEntry('images', _multipart(entry.value, fileName: entry.key)),
      ]);
  }

  Future<UpdateItem> createUpdate(UpdateDraft draft, {required String version}) async
  {
    try
    {
      final response = await _dio.post(
        '/app-updates/',
        data: _updateForm(draft, version: version),
        options: Options(receiveTimeout: _uploadTimeout),
      );

      return UpdateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la pubblicazione dell\'aggiornamento. Riprova più tardi.',
          "Couldn't publish the update. Please try again later.",
        ),
      );
    }
  }

  Future<UpdateItem> editUpdate(UpdateItem update, UpdateDraft draft) async
  {
    try
    {
      final response = await _dio.put(
        '/app-updates/${update.id}',
        data: _updateForm(draft, expectedUpdatedAt: update.updatedAt),
        options: Options(receiveTimeout: _uploadTimeout),
      );

      return UpdateItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la modifica dell\'aggiornamento. Riprova più tardi.',
          "Couldn't change the update. Please try again later.",
        ),
      );
    }
  }

  Future<void> deleteUpdate(int id) async
  {
    try
    {
      await _dio.delete('/app-updates/$id');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore durante l\'eliminazione dell\'aggiornamento.', "Couldn't delete the update."));
    }
  }

  // Everyone accepts the legal documents again at their next access.
  Future<void> requestTermsAcceptance() async
  {
    try
    {
      await _dio.post('/app-updates/terms-requests');
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Non è stato possibile richiedere la nuova accettazione. Riprova più tardi.',
          "Couldn't ask for the new acceptance. Please try again later.",
        ),
      );
    }
  }

  // Newest first, what the caller has still to read among those up to its version.
  Future<List<UpdateReadingItem>> getUnreadUpdates({required String version}) async
  {
    try
    {
      final response = await _dio.get('/app-updates/unread', queryParameters: {'version': version});

      return parseList(response.data, UpdateReadingItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare gli aggiornamenti.', "Couldn't load the updates."));
    }
  }

  Future<void> markUpdatesSeen(List<int> ids) async
  {
    try
    {
      await _dio.put('/app-updates/seen', data: {'ids': ids});
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile segnare gli aggiornamenti come letti.', "Couldn't mark the updates as read."));
    }
  }

  Future<Uint8List> fetchUpdateImage(int updateId, String key) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/app-updates/$updateId/images/$key',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: _uploadTimeout),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, tr('Impossibile caricare l\'immagine.', "Couldn't load the image."));
    }
  }

  Future<List<TeacherRoomAssignmentItem>> getTeacherRoomAssignments(DateTime day) async
  {
    final response = await _dio.get(
      '/teacher-room-assignments/',
      queryParameters: {'day': formatDateOnly(day)},
    );

    return parseList(response.data, TeacherRoomAssignmentItem.fromJson);
  }

  // Replaces the listed teachers' rooms and shifts in one go; the first room runs from midnight.
  Future<void> saveRoomPlan({
    required DateTime day,
    required Map<String, List<({int roomId, TimeOfDay startTime})>> rooms,
    required List<({String teacherTaxCode, int roomId, TimeOfDay startTime, TimeOfDay endTime})> shifts,
  }) async
  {
    try
    {
      await _dio.put(
        '/teacher-room-assignments/${formatDateOnly(day)}',
        data: {
          'teachers': [
            for (final MapEntry(key: teacherTaxCode, value: stretches) in rooms.entries)
              {
                'teacher_tax_code': teacherTaxCode,
                'stretches': [
                  for (final stretch in stretches)
                    {'room_id': stretch.roomId, 'start_time': formatTimeOfDay(stretch.startTime)},
                ],
              },
          ],
          'supervisions': [
            for (final shift in shifts)
              {
                'teacher_tax_code': shift.teacherTaxCode,
                'room_id': shift.roomId,
                'start_time': formatTimeOfDay(shift.startTime),
                'end_time': formatTimeOfDay(shift.endTime),
              },
          ],
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore durante il salvataggio delle stanze.', "Couldn't save the rooms."));
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

  MeResponse? get lastKnownIdentity => identity.value;

  // Read off the token: known even while /auth/me is refused pending the password change.
  String? get signedInTaxCode
  {
    final String? token = _accessToken;

    return token == null ? null : _accountOf(token);
  }

  String? _signInNotice;

  // Read once, by the sign-in page that opens after the session ended.
  String? takeSignInNotice()
  {
    final String? notice = _signInNotice;
    _signInNotice = null;

    return notice;
  }

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
    identityFailure.value = null;

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
      _refused(
        e,
        tr(
          'Errore durante il completamento del primo accesso. Riprova più tardi.',
          "Couldn't complete the first sign-in. Please try again later.",
        ),
      );
    }
  }

  Future<MeResponse> acceptTerms() async
  {
    try
    {
      final response = await _dio.post('/auth/accept-terms');
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Non è stato possibile registrare l'accettazione. Riprova più tardi.",
          "Couldn't record the acceptance. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante il cambio di ruolo. Riprova più tardi.',
          "Couldn't switch role. Please try again later.",
        ),
      );
    }
  }

  Future<MeResponse> setColourTheme(ColourTheme theme) async
  {
    try
    {
      final response = await _dio.put('/auth/colour-theme', data: {'colour_theme': theme.key});
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il cambio dei colori. Riprova più tardi.',
          "Couldn't change the colours. Please try again later.",
        ),
      );
    }
  }

  Future<MeResponse> setLanguage(AppLanguage language) async
  {
    try
    {
      final response = await _dio.put('/auth/language', data: {'language': language.key});
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il cambio della lingua. Riprova più tardi.',
          "Couldn't change the language. Please try again later.",
        ),
      );
    }
  }

  Future<MeResponse> setThemeMode(ThemeChoice mode) async
  {
    try
    {
      final response = await _dio.put('/auth/theme-mode', data: {'theme_mode': mode.key});
      final me = MeResponse.fromJson(Map<String, dynamic>.from(response.data));

      identity.value = me;

      return me;
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il cambio del tema. Riprova più tardi.',
          "Couldn't change the theme. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante il salvataggio dei contatti. Riprova più tardi.',
          "Couldn't save the contacts. Please try again later.",
        ),
      );
    }
    finally
    {
      _forgetPeople();
    }
  }

  Future<CompensationMonth> getCompensation(String taxCode, DateTime month) async
  {
    final response = await _dio.get(
      '/people/$taxCode/compensation',
      queryParameters: {'year': month.year, 'month': month.month},
    );

    return CompensationMonth.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StudentPaymentsItem> getStudentPayments(String taxCode) async
  {
    final response = await _dio.get('/people/$taxCode/payments');

    return StudentPaymentsItem.fromJson(response.data as Map<String, dynamic>);
  }

  // Each write answers with the tab as it now stands.
  Future<StudentPaymentsItem> _postStudentPayments(String taxCode, String path, Map<String, dynamic> data) async
  {
    try
    {
      final response = await _dio.post('/people/$taxCode/payments/$path', data: data);

      return StudentPaymentsItem.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio del pagamento. Riprova più tardi.',
          "Couldn't save the payment. Please try again later.",
        ),
      );
    }
  }

  Future<StudentPaymentsItem> _deleteStudentPayments(String taxCode, String path) async
  {
    try
    {
      final response = await _dio.delete('/people/$taxCode/payments/$path');

      return StudentPaymentsItem.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la revoca del pagamento. Riprova più tardi.',
          "Couldn't revoke the payment. Please try again later.",
        ),
      );
    }
  }

  // The package or month running, bought again: renewing is paying.
  Future<StudentPaymentsItem> renewStudentTariff({
    required String taxCode,
    required int amountCents,
    int? packageHours,
    required Map<String, dynamic> payment,
  })
  {
    return _postStudentPayments(taxCode, 'renewal', {
      'amount_cents': amountCents,
      'package_hours': packageHours,
      'payment': payment,
    });
  }

  Future<StudentPaymentsItem> changeStudentTariff({
    required String taxCode,
    required String kind,
    required int amountCents,
    int? packageHours,
    DateTime? startsOn,
    bool nextMonth = false,
    Map<String, dynamic>? payment,
  })
  {
    return _postStudentPayments(taxCode, 'tariff', {
      'kind': kind,
      'amount_cents': amountCents,
      'package_hours': packageHours,
      'starts_on': startsOn == null ? null : formatDateOnly(startsOn),
      'next_month': nextMonth,
      'payment': payment,
    });
  }

  // A whole line of hours, paid by the hour.
  Future<StudentPaymentsItem> settleStudentHours({
    required String taxCode,
    required String hoursKind,
    required int centsPerHour,
    required Map<String, dynamic> payment,
    required int expectedMinutes,
  })
  {
    // The minutes shown go along: the server refuses if the line grew meanwhile.
    return _postStudentPayments(taxCode, 'settlement', {
      'hours_kind': hoursKind,
      'cents_per_hour': centsPerHour,
      'payment': payment,
      'expected_minutes': expectedMinutes,
    });
  }

  // An annual fee owed, paid now: the body is the payment itself.
  Future<StudentPaymentsItem> settleMembershipFee({
    required String taxCode,
    required int feeId,
    required Map<String, dynamic> payment,
  })
  {
    return _postStudentPayments(taxCode, 'fees/$feeId/settlement', payment);
  }

  // The hours it covered or settled are to settle again.
  Future<StudentPaymentsItem> cancelStudentPayment({required String taxCode, required int paymentId})
  {
    return _deleteStudentPayments(taxCode, '$paymentId');
  }

  // The fee is owed again.
  Future<StudentPaymentsItem> cancelMembershipFeePayment({required String taxCode, required int feeId})
  {
    return _deleteStudentPayments(taxCode, 'fees/$feeId/settlement');
  }

  // Hourly tariff only: lessons draw on them before anything is due.
  Future<StudentPaymentsItem> payStudentHoursAhead({
    required String taxCode,
    required int minutes,
    required int centsPerHour,
    required Map<String, dynamic> payment,
  })
  {
    return _postStudentPayments(taxCode, 'ahead', {
      'minutes': minutes,
      'cents_per_hour': centsPerHour,
      'payment': payment,
    });
  }

  Future<StandardTariffsItem> getStandardTariffs() async
  {
    final response = await _dio.get('/standard-tariffs/');

    return StandardTariffsItem.fromJson(response.data as Map<String, dynamic>);
  }

  // Each write answers with every level and the fees as they now stand.
  Future<StandardTariffsItem> _putStandardTariffs(String path, Map<String, dynamic> data) async
  {
    try
    {
      final response = await _dio.put('/standard-tariffs/$path', data: data);

      return StandardTariffsItem.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio delle tariffe. Riprova più tardi.',
          "Couldn't save the rates. Please try again later.",
        ),
      );
    }
  }

  Future<StandardTariffsItem> updateStandardTariff(StandardTariffItem tariff)
  {
    return _putStandardTariffs('levels/${tariff.level}', tariff.toJson());
  }

  Future<StandardTariffsItem> updateAnnualFees(AnnualFeesItem fees)
  {
    return _putStandardTariffs('fees', fees.toJson());
  }

  // By their first day.
  Future<Set<DateTime>> getCompensationMonths(String taxCode) async
  {
    final response = await _dio.get('/people/$taxCode/compensation/months');

    return {for (final month in response.data as List<dynamic>) DateTime.parse(month as String)};
  }

  Future<BookingHistoryMonth> getBookingHistory(String taxCode, DateTime month) async
  {
    final response = await _dio.get(
      '/people/$taxCode/bookings-history',
      queryParameters: {'year': month.year, 'month': month.month},
    );

    return BookingHistoryMonth.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Set<DateTime>> getBookingHistoryMonths(String taxCode) async
  {
    final response = await _dio.get('/people/$taxCode/bookings-history/months');

    return {for (final month in response.data as List<dynamic>) DateTime.parse(month as String)};
  }

  // Null removes it.
  Future<void> updateIban(String taxCode, String? iban) async
  {
    try
    {
      await _dio.put('/people/$taxCode/compensation/iban', data: {'iban': iban});
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio dell\'IBAN. Riprova più tardi.',
          "Couldn't save the IBAN. Please try again later.",
        ),
      );
    }
  }

  // Holds from that month until the next change.
  Future<void> updateCompensation({
    required String taxCode,
    required DateTime month,
    required String collaborationType,
    required String? grossCompensation,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/compensation',
        data: {
          'year': month.year,
          'month': month.month,
          'collaboration_type': collaborationType,
          'gross_compensation': grossCompensation,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio del compenso. Riprova più tardi.',
          "Couldn't save the pay. Please try again later.",
        ),
      );
    }
  }

  // The teacher's rule for the unpaid hour from [month] until their next change.
  Future<void> updateVolunteeringRule({
    required String taxCode,
    required DateTime month,
    required VolunteeringRule rule,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/compensation/volunteering',
        data: {'year': month.year, 'month': month.month, 'rule': rule.name},
      );
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio del volontariato. Riprova più tardi.',
          "Couldn't save the volunteering. Please try again later.",
        ),
      );
    }
  }

  // The daily summary of teachers' hours for one band.
  Future<TeacherHoursBand> getTeacherHours(DateTime day, TimeBucket band) async
  {
    final response = await _dio.get(_teacherHoursPath(day, band));

    return TeacherHoursBand.fromJson(response.data as Map<String, dynamic>);
  }

  String _teacherHoursPath(DateTime day, TimeBucket band) => '/accounting/teacher-hours/${apiDate(day)}/${apiBand(band)}';

  // Each write answers with the band as it now stands.
  Future<TeacherHoursBand> _teacherHoursWrite(Future<Response<dynamic>> Function() call) async
  {
    try
    {
      final response = await call();

      return TeacherHoursBand.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio delle ore. Riprova più tardi.',
          "Couldn't save the hours. Please try again later.",
        ),
      );
    }
  }

  // Only what is passed changes; a null volunteer with setVolunteer means none at all.
  Future<TeacherHoursBand> updateTeacherHours(
    DateTime day,
    TimeBucket band,
    String taxCode, {
    List<HoursSpan>? work,
    bool setVolunteer = false,
    HoursSpan? volunteer,
    bool? absent,
  })
  {
    return _teacherHoursWrite(
      () => _dio.put(
        '${_teacherHoursPath(day, band)}/$taxCode',
        data: {
          'work': ?work?.map((span) => span.toJson()).toList(),
          if (setVolunteer) 'volunteer': volunteer?.toJson(),
          'absent': ?absent,
        },
      ),
    );
  }

  Future<TeacherHoursBand> addTeacherHours(
    DateTime day,
    TimeBucket band, {
    required String taxCode,
    required String mode,
    required List<HoursSpan> work,
    bool setVolunteer = false,
    HoursSpan? volunteer,
  })
  {
    return _teacherHoursWrite(
      () => _dio.post(
        _teacherHoursPath(day, band),
        data: {
          'tax_code': taxCode,
          'mode': mode,
          'work': work.map((span) => span.toJson()).toList(),
          if (setVolunteer) 'volunteer': volunteer?.toJson(),
        },
      ),
    );
  }

  // Back to the calendar; a row added by hand leaves the summary.
  Future<TeacherHoursBand> dropTeacherHours(DateTime day, TimeBucket band, String taxCode)
  {
    return _teacherHoursWrite(() => _dio.delete('${_teacherHoursPath(day, band)}/$taxCode'));
  }

  Future<TeacherHoursBand> confirmTeacherHours(DateTime day, TimeBucket band)
  {
    return _teacherHoursWrite(() => _dio.post('${_teacherHoursPath(day, band)}/confirm'));
  }

  Future<TeacherHoursBand> reopenTeacherHours(DateTime day, TimeBucket band)
  {
    return _teacherHoursWrite(() => _dio.post('${_teacherHoursPath(day, band)}/reopen'));
  }

  // The daily summary of pupils' hours for one band.
  Future<StudentHoursBand> getStudentHours(DateTime day, TimeBucket band) async
  {
    final response = await _dio.get(_studentHoursPath(day, band));

    return StudentHoursBand.fromJson(response.data as Map<String, dynamic>);
  }

  String _studentHoursPath(DateTime day, TimeBucket band) => '/accounting/student-hours/${apiDate(day)}/${apiBand(band)}';

  // Each write answers with the band as it now stands.
  Future<StudentHoursBand> _studentHoursWrite(Future<Response<dynamic>> Function() call) async
  {
    try
    {
      final response = await call();

      return StudentHoursBand.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio delle ore. Riprova più tardi.',
          "Couldn't save the hours. Please try again later.",
        ),
      );
    }
  }

  // Only what is passed changes.
  Future<StudentHoursBand> updateStudentHours(
    DateTime day,
    TimeBucket band,
    String taxCode, {
    List<HoursSpan>? work,
    bool? absent,
  })
  {
    return _studentHoursWrite(
      () => _dio.put(
        '${_studentHoursPath(day, band)}/$taxCode',
        data: {
          'work': ?work?.map((span) => span.toJson()).toList(),
          'absent': ?absent,
        },
      ),
    );
  }

  Future<StudentHoursBand> addStudentHours(
    DateTime day,
    TimeBucket band, {
    required String taxCode,
    required String mode,
    required List<HoursSpan> work,
  })
  {
    return _studentHoursWrite(
      () => _dio.post(
        _studentHoursPath(day, band),
        data: {
          'tax_code': taxCode,
          'mode': mode,
          'work': work.map((span) => span.toJson()).toList(),
        },
      ),
    );
  }

  // Back to the calendar; a row added by hand leaves the summary.
  Future<StudentHoursBand> dropStudentHours(DateTime day, TimeBucket band, String taxCode)
  {
    return _studentHoursWrite(() => _dio.delete('${_studentHoursPath(day, band)}/$taxCode'));
  }

  Future<StudentHoursBand> confirmStudentHours(DateTime day, TimeBucket band)
  {
    return _studentHoursWrite(() => _dio.post('${_studentHoursPath(day, band)}/confirm'));
  }

  Future<StudentHoursBand> reopenStudentHours(DateTime day, TimeBucket band)
  {
    return _studentHoursWrite(() => _dio.post('${_studentHoursPath(day, band)}/reopen'));
  }

  // The monthly summary of teachers: only confirmed bands count.
  Future<TeacherMonth> getTeachersMonth(DateTime month) async
  {
    final response = await _dio.get(_teacherMonthPath(month));

    return TeacherMonth.fromJson(response.data as Map<String, dynamic>);
  }

  String _teacherMonthPath(DateTime month) => '/accounting/teacher-month/${month.year}/${month.month}';

  // The accounting statistics: the last months up to this one, or a calendar year.
  Future<AccountingStats> getAccountingStats({int? months, int? year}) async
  {
    final response = await _dio.get(
      '/accounting/statistics',
      queryParameters: {'months': ?months, 'year': ?year},
    );

    return AccountingStats.fromJson(response.data as Map<String, dynamic>);
  }

  // The pupils' month: read only, though a month seen over fixes where they stood.
  // Everything paid in the month by anyone, the oldest first.
  Future<PaymentsMonth> getPaymentsMonth(DateTime month) async
  {
    final response = await _dio.get('/accounting/payments/${month.year}/${month.month}');

    return PaymentsMonth.fromJson(response.data as Map<String, dynamic>);
  }

  // Whoever owes something today: hours to settle and annual fees.
  Future<ToSettle> getToSettle() async
  {
    final response = await _dio.get('/accounting/to-settle/');

    return ToSettle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccountingOpening> getAccountingOpening() async
  {
    final response = await _dio.get('/accounting/opening/');

    return AccountingOpening.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OpeningPupil> getOpeningPupil(String taxCode) async
  {
    final response = await _dio.get('/accounting/opening/pupils/$taxCode');

    return OpeningPupil.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OpeningTeacher> confirmOpeningTeacher(String taxCode, Map<String, dynamic> data) async
  {
    final response = await _dio.put('/accounting/opening/teachers/$taxCode', data: data);

    return OpeningTeacher.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OpeningPupil> confirmOpeningPupil(String taxCode, Map<String, dynamic> data) async
  {
    final response = await _dio.put('/accounting/opening/pupils/$taxCode', data: data);

    return OpeningPupil.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccountingOpening> closeAccountingOpening() async
  {
    final response = await _dio.post('/accounting/opening/close');

    return AccountingOpening.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StudentMonth> getStudentsMonth(DateTime month) async
  {
    final response = await _dio.get('/accounting/student-month/${month.year}/${month.month}');

    return StudentMonth.fromJson(response.data as Map<String, dynamic>);
  }

  // How that teacher's unpaid hour counts for that month alone.
  Future<TeacherMonth> setMonthVolunteering(DateTime month, String taxCode, VolunteeringRule rule) async
  {
    try
    {
      final response = await _dio.put(
        '${_teacherMonthPath(month)}/$taxCode/volunteering',
        data: {'rule': rule.name},
      );

      return TeacherMonth.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio delle ore. Riprova più tardi.',
          "Couldn't save the hours. Please try again later.",
        ),
      );
    }
  }

  String _receiptPath(DateTime month, String taxCode) => '${_teacherMonthPath(month)}/$taxCode/receipt';

  // The bank transfer receipt of that teacher's month; a new one takes its place.
  Future<TeacherMonth> uploadPaymentReceipt(DateTime month, String taxCode, ApiFile file) async
  {
    try
    {
      final response = await _dio.put(
        _receiptPath(month, taxCode),
        data: FormData()..files.add(MapEntry('file', MultipartFile.fromBytes(file.bytes, filename: file.fileName))),
        options: Options(sendTimeout: _uploadTimeout, receiveTimeout: _uploadTimeout),
      );

      return TeacherMonth.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il caricamento della ricevuta. Riprova più tardi.',
          "Couldn't upload the receipt. Please try again later.",
        ),
      );
    }
  }

  Future<Uint8List> getPaymentReceipt(DateTime month, String taxCode) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        _receiptPath(month, taxCode),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: _uploadTimeout),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile aprire la ricevuta.', "Couldn't open the receipt."));
    }
  }

  Future<TeacherMonth> deletePaymentReceipt(DateTime month, String taxCode) async
  {
    try
    {
      final response = await _dio.delete(_receiptPath(month, taxCode));

      return TeacherMonth.fromJson(response.data as Map<String, dynamic>);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Errore durante l'eliminazione della ricevuta. Riprova più tardi.",
          "Couldn't delete the receipt. Please try again later.",
        ),
      );
    }
  }

  // What the weekly hour would give a teacher in person, for the dialog that adds one.
  Future<HoursSpan?> getVolunteerProposal(DateTime day, TimeBucket band, String taxCode, HoursSpan work) async
  {
    final response = await _dio.get(
      '${_teacherHoursPath(day, band)}/volunteering',
      queryParameters: {'tax_code': taxCode, 'start_time': clockOf(work.start), 'end_time': clockOf(work.end)},
    );

    final Object? volunteer = (response.data as Map<String, dynamic>)['volunteer'];

    return volunteer == null ? null : HoursSpan.fromJson(volunteer as Map<String, dynamic>);
  }

  // The "still at school" flag is set from the register, not here.
  Future<void> updateTeacherEducation({
    required String taxCode,
    String? schoolEducation,
    String? universityEducation,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/teacher-education',
        data: {
          'school_education': schoolEducation,
          'university_education': universityEducation,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante il salvataggio degli studi. Riprova più tardi.',
          "Couldn't save the education details. Please try again later.",
        ),
      );
    }
    finally
    {
      _forgetPeople();
    }
  }

  int profileImageVersion = 0;

  // Errors reach the image, which falls back to the initials.
  Future<Uint8List> fetchProfileImage(String path) async
  {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }

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
      _refused(e, tr('Errore durante il caricamento dell\'immagine.', "Couldn't upload the image."));
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
      _refused(e, tr('Errore durante la rimozione dell\'immagine.', "Couldn't remove the image."));
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
      _refused(
        e,
        tr(
          'Errore durante la creazione della scuola. Riprova più tardi.',
          "Couldn't create the school. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica della scuola. Riprova più tardi.',
          "Couldn't change the school. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della scuola. Riprova più tardi.',
          "Couldn't delete the school. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la creazione del percorso. Riprova più tardi.',
          "Couldn't create the programme. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica del percorso. Riprova più tardi.',
          "Couldn't change the programme. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione del percorso. Riprova più tardi.',
          "Couldn't delete the programme. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la creazione della materia. Riprova più tardi.',
          "Couldn't create the subject. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica della materia. Riprova più tardi.',
          "Couldn't change the subject. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della materia. Riprova più tardi.',
          "Couldn't delete the subject. Please try again later.",
        ),
      );
    }
    finally
    {
      _forgetCatalogues();
    }
  }

  // The heaviest answer by far: a slow line needs more than the default.
  static const Duration _registerTimeout = Duration(seconds: 60);

  Future<List<PersonItem>> getPeople({bool refresh = false})
  {
    return _peopleMemo.read(() async
    {
      final response = await _dio.get('/people/', options: Options(receiveTimeout: _registerTimeout));
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

  Future<List<PersonItem>> getFollowedStudents() async
  {
    final response = await _dio.get('/people/students');
    return parseList(response.data, PersonItem.fromJson);
  }

  // [types] are the backend codes: DSA, BES, ADHD, OTHER.
  Future<void> updateCertifications(
    String taxCode, {
    required List<String> types,
    String? dsaDetail,
    String? otherDetail,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/certifications',
        data: {
          'certification_types': types,
          'certification_dsa_detail': dsaDetail,
          'certification_other_detail': otherDetail,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
  }

  // The new images the text shows, each named by its key; those kept are not sent again.
  FormData _studentNoteForm(String text, Map<String, NoticeUpload> images)
  {
    return FormData()
      ..fields.add(MapEntry('text', text))
      ..files.addAll([
        for (final entry in images.entries)
          MapEntry('images', _multipart(entry.value, fileName: entry.key)),
      ]);
  }

  Future<void> createStudentNote(
    String taxCode,
    StudentNoteKind kind,
    String text, {
    Map<String, NoticeUpload> images = const {},
  }) async
  {
    try
    {
      await _dio.post(
        '/people/$taxCode/${kind.path}/',
        data: _studentNoteForm(text, images),
        options: Options(receiveTimeout: _uploadTimeout),
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
  }

  Future<void> updateStudentNote(
    String taxCode,
    StudentNoteKind kind,
    int noteId,
    String text, {
    Map<String, NoticeUpload> images = const {},
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$taxCode/${kind.path}/$noteId',
        data: _studentNoteForm(text, images),
        options: Options(receiveTimeout: _uploadTimeout),
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
  }

  Future<Uint8List> fetchStudentNoteImage(String taxCode, StudentNoteKind kind, int noteId, String key) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/people/$taxCode/${kind.path}/$noteId/images/$key',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: _uploadTimeout),
      );

      return Uint8List.fromList(response.data!);
    }
    on DioException catch (e)
    {
      _refusedBytes(e, tr('Impossibile caricare l\'immagine.', "Couldn't load the image."));
    }
  }

  // Only once the lesson is over; nobody but the administrators reads it afterwards.
  Future<void> createTeacherNote(int lessonId, String text) async
  {
    try
    {
      await _dio.post('/lessons/$lessonId/teacher-notes/', data: {'text': text});
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
  }

  Future<void> deleteStudentNote(String taxCode, StudentNoteKind kind, int noteId) async
  {
    try
    {
      await _dio.delete('/people/$taxCode/${kind.path}/$noteId');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
  }

  // Slug to the version seen; [platform] is "mobile" or "desktop".
  Future<Map<String, int>> getSeenTours(String platform) async
  {
    final response = await _dio.get('/tours/$platform');
    final Object? data = response.data;

    if (data is! Map)
    {
      throw const FormatException('Tutorial visti non leggibili.');
    }

    return {
      for (final MapEntry<dynamic, dynamic> entry in data.entries)
        if (entry.key is String && entry.value is int) entry.key as String: entry.value as int,
    };
  }

  Future<void> markToursSeen(String platform, Map<String, int> seen) async
  {
    await _dio.put('/tours/$platform', data: {'seen': seen});
  }

  // Newest first.
  Future<List<NotificationItem>> getNotifications() async
  {
    try
    {
      final response = await _dio.get('/notifications');

      return parseList(response.data, NotificationItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare le notifiche.', "Couldn't load the notifications."));
    }
  }

  // Marked by hand rather than opened, every kind stays on the card.
  Future<void> markNotificationRead(int id, {bool opened = true}) async
  {
    await _dio.put('/notifications/$id/read', queryParameters: opened ? null : {'opened': false});
  }

  Future<void> markNotificationUnread(int id) async
  {
    await _dio.put('/notifications/$id/unread');
  }

  Future<void> deleteNotification(int id) async
  {
    await _dio.delete('/notifications/$id');
  }

  Future<void> markCalendarSeen(DateTime day, TimeBucket band) async
  {
    await _dio.put('/notifications/calendar/${formatDateOnly(day)}/${LessonItem.formatBand(band)}/seen');
  }

  // One's own availabilities of those days on screen: the notifications of them go.
  Future<void> markAvailabilitySeen(DateTime from, DateTime to) async
  {
    await _dio.put(
      '/notifications/availabilities/seen',
      queryParameters: {'date_from': formatDateOnly(from), 'date_to': formatDateOnly(to)},
    );
  }

  // A pupil's bookings of those days on screen: the notifications of them go.
  Future<void> markBookingsSeen(String pupilTaxCode, DateTime from, DateTime to) async
  {
    await _dio.put(
      '/notifications/bookings/$pupilTaxCode/seen',
      queryParameters: {'date_from': formatDateOnly(from), 'date_to': formatDateOnly(to)},
    );
  }

  // A pupil's Osservazioni on screen: the notifications of teachers' new notes go.
  Future<void> markTeacherNotesSeen(String pupilTaxCode) async
  {
    await _dio.put('/notifications/teacher-notes/$pupilTaxCode/seen');
  }

  // One's own Osservazioni on screen: the server withdraws the news of new ones.
  Future<void> markAdministratorNotesSeen() async
  {
    await _dio.put('/notifications/administrator-notes/seen');
  }

  // The kinds of the account's roles that can be turned on or off.
  Future<List<NotificationKindChoice>> getNotificationKinds() async
  {
    try
    {
      final response = await _dio.get('/notifications/kinds');

      return parseList(response.data, NotificationKindChoice.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile caricare i tipi di notifica.', "Couldn't load the notification types."));
    }
  }

  Future<List<NotificationKindChoice>> setNotificationKinds(List<NotificationKindChoice> choices) async
  {
    try
    {
      final response = await _dio.put(
        '/notifications/kinds',
        data: [for (final choice in choices) choice.toJson()],
      );

      return parseList(response.data, NotificationKindChoice.fromJson);
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile salvare i tipi di notifica.', "Couldn't save the notification types."));
    }
  }

  // Null while the server has no key: browsers then get no pushes.
  Future<String?> getWebPushKey() async
  {
    final response = await _dio.get('/push/web-key');
    final Object? data = response.data;

    return data is Map ? data['public_key'] as String? : null;
  }

  Future<void> registerPushAddress(PushAddress address) async
  {
    await _dio.put('/push/devices', data: address.toJson());
  }

  Future<void> forgetPushAddress(String address) async
  {
    await _dio.delete('/push/devices', data: {'address': address});
  }

  // Null sections: every tour of the platform.
  Future<void> resetTours(String platform, [Iterable<String>? sections]) async
  {
    await _dio.delete(
      '/tours/$platform',
      queryParameters: {if (sections != null) 'section': sections.toList()},
      options: Options(listFormat: ListFormat.multi),
    );
  }

  // Also opens the accounts of the parents named; each one gets a welcome email.
  Future<void> createAccount(
    String fiscalCode, {
    required bool autonomousBookings,
    required List<String> parentTaxCodes,
  }) async
  {
    try
    {
      await _dio.post(
        '/people/$fiscalCode/account',
        data: {
          'autonomous_bookings': autonomousBookings,
          'parent_tax_codes': parentTaxCodes,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile creare l'account.", "Couldn't create the account."));
    }
    finally
    {
      _forgetPeople();
    }
  }

  Future<PersonAccountItem> getPersonAccount(String fiscalCode) async
  {
    try
    {
      final response = await _dio.get('/people/$fiscalCode/account');

      return PersonAccountItem.fromJson(Map<String, dynamic>.from(response.data));
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile caricare l'account.", "Couldn't load the account."));
    }
  }

  // Also ends every session of the account.
  Future<void> forcePasswordChange(String fiscalCode) async
  {
    try
    {
      await _dio.post('/people/$fiscalCode/account/password-change');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile richiedere il cambio password.', "Couldn't request the password change."));
    }
  }

  Future<void> sendPasswordResetEmail(String fiscalCode) async
  {
    try
    {
      await _dio.post('/people/$fiscalCode/account/password-reset-email');
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile inviare l'email di recupero.", "Couldn't send the recovery email."));
    }
  }

  Future<void> setAutonomousBookings(String fiscalCode, {required bool enabled}) async
  {
    try
    {
      await _dio.put(
        '/people/$fiscalCode/account/autonomous-bookings',
        data: {'enabled': enabled},
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile modificare le prenotazioni autonome.', "Couldn't change self-booking."));
    }
  }

  // Ends every session as well.
  Future<void> suspendAccount(String fiscalCode) async
  {
    try
    {
      await _dio.post('/people/$fiscalCode/account/suspension');
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile sospendere l'account.", "Couldn't suspend the account."));
    }
  }

  Future<void> reactivateAccount(String fiscalCode) async
  {
    try
    {
      await _dio.delete('/people/$fiscalCode/account/suspension');
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile riattivare l'account.", "Couldn't reactivate the account."));
    }
  }

  Future<void> unlockAccount(String fiscalCode) async
  {
    try
    {
      await _dio.delete('/people/$fiscalCode/account/lock');
    }
    on DioException catch (e)
    {
      _refused(e, tr("Impossibile sbloccare l'account.", "Couldn't unlock the account."));
    }
  }

  Future<void> revokePersonSession(String fiscalCode, String sessionId) async
  {
    try
    {
      await _dio.delete('/people/$fiscalCode/account/sessions/$sessionId');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile disattivare la sessione.', "Couldn't sign out the session."));
    }
  }

  // On one's own record the session in use survives.
  Future<void> revokePersonSessions(String fiscalCode) async
  {
    try
    {
      await _dio.delete('/people/$fiscalCode/account/sessions');
    }
    on DioException catch (e)
    {
      _refused(e, tr('Impossibile disattivare le sessioni.', "Couldn't sign out the sessions."));
    }
  }

  Future<String> updatePerson(String fiscalCode, Map<String, dynamic> payload, {Uint8List? imageBytes}) async
  {
    try
    {
      final response   = await _dio.put('/people/$fiscalCode', data: payload);
      final newTaxCode = response.data['new_tax_code'] ?? fiscalCode;

      // One's own record may change one's own roles.
      if (fiscalCode.toUpperCase() == identity.value?.taxCode.toUpperCase())
      {
        unawaited(_recheckIdentity(now: true));
      }

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
      _refused(
        e,
        tr(
          'Errore imprevisto durante l\'aggiornamento. Riprova più tardi.',
          'Unexpected error while updating. Please try again later.',
        ),
      );
    }
    finally
    {
      _forgetPeople();
    }
  }

  // Returns the new person's tax code.
  Future<String> createPersonFromWizard(Map<String, dynamic> payload, {Uint8List? imageBytes}) async
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

      return response.data['tax_code'] as String;
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore imprevisto durante la creazione della persona. Riprova più tardi.',
          'Unexpected error while creating the person. Please try again later.',
        ),
      );
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
      _refusedBytes(
        e,
        tr(
          'Errore imprevisto durante la generazione del modulo. Riprova più tardi.',
          'Unexpected error while generating the form. Please try again later.',
        ),
      );
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
      _refusedBytes(
        e,
        tr(
          'Errore imprevisto durante la generazione del modulo. Riprova più tardi.',
          'Unexpected error while generating the form. Please try again later.',
        ),
      );
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
      _refusedBytes(
        e,
        tr(
          'Errore imprevisto durante la generazione del modulo. Riprova più tardi.',
          'Unexpected error while generating the form. Please try again later.',
        ),
      );
    }
  }

  Future<ApiFile> fetchDocument(String path, {required String fallbackName}) async
  {
    try
    {
      final response = await _dio.get<List<int>>(
        '/documents/$path',
        options: Options(responseType: ResponseType.bytes),
      );

      return (
        bytes: Uint8List.fromList(response.data!),
        fileName: fileNameOf(response.headers.value('content-disposition')) ?? '$fallbackName.pdf',
      );
    }
    on DioException catch (e)
    {
      _refusedBytes(
        e,
        tr(
          'Errore imprevisto durante il recupero del documento. Riprova più tardi.',
          'Unexpected error while fetching the document. Please try again later.',
        ),
      );
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
      _refusedBytes(
        e,
        tr(
          'Errore imprevisto durante la generazione del modulo. Riprova più tardi.',
          'Unexpected error while generating the form. Please try again later.',
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile inviare la segnalazione. Riprova più tardi.',
          "Couldn't send the report. Please try again later.",
        ),
      );
    }
  }

  // Owed fees or unpaid hours to lose are refused with WriteWouldTakeAway until confirmed.
  Future<void> updatePersonMemberships(
    String fiscalCode,
    List<Map<String, dynamic>> memberships,
    DateTime? expectedUpdatedAt, {
    bool confirm = false,
  }) async
  {
    try
    {
      await _dio.put(
        '/people/$fiscalCode/memberships',
        data: {
          'memberships': memberships,
          if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt.toIso8601String(),
          'confirm': confirm,
        },
      );
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore imprevisto durante l\'aggiornamento delle iscrizioni. Riprova più tardi.',
          'Unexpected error while updating the enrolments. Please try again later.',
        ),
      );
    }
    finally
    {
      _forgetPeople();
    }
  }

  // The year in course with its fees, method and, for a pupil, tariff: all or nothing.
  Future<void> reEnrollPerson(String fiscalCode, Map<String, dynamic> payload) async
  {
    try
    {
      await _dio.post('/people/$fiscalCode/re-enrollment', data: payload);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore imprevisto durante il rinnovo dell\'iscrizione. Riprova più tardi.',
          'Unexpected error while renewing the enrolment. Please try again later.',
        ),
      );
    }
    finally
    {
      _forgetPeople();
    }
  }

  // Switching off with hours ahead is refused with WriteWouldTakeAway until confirmed.
  Future<void> setCollaboration(String fiscalCode, {required bool active, bool confirm = false}) async
  {
    try
    {
      await _dio.put(
        '/people/$fiscalCode/collaboration',
        data: {'active': active, 'confirm': confirm},
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
    }
    finally
    {
      _forgetPeople();
    }
  }

  // One criterion of a teacher's evaluation; answers the criteria met and the rating they make.
  Future<({List<String> met, double rating})> setTeacherCriterion(
    String fiscalCode,
    String criterion, {
    required bool met,
  }) async
  {
    try
    {
      final response = await _dio.put('/people/$fiscalCode/evaluation/$criterion', data: {'met': met});
      final Map<String, dynamic> body = response.data as Map<String, dynamic>;

      return (
        met: (body['met_criteria'] as List<dynamic>).cast<String>(),
        rating: (body['rating'] as num).toDouble(),
      );
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(
        e,
        tr(
          'Errore imprevisto durante la revoca dell\'iscrizione. Riprova più tardi.',
          'Unexpected error while revoking the enrolment. Please try again later.',
        ),
      );
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
    _refused(
      e,
      tr(
        'Errore imprevisto durante l\'aggiornamento degli anni scolastici. Riprova più tardi.',
        'Unexpected error while updating the school years. Please try again later.',
      ),
    );
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
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(
        e,
        tr(
          'Impossibile recuperare i totali attuali. Riprova più tardi.',
          "Couldn't get the current totals. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il trend degli iscritti. Riprova più tardi.',
          "Couldn't get the enrolment trend. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il trend dei collaboratori. Riprova più tardi.',
          "Couldn't get the collaborators trend. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il tasso di fidelizzazione. Riprova più tardi.',
          "Couldn't get the retention rate. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il tasso di fidelizzazione collaboratori. Riprova più tardi.',
          "Couldn't get the collaborators retention rate. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare i totali del ruolo. Riprova più tardi.',
          "Couldn't get the role totals. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il trend del ruolo. Riprova più tardi.',
          "Couldn't get the role trend. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il trend collaboratori del ruolo. Riprova più tardi.',
          "Couldn't get the role collaborators trend. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la fidelizzazione del ruolo. Riprova più tardi.',
          "Couldn't get the role retention. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la fidelizzazione collaboratori. Riprova più tardi.',
          "Couldn't get the collaborators retention. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la distribuzione per città. Riprova più tardi.',
          "Couldn't get the breakdown by city. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la distribuzione per età. Riprova più tardi.',
          "Couldn't get the breakdown by age. Please try again later.",
        ),
      );
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
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(e, tr('Errore imprevisto. Riprova più tardi.', 'Unexpected error. Please try again later.'));
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la distribuzione scolastica. Riprova più tardi.',
          "Couldn't get the breakdown by school. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la distribuzione delle certificazioni. Riprova più tardi.',
          "Couldn't get the breakdown of certifications. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare le statistiche sulle materie dei docenti. Riprova più tardi.',
          "Couldn't get the statistics on teachers' subjects. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il gradimento dei docenti. Riprova più tardi.',
          "Couldn't get the teachers' ratings. Please try again later.",
        ),
      );
    }
  }

  Future<TeacherAvailabilityStatisticsItem> getTeacherAvailabilityStatistics({
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/availability-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return TeacherAvailabilityStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Impossibile recuperare le statistiche sulle disponibilità. Riprova più tardi.',
          "Couldn't get the availability statistics. Please try again later.",
        ),
      );
    }
  }

  Future<StudentPresenceStatisticsItem> getStudentPresenceStatistics({
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/presence-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return StudentPresenceStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Impossibile recuperare le statistiche sulle presenze. Riprova più tardi.',
          "Couldn't get the attendance statistics. Please try again later.",
        ),
      );
    }
  }

  Future<DateTime?> getFirstOpenDay({String mode = 'presence'}) async
  {
    try
    {
      final response = await _dio.get('/statistics/first-open-day', queryParameters: {'mode': mode});
      return parseDate(response.data['first_open_day']);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Impossibile recuperare l'andamento. Riprova più tardi.",
          "Couldn't get the trend. Please try again later.",
        ),
      );
    }
  }

  // The ten teachers with the most hours done, as their homes count them.
  Future<List<PersonHoursItem>> getTeacherLessonHours({
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/lesson-hours',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return parseList(response.data, PersonHoursItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Impossibile recuperare le ore di lezione dei docenti. Riprova più tardi.',
          "Couldn't get the teachers' lesson hours. Please try again later.",
        ),
      );
    }
  }

  Future<List<TeacherActivityDayItem>> getTeacherActivityTrend({
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/activity-trend',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return parseList(response.data, TeacherActivityDayItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Impossibile recuperare l'andamento dei docenti. Riprova più tardi.",
          "Couldn't get the teachers' trend. Please try again later.",
        ),
      );
    }
  }

  Future<List<PresenceDayItem>> getStudentPresenceTrend({
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/presence-trend',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return parseList(response.data, PresenceDayItem.fromJson);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Impossibile recuperare l'andamento delle presenze. Riprova più tardi.",
          "Couldn't get the attendance trend. Please try again later.",
        ),
      );
    }
  }

  Future<TeacherPersonalStatisticsItem> getTeacherPersonalStatistics(
    String taxCode, {
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/teachers/$taxCode/personal-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return TeacherPersonalStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Impossibile recuperare le statistiche personali. Riprova più tardi.',
          "Couldn't get the personal statistics. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare il gradimento del docente. Riprova più tardi.',
          "Couldn't get the teacher's rating. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare gli studenti. Riprova più tardi.',
          "Couldn't get the students. Please try again later.",
        ),
      );
    }
  }

  Future<StudentPersonalStatisticsItem> getStudentPersonalStatistics(
    String taxCode, {
    int? months,
    int? year,
    int? month,
    String mode = 'presence',
  }) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/$taxCode/personal-statistics',
        queryParameters: {
          'months': ?months,
          'year': ?year,
          'month': ?month,
          'mode': mode,
        },
      );
      return StudentPersonalStatisticsItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Impossibile recuperare le statistiche personali. Riprova più tardi.',
          "Couldn't get the personal statistics. Please try again later.",
        ),
      );
    }
  }

  // Separate from the presence statistics: the discipline is chosen after the page has loaded.
  Future<List<MemberTrendItem>> getDisciplineRequestTrend(int associationSubjectId, {String mode = 'presence'}) async
  {
    try
    {
      final response = await _dio.get(
        '/statistics/students/discipline-trend',
        queryParameters: {'association_subject_id': associationSubjectId, 'mode': mode},
      );
      return monthlyTrendPoints(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          "Impossibile recuperare l'andamento della disciplina. Riprova più tardi.",
          "Couldn't get the discipline trend. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Impossibile recuperare la distribuzione dei corsi. Riprova più tardi.',
          "Couldn't get the breakdown of courses. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la verifica del codice fiscale. Riprova più tardi.',
          "Couldn't check the tax code. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la creazione della disponibilità. Riprova più tardi.',
          "Couldn't create the availability. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica della disponibilità. Riprova più tardi.',
          "Couldn't change the availability. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della disponibilità. Riprova più tardi.',
          "Couldn't delete the availability. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica della richiesta. Riprova più tardi.',
          "Couldn't change the request. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della richiesta. Riprova più tardi.',
          "Couldn't delete the request. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'aggiunta della materia. Riprova più tardi.',
          "Couldn't add the subject. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica della materia. Riprova più tardi.',
          "Couldn't change the subject. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della materia. Riprova più tardi.',
          "Couldn't delete the subject. Please try again later.",
        ),
      );
    }
  }

  Future<LessonItem> getLesson(int id) async
  {
    final response = await _dio.get('/lessons/$id');

    return LessonItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<LessonItem>> getLessons({DateTime? dateFrom, DateTime? dateTo, String? teacherTaxCode}) async
  {
    final response = await _dio.get(
      '/lessons/',
      queryParameters: {
        'date_from': ?dateFrom.let(formatDateOnly),
        'date_to': ?dateTo.let(formatDateOnly),
        'teacher_tax_code': ?teacherTaxCode,
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
    bool waiveCompetence = false,
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
          'waive_competence': waiveCompetence,
        },
      );

      return LessonItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la creazione della lezione. Riprova più tardi.',
          "Couldn't create the lesson. Please try again later.",
        ),
      );
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
    bool waiveCompetence = false,
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
          'waive_competence': waiveCompetence,
        },
      );

      return LessonItem.fromJson(response.data);
    }
    on DioException catch (e)
    {
      _refused(
        e,
        tr(
          'Errore durante la modifica della lezione. Riprova più tardi.',
          "Couldn't change the lesson. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione della lezione. Riprova più tardi.',
          "Couldn't delete the lesson. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la creazione dell\'attività. Riprova più tardi.',
          "Couldn't create the activity. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante la modifica dell\'attività. Riprova più tardi.',
          "Couldn't change the activity. Please try again later.",
        ),
      );
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
      _refused(
        e,
        tr(
          'Errore durante l\'eliminazione dell\'attività. Riprova più tardi.',
          "Couldn't delete the activity. Please try again later.",
        ),
      );
    }
  }

  String _publicationPath(DateTime day, TimeBucket band)
  {
    return '/calendar-publications/${formatDateOnly(day)}/${LessonItem.formatBand(band)}';
  }

  // Bands whose bookings closed with nobody booked: they will never be published.
  Future<List<(DateTime, TimeBucket)>> getUnbookedBands({required DateTime dateFrom, required DateTime dateTo}) async
  {
    final response = await _dio.get(
      '/calendar-publications/unbooked',
      queryParameters: {
        'date_from': formatDateOnly(dateFrom),
        'date_to': formatDateOnly(dateTo),
      },
    );

    return parseList(response.data, (json) => (DateTime.parse(json['date'] as String), LessonItem.parseBand(json['band'])));
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
      _refused(e, tr('Errore durante la pubblicazione del calendario.', "Couldn't publish the calendar."));
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
      _refused(e, tr('Errore durante il ritorno in bozza.', "Couldn't go back to draft."));
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
      _refused(e, tr('Errore durante l\'uscita dalla bozza.', "Couldn't leave the draft."));
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
      _refused(e, tr('Errore durante la pubblicazione delle modifiche.', "Couldn't publish the changes."));
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
      _refused(e, tr('Errore durante l\'esclusione del docente.', "Couldn't exclude the teacher."));
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
      _refused(e, tr('Errore durante il reinserimento del docente.', "Couldn't bring the teacher back."));
    }
  }

  // Administrators read the band's notes; a teacher reads their own, published bands only.
  Future<List<CalendarTeacherNoteItem>> getCalendarTeacherNotes({
    required DateTime day,
    TimeBucket? band,
  }) async
  {
    final response = await _dio.get(
      '/calendar-teacher-notes/',
      queryParameters: {
        'day': formatDateOnly(day),
        if (band != null) 'band': LessonItem.formatBand(band),
      },
    );

    return [
      for (final row in (response.data as List).cast<Map<String, dynamic>>()) CalendarTeacherNoteItem.fromJson(row),
    ];
  }

  // The band's whole set: teachers left out lose their note.
  Future<List<CalendarTeacherNoteItem>> replaceCalendarTeacherNotes({
    required DateTime day,
    required TimeBucket band,
    required Map<String, String> notes,
  }) async
  {
    try
    {
      final response = await _dio.put(
        '/calendar-teacher-notes/',
        data: {
          'date': formatDateOnly(day),
          'band': LessonItem.formatBand(band),
          'notes': [
            for (final MapEntry(:key, :value) in notes.entries) {'teacher_tax_code': key, 'text': value},
          ],
        },
      );

      return [
        for (final row in (response.data as List).cast<Map<String, dynamic>>()) CalendarTeacherNoteItem.fromJson(row),
      ];
    }
    on DioException catch (e)
    {
      _refused(e, tr('Errore durante il salvataggio delle note.', "Couldn't save the notes."));
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
