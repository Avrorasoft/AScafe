// Nombre del archivo: views/activacion_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/license_service.dart';
import '../services/database_service.dart';

class ActivacionScreen extends StatefulWidget {
  final VoidCallback onLicenciaAceptada;

  const ActivacionScreen({super.key, required this.onLicenciaAceptada});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  String _uidHardware = 'Leyendo hardware...';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarUID();
  }

  Future<void> _cargarUID() async {
    String uid = await LicenseService.instance.obtenerUIDPlacaBase();
    setState(() {
      _uidHardware = uid;
      _cargando = false;
    });
  }

  Future<void> _enviarWhatsApp() async {
    const String telefonoEmpresa = '59170000000';
    String mensaje = Uri.encodeComponent(
      'Hola, necesito activar el sistema AScafe para mi PC.\nMi UID de placa base es: *$_uidHardware*'
    );
    
    final Uri url = Uri.parse('https://wa.me/$telefonoEmpresa?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _importarArchivoLicencia() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['av'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        File archivo = File(filePath);
        String contenidoLicencia = await archivo.readAsString();

        bool esValida = LicenseService.instance.validarLicenciaArchivo(contenidoLicencia, _uidHardware);

        if (esValida) {
          await DatabaseService.instance.guardarConfiguracionNegocio({
            'serial_activacion': contenidoLicencia.trim(),
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('✅ ¡Licencia .av importada y activada con éxito!'),
            ),
          );
          widget.onLicenciaAceptada();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('❌ El archivo de licencia no es válido o pertenece a otra PC.'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al procesar el archivo de licencia: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFAB00), width: 1.5),
          ),
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('🔒 Activación de Licencia AScafe', style: TextStyle(color: Color(0xFFFFAB00), fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                      'Este software está vinculado a la placa base de esta PC.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Text('UID de la Placa Base (Hardware ID):', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_uidHardware, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2)),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Color(0xFFFFAB00), size: 20),
                            tooltip: 'Copiar UID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _uidHardware));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID copiado al portapapeles')));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: _enviarWhatsApp,
                      icon: const Icon(Icons.chat),
                      label: const Text('Enviar UID por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(color: Colors.white24, height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: _importarArchivoLicencia,
                      icon: const Icon(Icons.folder_open, size: 20),
                      label: const Text('Importar Archivo de Licencia (.av)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}