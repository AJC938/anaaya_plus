import 'device_token_repository.dart';

class MockDeviceTokenRepository implements DeviceTokenRepository {
  final Map<String, String> registeredTokens = {}; // token -> platform

  @override
  Future<void> registerToken({required String token, required String platform}) async {
    registeredTokens[token] = platform;
  }

  @override
  Future<void> deleteToken(String token) async {
    registeredTokens.remove(token);
  }
}
