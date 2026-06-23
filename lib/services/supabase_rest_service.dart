import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SupabaseRestService {
  SupabaseRestService({http.Client? client, String? restUrl, String? anonKey})
    : _client = client ?? http.Client(),
      restUrl = restUrl ?? SupabaseConfig.restUrl,
      anonKey = anonKey ?? SupabaseConfig.anonKey;

  final http.Client _client;
  final String restUrl;
  final String anonKey;

  bool get isConfigured => anonKey.trim().isNotEmpty;

  Uri _uri(String table, [Map<String, String>? query]) {
    final base = restUrl.endsWith('/') ? restUrl : '$restUrl/';
    return Uri.parse('$base$table').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final bearerToken = SupabaseConfig.accessToken?.trim().isNotEmpty == true
        ? SupabaseConfig.accessToken!
        : anonKey;

    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, String>? filters,
    String select = '*',
    int? limit,
    String? order,
  }) async {
    if (!isConfigured) {
      return [];
    }

    final query = <String, String>{'select': select, ...?filters};
    if (limit != null) {
      query['limit'] = limit.toString();
    }
    if (order != null) {
      query['order'] = order;
    }

    final response = await _client.get(_uri(table, query), headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Supabase select $table fallo: ${response.body}');
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    String? onConflict,
  }) async {
    if (!isConfigured) {
      return;
    }

    final query = onConflict == null ? null : {'on_conflict': onConflict};
    final response = await _client.post(
      _uri(table, query),
      headers: {
        ..._headers,
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Supabase upsert $table fallo: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, String> filters,
  }) async {
    if (!isConfigured) {
      return [];
    }

    final response = await _client.patch(
      _uri(table, filters),
      headers: {..._headers, 'Prefer': 'return=representation'},
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Supabase update $table fallo: ${response.body}');
      throw SupabaseRestException(
        'No se pudo actualizar $table.',
        response.statusCode,
        response.body,
      );
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(body);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    if (!isConfigured) {
      return;
    }

    final response = await _client.post(
      _uri(table),
      headers: {..._headers, 'Prefer': 'return=minimal'},
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Supabase insert $table fallo: ${response.body}');
    }
  }

  Future<void> delete(
    String table, {
    required Map<String, String> filters,
  }) async {
    if (!isConfigured) {
      return;
    }

    final response = await _client.delete(
      _uri(table, filters),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Supabase delete $table fallo: ${response.body}');
    }
  }
}

class SupabaseRestException implements Exception {
  const SupabaseRestException(this.message, this.statusCode, this.body);

  final String message;
  final int statusCode;
  final String body;

  @override
  String toString() => body.trim().isEmpty ? message : '$message $body';
}

class SupabaseConfig {
  static String? accessToken;

  static const restUrl = String.fromEnvironment(
    'SUPABASE_REST_URL',
    defaultValue: 'https://zexfyjefmomuaoamwycw.supabase.co/rest/v1/',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_rrx6nMypqyFpVYw76O7rhg_zmj4Uj8o',
  );

  static String eq(String value) => 'eq.$value';
}

final supabaseRest = SupabaseRestService();
