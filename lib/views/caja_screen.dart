// Nombre del archivo: caja_screen.dart

import 'package:flutter/material.dart';
import '../services/caja_service.dart';
import '../services/reportes_pdf_service.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State createState() => _CajaScreenState();
}

class _CajaScreenState extends State {
  final CajaService _cajaService = CajaService();
  final ReportesPdfService _pdfService = ReportesPdfService();

  final TextEditingController _montoInicialController = TextEditingController();
  final TextEditingController _montoFinalController = TextEditingController();

  Map? _cajaActiva;
  Map? _desgloseVentas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadoCaja();
  }

  Future _cargarEstadoCaja() async {
    setState(() => _isLoading = true);
    final caja = await _cajaService.obtenerCajaActiva() as Map?;
    Map? desglose;
    if (caja != null) {
      final int cajaId = (caja['id'] as num).toInt();
      desglose = await _cajaService.calcularDesgloseVentasSesion(cajaId) as Map?;
    }
    setState(() {
      _cajaActiva = caja;
      _desgloseVentas = desglose;
      _isLoading = false;
    });
  }

  Future _abrirCajaSesion() async {
    final double? monto = double.tryParse(_montoInicialController.text);
    if (monto == null || monto < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Ingrese un monto inicial válido')),
      );
      return;
    }
    await _cajaService.abrirCaja(monto);
    _montoInicialController.clear();
    await _cargarEstadoCaja();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('¡Caja abierta con éxito!')),
      );
    }
  }

  Future _cerrarCajaSesion() async {
    final double? montoFinal = double.tryParse(_montoFinalController.text);
    if (montoFinal == null || montoFinal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Ingrese el monto físico contado en caja')),
      );
      return;
    }
    final int cajaId = (_cajaActiva!['id'] as num).toInt();
    await _cajaService.cerrarCaja(cajaId, montoFinal);
    _montoFinalController.clear();
    await _cargarEstadoCaja();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('¡Caja cerrada y arqueo registrado!')),
      );
    }
  }

  Future _exportarReporteHoy() async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    await _pdfService.generarPdfReporteDiarioConVistaPrevia(context, hoy);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('Gestión de Caja Diaria y Arqueo'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: const Color(0xFFFFAB00),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                color: const Color(0xFF131C31),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Control de Sesión',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                      ),
                      const Divider(color: Color(0xFF1E293B)),
                      const SizedBox(height: 16),
                      _cajaActiva == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'No hay ninguna caja abierta. Ingrese el fondo inicial para comenzar el turno.',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _montoInicialController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                                  decoration: const InputDecoration(
                                    labelText: 'Monto Inicial en Efectivo (Bs.)',
                                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _abrirCajaSesion,
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('Abrir Caja'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFAB00),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.greenAccent),
                                    SizedBox(width: 8),
                                    Text('Caja Abierta y Activa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text('Fondo Inicial: Bs. ${(_cajaActiva!['monto_inicial'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFE2E8F0))),
                                const SizedBox(height: 8),
                                Text('Efectivo en Ventas: Bs. ${(_desgloseVentas!['efectivo'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFE2E8F0))),
                                const SizedBox(height: 8),
                                Text('QR / Transferencias: Bs. ${(_desgloseVentas!['qr'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFE2E8F0))),
                                const SizedBox(height: 8),
                                Text('Total Consolidado: Bs. ${(_desgloseVentas!['total'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFAB00))),
                                const Divider(color: Color(0xFF1E293B), height: 32),
                                TextField(
                                  controller: _montoFinalController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                                  decoration: const InputDecoration(
                                    labelText: 'Arqueo Físico (Efectivo Contado)',
                                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(),
                                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _cerrarCajaSesion,
                                  icon: const Icon(Icons.lock),
                                  label: const Text('Cerrar Caja y Arqueo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Card(
                color: const Color(0xFF131C31),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Reportes y Resumen Diario',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                      ),
                      const Divider(color: Color(0xFF1E293B)),
                      const SizedBox(height: 16),
                      const Text(
                        'Genera y visualiza el reporte oficial en PDF con el desglose exacto de ingresos físicos y bancarios de hoy.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _exportarReporteHoy,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Ver Vista Previa e Imprimir PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}