import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medqueue_frontend/models/api_response_model.dart';
import 'dart:convert';
import 'api_constants.dart';

/// Token Manager for secure token storage and retrieval
class TokenManager {
  static const _storage = FlutterSecureStorage();

  /// Write arbitrary string data for app-level persistence.
  static Future<void> writeRaw(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read arbitrary string data for app-level persistence.
  static Future<String?> readRaw(String key) async {
    return await _storage.read(key: key);
  }

  /// Save both access and refresh tokens
  static Future<void> saveTokens(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: ApiConstants.accessTokenKey, value: access),
      _storage.write(key: ApiConstants.refreshTokenKey, value: refresh),
    ]);
  }

  /// Get the access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: ApiConstants.accessTokenKey);
  }

  /// Get the refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: ApiConstants.refreshTokenKey);
  }

  /// Check if user is authenticated (has valid access token)
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Decode JWT token and extract claims
  static TokenClaims? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      final decoded = utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1]),
      ));
      
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return TokenClaims.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Get decoded access token claims
  static Future<TokenClaims?> getAccessTokenClaims() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return decodeToken(token);
  }

  /// Check if access token is expired
  static Future<bool> isAccessTokenExpired() async {
    final claims = await getAccessTokenClaims();
    if (claims == null) return true;
    return claims.isExpired;
  }

  /// Save user data for quick access
  static Future<void> saveUserData(UserProfile user) async {
    final jsonString = jsonEncode(user.toJson());
    await _storage.write(key: ApiConstants.userDataKey, value: jsonString);
  }

  /// Get cached user data
  static Future<UserProfile?> getCachedUserData() async {
    final jsonString = await _storage.read(key: ApiConstants.userDataKey);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Clear all stored tokens and user data
  static Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: ApiConstants.accessTokenKey),
      _storage.delete(key: ApiConstants.refreshTokenKey),
      _storage.delete(key: ApiConstants.userDataKey),
    ]);
  }

  /// Get user role from cached data or decoded token
  static Future<String?> getUserRole() async {
    // Try from cached user data first
    final cachedUser = await getCachedUserData();
    if (cachedUser != null) return cachedUser.role;

    // Try from access token claims
    final claims = await getAccessTokenClaims();
    return claims?.role;
  }
}
