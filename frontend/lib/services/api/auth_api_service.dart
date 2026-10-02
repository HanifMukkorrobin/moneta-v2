import '../../models/user_profile.dart';
import 'moneta_api_client.dart';

class AuthSessionResult {
  final UserProfile user;
  final String token;

  const AuthSessionResult({
    required this.user,
    required this.token,
  });

  UserProfile get profile => user;
}

class AuthApiService {
  static final AuthApiService instance = AuthApiService();
  final MonetaApiClient _client;

  AuthApiService({MonetaApiClient? client})
      : _client = client ?? MonetaApiClient.instance;

  Future<AuthSessionResult> register({
    String? displayName,
    String? name,
    required String email,
    required String password,
    String? confirmPassword,
    String? currency,
  }) async {
    final effectiveName = displayName ?? name ?? '';
    final res = await _client.post(
      '/api/auth/register',
      body: {
        'displayName': effectiveName,
        'email': email,
        'password': password,
        if (confirmPassword != null) 'confirmPassword': confirmPassword,
        if (currency != null) 'currency': currency,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    final token = (data['token'] ?? res['token'] ?? '').toString();
    final user = UserProfile.fromJson(userMap);
    _client.setAuthSession(token: token, userId: user.id);
    return AuthSessionResult(user: user, token: token);
  }

  Future<AuthSessionResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final res = await _client.post(
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
        if (deviceName != null) 'deviceName': deviceName,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    final token = (data['token'] ?? res['token'] ?? '').toString();
    final user = UserProfile.fromJson(userMap);
    _client.setAuthSession(token: token, userId: user.id);
    return AuthSessionResult(user: user, token: token);
  }

  Future<UserProfile?> verifySession({String? token}) async {
    final res = await _client.get(
      '/api/auth/verify',
      queryParameters: token != null ? {'token': token} : null,
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    if (data['valid'] == false || res['valid'] == false) {
      return null;
    }
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<void> logout({bool allDevices = false}) async {
    await _client.post(
      '/api/auth/logout',
      body: {'allDevices': allDevices},
    );
    _client.clearAuthSession();
  }

  Future<UserProfile> getProfile({int? userId}) async {
    final res = await _client.get(
      '/api/auth/profile',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<UserProfile> updateProfile({
    Map<String, dynamic>? updates,
    String? displayName,
    String? email,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      if (updates != null) ...updates,
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
    final res = await _client.put('/api/auth/profile', body: body);
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<Map<String, dynamic>> getSecurityStatus({int? userId}) async {
    final res = await _client.get(
      '/api/auth/security',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    return (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
  }

  Future<UserProfile> setupPin({
    required String pin,
    String? currentPin,
    int? userId,
  }) async {
    final res = await _client.post(
      '/api/auth/pin/setup',
      body: {
        'pin': pin,
        if (currentPin != null) 'currentPin': currentPin,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<bool> verifyPin({
    required String pin,
    int? userId,
  }) async {
    try {
      final res = await _client.post(
        '/api/auth/pin/verify',
        body: {
          'pin': pin,
          if (userId != null) 'userId': userId,
        },
      );
      final data = (res['data'] is Map<String, dynamic>)
          ? res['data'] as Map<String, dynamic>
          : res;
      return data['verified'] == true || res['verified'] == true || res['success'] == true;
    } on MonetaApiException {
      return false;
    }
  }

  Future<UserProfile> disablePin({
    String? currentPin,
    int? userId,
  }) async {
    final res = await _client.delete(
      '/api/auth/pin',
      body: {
        if (currentPin != null) 'currentPin': currentPin,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<UserProfile> updateBiometric({
    required bool enabled,
    int? userId,
  }) async {
    final res = await _client.put(
      '/api/auth/biometric',
      body: {
        'enabled': enabled,
        'biometricEnabled': enabled,
        if (userId != null) 'userId': userId,
      },
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final userMap = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(userMap);
  }

  Future<UserProfile> toggleSecurity({
    bool? pinEnabled,
    String? pinCode,
    bool? biometricEnabled,
    int? userId,
  }) async {
    if (biometricEnabled != null) {
      return updateBiometric(enabled: biometricEnabled, userId: userId);
    }
    if (pinEnabled == true && pinCode != null) {
      return setupPin(pin: pinCode, userId: userId);
    }
    if (pinEnabled == false) {
      return disablePin(userId: userId);
    }
    return getProfile(userId: userId);
  }

  Future<UserProfile> getPreferences({int? userId}) async {
    final res = await _client.get(
      '/api/preferences',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final prefMap = (data['preferences'] is Map<String, dynamic>)
        ? data['preferences'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(prefMap);
  }

  Future<UserProfile> updatePreferences(Map<String, dynamic> updates) async {
    final res = await _client.put('/api/preferences', body: updates);
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final prefMap = (data['preferences'] is Map<String, dynamic>)
        ? data['preferences'] as Map<String, dynamic>
        : (data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : data);
    return UserProfile.fromJson(prefMap);
  }

  Future<UserProfile> resetPreferences({int? userId}) async {
    final res = await _client.post(
      '/api/preferences/reset',
      body: {if (userId != null) 'userId': userId},
    );
    final data = (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
    final prefMap = (data['preferences'] is Map<String, dynamic>)
        ? data['preferences'] as Map<String, dynamic>
        : data;
    return UserProfile.fromJson(prefMap);
  }

  Future<Map<String, dynamic>> getSyncSnapshot({int? userId}) async {
    final res = await _client.get(
      '/api/sync',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    return (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
  }

  Future<Map<String, dynamic>> exportData({String? format, int? userId}) =>
      getSyncSnapshot(userId: userId);

  Future<Map<String, dynamic>> pushSyncData(Map<String, dynamic> payload) async {
    final res = await _client.post('/api/sync', body: payload);
    return (res['data'] is Map<String, dynamic>)
        ? res['data'] as Map<String, dynamic>
        : res;
  }

  Future<void> clearAllUserRecords({int? userId}) async {
    await _client.delete(
      '/api/sync/clear',
      body: {
        'confirm': true,
        if (userId != null) 'userId': userId,
      },
    );
  }

  Future<void> resetData({int? userId}) => clearAllUserRecords(userId: userId);
}
