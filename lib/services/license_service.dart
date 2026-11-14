// Nombre del archivo: lib/services/license_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  // 🔑 Clave secreta compartida estricta entre AScafe y ASserial / avrora_license_manager
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

  // 🧮 Generador de Firma Criptográfica HMAC-SHA256 Clásica (Retrocompatible)
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

  // 🧮 Generador de Firma Criptográfica HMAC-SHA256 con Módulo de Contaduría
  String generarFirmaConModulos({
    required String cliente,
    required String uid,
    required String expiracion,
    required bool moduloContaduria,
  }) {
    final flagCont = moduloContaduria ? 'CONT_1' : 'CONT_0';
    final payload = '$cliente|$uid|$expiracion|$flagCont';
    final key = utf8.encode(_secretoLicencia);
    final bytes = utf8.encode(payload);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString().toUpperCase();
  }

  // 🔓 Decodifica el archivo .av (soporta JSON directo o Base64 si existiera)
  Map<String, dynamic>? _decodificarContenidoLicencia(String contenidoRaw) {
    final texto = contenidoRaw.trim();
    if (texto.isEmpty) return null;

    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      try {
        final decoded = utf8.decode(base64Decode(texto));
        return jsonDecode(decoded) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  // ✅ Validador Integral de Licencia .AV (Soporte Perpetuo, Temporal y Módulo Contaduría)
  bool validarLicenciaArchivo(String contenidoJson, String uidActual) {
    try {
      final mapa = _decodificarContenidoLicencia(contenidoJson);
      if (mapa == null) return false;

      final cliente = (mapa['cliente'] ?? mapa['cliente_negocio'] ?? '').toString().trim();
      final uidLicencia = (mapa['uid'] ?? mapa['hardware_uid'] ?? '').toString().trim();
      final expiracion = (mapa['expiracion'] ?? '').toString().trim();
      final firmaIngresada = (mapa['firma'] ?? '').toString().trim().toUpperCase();

      if (cliente.isEmpty || uidLicencia.isEmpty || expiracion.isEmpty || firmaIngresada.isEmpty) {
        return false;
      }

      // 1. Validar que el UID coincida exactamente con el hardware actual (o comodín CUALQUIER_PC)
      final uidNorm = uidLicencia.toUpperCase();
      final actualNorm = uidActual.trim().toUpperCase();
      if (uidNorm != 'CUALQUIER_PC' && uidNorm != actualNorm) {
        return false;
      }

      // 2. Validar expiración solo si NO es una licencia perpetua
      if (expiracion.toUpperCase() != 'PERPETUA') {
        final fechaExp = DateTime.parse(expiracion);
        if (DateTime.now().isAfter(fechaExp)) {
          return false;
        }
      }

      // 3. Verificar firma criptográfica HMAC-SHA256 (Con soporte para flag de Contaduría y retrocompatibilidad)
      if (mapa.containsKey('modulo_contaduria')) {
        final bool tieneContaduria = mapa['modulo_contaduria'] == true ||
            mapa['modulo_contaduria']?.toString().toLowerCase() == 'true' ||
            mapa['modulo_contaduria']?.toString() == '1';

        final firmaConModulo = generarFirmaConModulos(
          cliente: cliente,
          uid: uidLicencia,
          expiracion: expiracion,
          moduloContaduria: tieneContaduria,
        );

        if (firmaConModulo == firmaIngresada) {
          return true;
        }
      }

      // Retrocompatibilidad con licencias emitidas sin el campo modulo_contaduria en la firma
      final firmaClasica = generarFirma(
        cliente: cliente,
        uid: uidLicencia,
        expiracion: expiracion,
      );

      return firmaClasica == firmaIngresada;
    } catch (_) {
      return false;
    }
  }

  // 📊 Verifica si el archivo .AV tiene habilitado el Módulo de Contaduría
  bool licenciaIncluyeContaduria(String contenidoJson) {
    try {
      final mapa = _decodificarContenidoLicencia(contenidoJson);
      if (mapa == null) return false;
      if (!mapa.containsKey('modulo_contaduria')) {
        return false;
      }
      final val = mapa['modulo_contaduria'];
      return val == true || val.toString().toLowerCase() == 'true' || val.toString() == '1';
    } catch (_) {
      return false;
    }
  }

  // 🔍 Obtener detalles de la licencia para auditoría o UI
  Map<String, dynamic>? obtenerDetallesLicencia(String contenidoJson) {
    return _decodificarContenidoLicencia(contenidoJson);
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