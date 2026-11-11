// Nombre del archivo: lib/keygen.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

// 🔑 Clave secreta compartida estricta (debe ser idéntica a la de AScafe)
const String _secretoLicencia = 'AvroraSoft_AScafe_Key_2026_Secure';

void main() {
  // 1. Datos iniciales de la licencia
  String cliente = 'PREMIUM';
  
  stdout.write('Ingrese el UID de la Placa Base del cliente: ');
  String uid = stdin.readLineSync()?.trim().toUpperCase() ?? '';
  
  if (uid.isEmpty) {
    stderr.writeln('Error: El UID no puede estar vacío.');
    return;
  }

  // Definir fecha de expiración (1 año a partir de hoy)
  DateTime fechaExpiracion = DateTime.now().add(const Duration(days: 365));
  String expiracionIso = fechaExpiracion.toIso8601String();

  // 2. Calcular la firma criptográfica HMAC-SHA256
  String firma = generarFirma(
    cliente: cliente,
    uid: uid,
    expiracion: expiracionIso,
  );

  // 3. Construir el mapa de la licencia
  final Map<String, dynamic> datosLicencia = {
    'cliente': cliente,
    'uid': uid,
    'expiracion': expiracionIso,
    'firma': firma,
  };

  // 4. Convertir a JSON
  String jsonLicencia = jsonEncode(datosLicencia);

  // 5. Guardar el archivo license.av
  try {
    final archivo = File('license.av');
    archivo.writeAsStringSync(jsonLicencia);
    
    stdout.writeln('¡Licencia generada con éxito!');
    stdout.writeln('Archivo guardado como: license.av en la ruta actual.');
  } catch (e) {
    stderr.writeln('Error al guardar el archivo de licencia: $e');
  }
}

// 🧮 Función de firma idéntica a la de AScafe
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