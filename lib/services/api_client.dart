import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tnt_lh/services/auth_service.dart';

/// The one place an authenticated request is made.
///
/// Access tokens live for **one hour**. `AuthService.refreshToken()` existed and
/// was never called by anything, and only `getProfile` handled a 401 — so every
/// other service (cart, orders, addresses, wishlist, coupons, reviews) simply
/// started failing an hour into the session. The customer would add something to
/// their cart, get a generic error, and have no idea that quitting and
/// reopening the app would have fixed it.
///
/// Everything authenticated goes through here now: it attaches the token,
/// and on a 401 it refreshes once and replays the request.
class ApiClient {
  ApiClient._();

  /// Collapses concurrent refreshes into one. The backend **rotates** the
  /// refresh token on use, so if the cart, the order list and the wishlist all
  /// 401 at once and each refreshed independently, they would revoke each
  /// other's tokens and log the customer out.
  static Future<String?>? _refreshInFlight;

  static Future<String?> _refresh() {
    return _refreshInFlight ??= AuthService.refreshToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// For callers outside the HTTP path that hold a token the server refused —
  /// the live-updates socket. Shares the single in-flight refresh above.
  static Future<String?> refreshSession() => _refresh();

  /// Dart's `http` package applies NO timeout by default. A request to a cell
  /// that has gone dead, or through a captive portal that black-holes traffic,
  /// simply never completes — so the customer sat watching a spinner forever,
  /// with no way out but killing the app. That is also precisely how a checkout
  /// ends up submitted twice.
  static const Duration _timeout = Duration(seconds: 25);

  static Future<http.Response> get(Uri url) => _send('GET', url);

  static Future<http.Response> post(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
  }) => _send('POST', url, body: body, extraHeaders: headers);

  static Future<http.Response> put(Uri url, {Object? body}) =>
      _send('PUT', url, body: body);

  static Future<http.Response> patch(Uri url, {Object? body}) =>
      _send('PATCH', url, body: body);

  static Future<http.Response> delete(Uri url, {Object? body}) =>
      _send('DELETE', url, body: body);

  static Future<http.Response> _send(
    String method,
    Uri url, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw 'Not authenticated';

    var response = await _dispatch(method, url, token, body, extraHeaders);

    // The token is an hour old at most, so this is the routine case, not an
    // exceptional one: refresh and replay, once.
    if (response.statusCode == 401) {
      final fresh = await _refresh();
      if (fresh == null) {
        // Rejected outright: AuthService.refreshToken has already signed the
        // customer out, and the app returns to the sign-in screen. Otherwise
        // the refresh merely failed to get through, and the session is intact.
        if (await AuthService.hasSession()) {
          throw "Can't reach the server. Check your connection and try again.";
        }
        throw 'Your session expired. Please sign in again.';
      }
      response = await _dispatch(method, url, fresh, body, extraHeaders);
    }

    return response;
  }

  static Future<http.Response> _dispatch(
    String method,
    Uri url,
    String token,
    Object? body,
    Map<String, String>? extraHeaders,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?extraHeaders,
    };
    final encoded = body == null ? null : jsonEncode(body);

    Future<http.Response> call() {
      switch (method) {
        case 'GET':
          return http.get(url, headers: headers);
        case 'POST':
          return http.post(url, headers: headers, body: encoded);
        case 'PUT':
          return http.put(url, headers: headers, body: encoded);
        case 'PATCH':
          return http.patch(url, headers: headers, body: encoded);
        case 'DELETE':
          return http.delete(url, headers: headers, body: encoded);
        default:
          throw ArgumentError('Unsupported method: \$method');
      }
    }

    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw "That took too long. Check your connection and try again.";
    } on SocketException {
      throw "Can't reach the server. Check your connection.";
    } on http.ClientException {
      throw "The connection dropped. Check your connection and try again.";
    }
  }
}
