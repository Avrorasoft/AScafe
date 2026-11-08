// Nombre del archivo: reportes_pdf_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_service.dart';

class ReportesPdfService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future _obtenerDatosReporteDia(String fecha) async {
    final db = await _dbService.database;

    final List ventas = await db.rawQuery('''
      SELECT _v.*, c.monto_inicial 
      FROM ventas _v
      LEFT JOIN caja_sesiones c ON _v.caja_id = c.id
      WHERE DATE(_v.fecha) = ?
    ''', [fecha]);

    double totalEfectivo = 0.0;
    double totalQr = 0.0;

    for (final elemento in ventas) {
      final v = elemento as Map;
      final double monto = (v['total'] as num).toDouble();
      final String metodo = v['metodo_pago'].toString();

      if (metodo == 'Efectivo') {
        totalEfectivo = totalEfectivo + monto;
      } else {
        totalQr = totalQr + monto;
      }
    }

    return {
      'fecha': fecha,
      'ventas': ventas,
      'totalEfectivo': totalEfectivo,
      'totalQr': totalQr,
      'totalGeneral': totalEfectivo + totalQr,
    };
  }

  Future generarPdfReporteDiarioConVistaPrevia(androidContext, String fecha) async {
    final Map datos = await _obtenerDatosReporteDia(fecha) as Map;
    final List ventas = datos['ventas'] as List;
    final double totalEfectivo = (datos['totalEfectivo'] as num).toDouble();
    final double totalQr = (datos['totalQr'] as num).toDouble();
    final double totalGeneral = (datos['totalGeneral'] as num).toDouble();

    final pdf = pw.Document();

    final List datosTabla = [];
    for (final elemento in ventas) {
      final v = elemento as Map;
      final fechaHora = v['fecha'].toString();
      final hora = fechaHora.contains('T')
          ? fechaHora.split('T')[1].substring(0, 8)
          : fechaHora;
      datosTabla.add([
        '#${v['id']}',
        hora,
        v['metodo_pago'].toString(),
        (v['total'] as num).toStringAsFixed(2),
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SALTEÑERÍA "EL BUEN SABOR"',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Reporte Diario de Ventas y Arqueo Financiero'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Desarrollado por: Avrora Soft - Vibola LLC',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Fecha: $fecha',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Generado: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 2, height: 20),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Ingreso Físico (Efectivo)', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Bs. ${totalEfectivo.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Ingreso Bancario (QR)', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Bs. ${totalQr.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber100,
                      border: pw.Border.all(color: PdfColors.amber700),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Total Consolidado', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Bs. ${totalGeneral.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Detalle de Transacciones',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ventas.isEmpty
                  ? pw.Center(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Text('No se registraron ventas en esta fecha.'),
                      ),
                    )
                  : pw.Expanded(
                      child: pw.TableHelper.fromTextArray(
                        headers: ['ID Venta', 'Hora', 'Método de Pago', 'Total (Bs.)'],
                        data: datosTabla.cast(),
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.amber300),
                        cellAlignment: pw.Alignment.centerLeft,
                        cellAlignments: {3: pw.Alignment.centerRight},
                        cellStyle: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL GENERAL: Bs. ${totalGeneral.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Ventas_$fecha.pdf',
    );
  }
}