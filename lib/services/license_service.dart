// Nombre del archivo: services/license_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  static const String _secretKey = "AvroraSoft_Master_Key_2026_Secure";

  Future<String> obtenerUIDPlacaBase() async {
    try {
      if (Platform.isWindows) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        
        // Usamos systemMemoryInMegabytes que es el campo correcto de WindowsDeviceInfo
        String rawId = '${windowsInfo.computerName}-${windowsInfo.productId}-${windowsInfo.systemMemoryInMegabytes}\$AScafe2026';
        var bytes = utf8.encode(rawId);
        var digest = md5.convert(bytes);
        return digest.toString().toUpperCase();
      }
      return 'PC-GENERICA-UID';
    } catch (e) {
      return 'ERROR-UID-HW';
    }
  }

  bool validarLicenciaArchivo(String contenidoLicencia, String uidActual) {
    try {
      List<String> parts = contenidoLicencia.trim().split('.');
      if (parts.length != 2) return false;

      String datosB64 = parts[0];
      String firmaRecibida = parts[1];

      var keyBytes = utf8.encode(_secretKey);
      var bytesDatos = utf8.encode(datosB64);
      var hmacSha256 = Hmac(sha256, keyBytes);
      var digest = hmacSha256.convert(bytesDatos);
      String firmaCalculada = digest.toString();

      if (firmaCalculada.toLowerCase() != firmaRecibida.toLowerCase()) {
        return false;
      }

      String jsonString = utf8.decode(base64.decode(datosB64));
      Map<String, dynamic> payload = json.decode(jsonString);

      String uidLicencia = payload['uid_hardware']?.toString() ?? '';
      if (uidLicencia.isNotEmpty && uidLicencia != uidActual) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}