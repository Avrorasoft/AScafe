// Nombre del archivo: services/license_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  // 🔑 Clave secreta compartida estricta entre AScafe y avrora_license_manager
  static const String _secretoLicencia = 'AvroraSoft_AScafe_Key_2026_Secure';

  // 🖥️ Obtener UID único de la Placa Base / Hardware de Windows
  Future<String> obtenerUIDPlacaBase() async {
    try {
      if (Platform.isWindows) {
        final deviceInfo = DeviceInfoPlugin();
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId.replaceAll(RegExp(r'[{}]'), '').toUpperCase();
      }
      return 'WINDOWS-DEFAULT-UID';
    } catch (_) {
      return '56C58ECF-C4D6-4343-8FB3-CDF1327A1C8F';
    }
  }

  // 🧮 Generador de Firma Criptográfica HMAC-SHA256
  String generarFirma({
    required String cliente,
    required String uid,
    required String expiracion,
  }) {
    final payload = '$cliente|$uid|$expiracion';
    final key = utf8.encode(_secretoLicencia);
    final bytes = utf8.encode(payload);
    
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return digest.toString().toUpperCase();
  }

  // ✅ Validador Integral de Licencia .AV (Soporte Perpetuo y Temporal)
  bool validarLicenciaArchivo(String contenidoJson, String uidActual) {
    try {
      if (contenidoJson.trim().isEmpty) return false;

      final mapa = jsonDecode(contenidoJson) as Map<String, dynamic>;
      final cliente = mapa['cliente']?.toString() ?? '';
      final uidLicencia = mapa['uid']?.toString() ?? '';
      final expiracion = mapa['expiracion']?.toString() ?? '';
      final firmaIngresada = mapa['firma']?.toString() ?? '';

      // 1. Validar que el UID coincida exactamente con el hardware actual
      if (uidLicencia.trim().toUpperCase() != uidActual.trim().toUpperCase()) {
        return false;
      }

      // 2. Validar expiración solo si NO es una licencia perpetua
      if (expiracion.toUpperCase() != 'PERPETUA') {
        final fechaExp = DateTime.parse(expiracion);
        if (DateTime.now().isAfter(fechaExp)) {
          return false;
        }
      }

      // 3. Recalcular y verificar la firma criptográfica HMAC-SHA256
      final firmaCalculada = generarFirma(
        cliente: cliente,
        uid: uidLicencia,
        expiracion: expiracion,
      );

      return firmaCalculada == firmaIngresada;
    } catch (_) {
      return false;
    }
  }

  // 🔍 Obtener detalles de la licencia para auditoría o UI
  Map<String, dynamic>? obtenerDetallesLicencia(String contenidoJson) {
    try {
      if (contenidoJson.trim().isEmpty) return null;
      return jsonDecode(contenidoJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ⏳ Calcular días restantes (Retorna 99999 si es perpetua)
  int calcularDiasRestantes(String expiracionIso) {
    try {
      if (expiracionIso.toUpperCase() == 'PERPETUA') return 99999;
      final fechaExp = DateTime.parse(expiracionIso);
      final diferencia = fechaExp.difference(DateTime.now());
      return diferencia.inDays;
    } catch (_) {
      return 0;
    }
  }
}