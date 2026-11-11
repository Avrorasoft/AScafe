// Archivo: lib/keygen_screen.dart (Utilidad Keygen para Avrora Soft)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

void main() {
runApp(const AvroraKeygenApp());
}

class AvroraKeygenApp extends StatelessWidget {
const AvroraKeygenApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'Avrora Soft - License Keygen',
debugShowCheckedModeBanner: false,
theme: ThemeData.dark().copyWith(
scaffoldBackgroundColor: const Color(0xFF0A0F1D),
primaryColor: const Color(0xFFFFAB00),
),
home: const KeygenScreen(),
);
}
}

class KeygenScreen extends StatefulWidget {
const KeygenScreen({super.key});

@override
State createState() => _KeygenScreenState();
}

class _KeygenScreenState extends State {
final TextEditingController _ctrlUid = TextEditingController();
final TextEditingController _ctrlCliente = TextEditingController();
final TextEditingController _ctrlDias = TextEditingController(text: '365');

String _serialGenerado = '';
String _estadoLicencia = '';

static const String _secretSalt = 'AVRORA_SOFT_VIBOLA_SECURE_SALT_2026';

void _generarLicencia() {
final uid = _ctrlUid.text.trim();
final cliente = _ctrlCliente.text.trim();
final dias = int.tryParse(_ctrlDias.text.trim()) ?? 365;

if (uid.isEmpty) {
  setState(() {
    _estadoLicencia = '⚠️ Por favor, ingrese el UID de la placa base del cliente.';
    _serialGenerado = '';
  });
  return;
}

final fechaExpiracion = DateTime.now().add(Duration(days: dias)).toIso8601String();

final rawData = '$uid\vert{}$cliente|$fechaExpiracion\vert{}$_secretSalt';
final bytes = utf8.encode(rawData);
final digest = sha256.convert(bytes);
final firma = digest.toString().toUpperCase();

final Map<String, dynamic> payloadLicencia = {
  'cliente': cliente.isEmpty ? 'Cliente Autorizado' : cliente,
  'uid': uid,
  'expiracion': fechaExpiracion,
  'firma': firma,
};

final jsonString = jsonEncode(payloadLicencia);
final base64Serial = base64Encode(utf8.encode(jsonString));

setState(() {
  _serialGenerado = base64Serial;
  _estadoLicencia = '✨ Licencia generada con éxito (Válida por $dias días).';
});


}

Future _guardarArchivoLicencia() async {
if (_serialGenerado.isEmpty) return;

try {
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo de licencia',
    fileName: 'license.av',
    allowedExtensions: ['av'],
    type: FileType.custom,
  );

  if (outputFile != null) {
    final file = File(outputFile);
    await file.writeAsString(_serialGenerado);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('✅ Archivo license.av guardado correctamente en: $outputFile'),
      ),
    );
  }
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.redAccent,
      content: Text('❌ Error al guardar el archivo: $e'),
    ),
  );
}


}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
backgroundColor: const Color(0xFF0E1626),
title: const Text(
'🔑 Avrora Soft - Keygen & License Generator (.av)',
style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
),
),
body: Padding(
padding: const EdgeInsets.all(20.0),
key: const Key('keygen_body'),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Generador oficial de licencias para sistemas de escritorio (AScafe, ASestud, etc.)',
style: TextStyle(color: Colors.grey, fontSize: 13),
),
const SizedBox(height: 20),
TextField(
controller: _ctrlUid,
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
decoration: InputDecoration(
labelText: '💻 UID de Hardware del Cliente (Placa Base / CPU)',
labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
filled: true,
fillColor: const Color(0xFF131C31),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
),
const SizedBox(height: 12),
Row(
children: [
Expanded(
flex: 3,
child: TextField(
controller: _ctrlCliente,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
labelText: '👤 Nombre del Cliente / Establecimiento',
labelStyle: const TextStyle(color: Colors.white70),
filled: true,
fillColor: const Color(0xFF131C31),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
),
),
const SizedBox(width: 12),
Expanded(
flex: 1,
child: TextField(
controller: _ctrlDias,
keyboardType: TextInputType.number,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
labelText: '⏳ Días de Vigencia',
labelStyle: const TextStyle(color: Colors.orangeAccent),
filled: true,
fillColor: const Color(0xFF131C31),
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
),
),
],
),
const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 48,
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFFFFAB00),
foregroundColor: Colors.black,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
onPressed: _generarLicencia,
icon: const Icon(Icons.vpn_key),
label: const Text('GENERAR SERIAL Y ARCHIVO .AV', style: TextStyle(fontWeight: FontWeight.bold)),
),
),
const SizedBox(height: 20),
if (_estadoLicencia.isNotEmpty)
Text(_estadoLicencia, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
const Text('Serial / Token Base64 para activación manual:', style: TextStyle(color: Colors.white70, fontSize: 12)),
const SizedBox(height: 6),
Expanded(
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: const Color(0xFF131C31),
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.white24),
),
child: SingleChildScrollView(
child: SelectableText(
_serialGenerado.isEmpty ? 'Genera una licencia para ver el código aquí...' : _serialGenerado,
style: TextStyle(color: _serialGenerado.isEmpty ? Colors.grey : const Color(0xFF00E5FF), fontFamily: 'Courier', fontSize: 13),
),
),
),
),
const SizedBox(height: 14),
SizedBox(
width: double.infinity,
height: 46,
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF00E5FF),
foregroundColor: Colors.black,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
onPressed: _serialGenerado.isEmpty ? null : _guardarArchivoLicencia,
icon: const Icon(Icons.save_alt),
label: const Text('GUARDAR COMO ARCHIVO license.av', style: TextStyle(fontWeight: FontWeight.bold)),
),
),
],
),
),
);
}
}