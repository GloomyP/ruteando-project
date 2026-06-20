import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_rest_service.dart';

class SupabaseAuthUser {
  const SupabaseAuthUser({
    required this.id,
    required this.email,
    this.name,
  });

  final String id;
  final String email;
  final String? name;

  String? get displayName => name;
  String get uid => id;

  factory SupabaseAuthUser.fromJson(Map<String, dynamic> json) {
    final metadata = json['user_metadata'];
    final meta = metadata is Map ? Map<String, dynamic>.from(metadata) : {};
    return SupabaseAuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString().toLowerCase().trim() ?? '',
      name:
          (meta['name'] ?? meta['full_name'] ?? meta['display_name'])
              ?.toString()
              .trim(),
    );
  }

  SupabaseAuthUser copyWith({String? name}) {
    return SupabaseAuthUser(id: id, email: email, name: name ?? this.name);
  }
}

class SupabaseAuthSession {
  const SupabaseAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final SupabaseAuthUser user;
}

class SupabaseAuthService {
  SupabaseAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _authChanges = StreamController<SupabaseAuthUser?>.broadcast();
  SupabaseAuthSession? _session;

  SupabaseAuthUser? get currentUser => _session?.user;
  String? get accessToken => _session?.accessToken;
  Stream<SupabaseAuthUser?> authStateChanges() async* {
    yield currentUser;
    yield* _authChanges.stream;
  }

  Uri _authUri(String path, [Map<String, String>? query]) {
    final authUrl = SupabaseConfig.restUrl.replaceFirst('/rest/v1/', '/auth/v1/');
    final base = authUrl.endsWith('/') ? authUrl : '$authUrl/';
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    return {
      'apikey': SupabaseConfig.anonKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Map<String, String> get _authHeaders {
    final token = _session?.accessToken;
    return {
      ..._headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<SupabaseAuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _authUri('token', {'grant_type': 'password'}),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final decoded = _decode(response);
    _session = _sessionFromJson(decoded);
    SupabaseConfig.accessToken = _session?.accessToken;
    _authChanges.add(_session?.user);
    return _session!;
  }

  Future<SupabaseAuthUser> signUp({
    required String email,
    required String password,
    String? name,
    bool keepCurrentSession = false,
  }) async {
    final previous = _session;
    final response = await _client.post(
      _authUri('signup'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {if (name != null && name.trim().isNotEmpty) 'name': name},
      }),
    );
    final decoded = _decode(response);
    final userJson = decoded['user'] is Map ? decoded['user'] : decoded;
    final user = SupabaseAuthUser.fromJson(Map<String, dynamic>.from(userJson));

    final sessionJson = decoded['session'];
    if (!keepCurrentSession && sessionJson is Map) {
      _session = _sessionFromJson(Map<String, dynamic>.from(sessionJson));
      SupabaseConfig.accessToken = _session?.accessToken;
      _authChanges.add(_session?.user);
    } else {
      _session = previous;
      SupabaseConfig.accessToken = previous?.accessToken;
    }

    return user;
  }

  Future<void> updatePassword(String password) async {
    final response = await _client.put(
      _authUri('user'),
      headers: _authHeaders,
      body: jsonEncode({'password': password}),
    );
    _decode(response);
  }

  Future<void> updateDisplayName(String name) async {
    final response = await _client.put(
      _authUri('user'),
      headers: _authHeaders,
      body: jsonEncode({
        'data': {'name': name},
      }),
    );
    final decoded = _decode(response);
    final updated = SupabaseAuthUser.fromJson(decoded);
    _session = SupabaseAuthSession(
      accessToken: _session!.accessToken,
      refreshToken: _session!.refreshToken,
      user: updated,
    );
    _authChanges.add(updated);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final response = await _client.post(
      _authUri('recover'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    _decode(response);
  }

  Future<void> signOut() async {
    if (_session != null) {
      await _client.post(_authUri('logout'), headers: _authHeaders);
    }
    _session = null;
    SupabaseConfig.accessToken = null;
    _authChanges.add(null);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          data['msg'] ??
          data['message'] ??
          data['error_description'] ??
          data['error'] ??
          response.reasonPhrase ??
          'Error de Supabase Auth';
      throw SupabaseAuthException(message.toString(), response.statusCode);
    }
    return data;
  }

  SupabaseAuthSession _sessionFromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map) {
      throw const SupabaseAuthException('Supabase no devolvio usuario.', 500);
    }
    return SupabaseAuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      user: SupabaseAuthUser.fromJson(Map<String, dynamic>.from(userJson)),
    );
  }
}

class SupabaseAuthException implements Exception {
  const SupabaseAuthException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

final supabaseAuth = SupabaseAuthService();
