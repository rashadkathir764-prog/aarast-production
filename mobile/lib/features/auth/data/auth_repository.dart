import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/auth_response.dart';
import '../models/safe_user.dart';

class AuthRepository {
  const AuthRepository(this._apiClient, this._authStorage);

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/auth/login', {
      'phone': phone,
      'password': password,
    });
    final response = AuthResponse.fromJson(json);
    await _authStorage.saveSession(
      accessToken: response.accessToken,
      user: response.user,
    );
    return response;
  }

  Future<AuthResponse> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    final json = await _apiClient.postJson('/auth/register', {
      'name': name,
      'phone': phone,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'password': password,
    });
    final response = AuthResponse.fromJson(json);
    await _authStorage.saveSession(
      accessToken: response.accessToken,
      user: response.user,
    );
    return response;
  }

  Future<SafeUser> me() async {
    final json = await _apiClient.getJson('/auth/me');
    final user = SafeUser.fromJson(json);
    await _authStorage.saveUser(user);
    return user;
  }

  Future<String?> readAccessToken() => _authStorage.readAccessToken();

  SafeUser? readCachedUser() => _authStorage.readUser();

  Future<void> logout() => _authStorage.clear();
}
