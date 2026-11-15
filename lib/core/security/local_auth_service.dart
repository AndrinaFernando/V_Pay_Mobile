import 'package:local_auth/local_auth.dart';

class LocalAuthService {
  LocalAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isAvailable() async {
    try {
      return await _localAuthentication.isDeviceSupported();
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateForAppAccess() {
    return _authenticate(
      'Authenticate to access VPay',
      persistAcrossBackgrounding: true,
    );
  }

  Future<bool> authenticateForSensitiveAction({required String reason}) {
    return _authenticate(reason);
  }

  Future<bool> _authenticate(
    String reason, {
    bool persistAcrossBackgrounding = false,
  }) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
