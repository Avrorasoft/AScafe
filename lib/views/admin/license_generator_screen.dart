// Nombre del archivo: lib/views/admin/license_generator_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

class LicenseGeneratorScreen extends StatefulWidget {
  const LicenseGeneratorScreen({super.key});

  @override
  State<LicenseGeneratorScreen> createState() => _LicenseGeneratorScreenState();
}

class _LicenseGeneratorScreenState extends State<LicenseGeneratorScreen> {
  final TextEditingController _clienteController = TextEditingController(text: 'CLIENTE PREMIUM');
  final TextEditingController _uidController = TextEditingController();
  
  // 🔑 Clave secreta estricta unificada con AScafe
  static const String _secretoLicencia = 'AvroraSoft_AScafe_Key_2026_Secure';
  
  int _diasValidez = 365;
  String _mensajeEstado = '';
  bool _esExito = false;

  @override
  void dispose() {
    _clienteController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  String _generarFirma({
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

  Future<void> _generarYGuardarLicencia() async {
    final cliente = _clienteController.text.trim().toUpperCase();
    final uid = _uidController.text.trim().toUpperCase();

    if (uid.isEmpty) {
      setState(() {
        _mensajeEstado = '❌ Error: El UID de la placa base del cliente no puede estar vacío.';
        _esExito = false;
      });
      return;
    }

    try {
      final fechaExpiracion = DateTime.now().add(Duration(days: _diasValidez));
      final expiracionIso = fechaExpiracion.toIso8601String();

      final firma = _generarFirma(
        cliente: cliente,
        uid: uid,
        expiracion: expiracionIso,
      );

      final Map<String, dynamic> datosLicencia = {
        'cliente': cliente,
        'uid': uid,
        'expiracion': expiracionIso,
        'firma': firma,
      };

      final jsonLicencia = jsonEncode(datosLicencia);

      // Diálogo moderno para seleccionar dónde guardar el archivo .av
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Archivo de Licencia AScafe',
        fileName: 'license_${cliente.replaceAll(' ', '_')}.av',
        allowedExtensions: ['av'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final archivo = File(outputFile);
        await archivo.writeAsString(jsonLicencia);

        setState(() {
          _mensajeEstado = '✅ ¡Licencia generada y firmada con éxito!\n📁 Guardado en: $outputFile';
          _esExito = true;
        });
      }
    } catch (e) {
      setState(() {
        _mensajeEstado = '❌ Error al generar la licencia: $e';
        _esExito = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('🔐 Módulo Profesional de Generación de Licencias (.av)'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFAB00), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Generador Criptográfico Avrora Soft',
                style: TextStyle(color: Color(0xFFFFAB00), fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Cree archivos .av firmados por HMAC-SHA256 vinculados al hardware del cliente.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _clienteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '👤 Nombre o Tipo de Licencia (Ej: CLIENTE VIP)',
                  labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                  filled: true,
                  fillColor: const Color(0xFF0A0F1D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _uidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '🖥️ UID de Placa Base del Cliente (Hardware ID)',
                  labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                  filled: true,
                  fillColor: const Color(0xFF0A0F1D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Text('📅 Tiempo de Validez: ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _diasValidez.toDouble(),
                      min: 30,
                      max: 730,
                      divisions: 23,
                      activeColor: const Color(0xFFFFAB00),
                      inactiveColor: Colors.white24,
                      label: '$_diasValidez días',
                      onChanged: (val) {
                        setState(() {
                          _diasValidez = val.toInt();
                        });
                      },
                    ),
                  ),
                  Text('$_diasValidez días', style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAB00),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _generarYGuardarLicencia,
                icon: const Icon(Icons.security, size: 22),
                label: const Text(
                  'GENERAR Y EXPORTAR ARCHIVO .AV',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
              if (_mensajeEstado.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _esExito ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                    border: Border.all(color: _esExito ? Colors.greenAccent : Colors.redAccent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _mensajeEstado,
                    style: TextStyle(color: _esExito ? Colors.greenAccent : Colors.redAccent, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}