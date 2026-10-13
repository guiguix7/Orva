import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../logging/orva_diagnostics.dart';

/// Handles differences in Android's biometric enrollment APIs.
///
/// On Android versions below 10 (API 29), local_auth documents that
/// getAvailableBiometrics cannot reliably report all biometric types. In
/// that case we allow a real biometric-only attempt and rely on local_auth's
/// result; callers must retain the PIN fallback. On Android 10+ and platforms
/// where enrollment listing is reliable, a non-empty enrollment list is
/// required before enabling the biometric option.
abstract final class OrvaBiometricSupport {
  static const MethodChannel _deviceChannel =
      MethodChannel('com.appguilherme.orva/device_info');

  static Future<bool> canAuthenticate(LocalAuthentication auth) async {
    try {
      final deviceSupported = await auth.isDeviceSupported();
      if (!deviceSupported) return false;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final sdkVersion = await _androidSdkVersion();
        if (sdkVersion != null && sdkVersion < 29) {
          // The actual authenticate(biometricOnly: true) call verifies that
          // biometric hardware and an enrolled biometric are usable.
          return true;
        }
      }

      if (!await auth.canCheckBiometrics) return false;
      return (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'biometric-capability',
        module: 'security',
        severity: DiagnosticSeverity.warning,
      );
      return false;
    }
  }

  static Future<int?> _androidSdkVersion() async {
    try {
      return await _deviceChannel.invokeMethod<int>('androidSdkVersion');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
