// Nombre del archivo: reportes_screen.dart

import 'package:flutter/material.dart';
import '../services/reportes_pdf_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State {
  final ReportesPdfService _pdfService = ReportesPdfService();
  bool _generando = false;

  Future _exportarReporteHoy() async {
    setState(() => _generando = true);
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      await _pdfService.generarPdfReporteDiarioConVistaPrevia(context, hoy);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Vista Previa PDF'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.picture_as_pdf, size: 56, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Generar Reporte Diario con Vista Previa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Visualiza y exporta el desglose financiero (Efectivo vs QR) y transacciones del día.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _generando ? null : _exportarReporteHoy,
                    icon: const Icon(Icons.preview),
                    label: Text(_generando ? 'Generando...' : 'Ver Vista Previa e Imprimir PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}