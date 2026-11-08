// Nombre del folder y archivo: lib/services/thermal_printer_service.dart

import 'dart:developer';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ThermalPrinterService {
  Future printReceipt({
    required String ticketNumber,
    required List items,
    required double total,
    required String metodoPago,
  }) async {
    try {
      final doc = pw.Document();

      const rollFormat = PdfPageFormat(
        80 * PdfPageFormat.mm,
        200 * PdfPageFormat.mm,
        marginAll: 5 * PdfPageFormat.mm,
      );

      final List filasProductos = [];
      for (final elemento in items) {
        final item = elemento as Map;
        final int qty = (item['quantity'] as num).toInt();
        final String name = item['name'].toString();
        final double price = (item['price'] as num).toDouble();
        final double subtotal = qty * price;

        filasProductos.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text('$qty x $name', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Text('Bs. ${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        );
      }

      final ahora = DateTime.now();
      final fechaHoraFormateada = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}';

      doc.addPage(
        pw.Page(
          pageFormat: rollFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'SALTEÑERÍA "EL BUEN SABOR"',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Center(
                  child: pw.Text('Riberalta - Beni - Bolivia', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Ticket: $ticketNumber', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Fecha/Hora: $fechaHoraFormateada', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Pago: $metodoPago', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Cant / Producto',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(
                      'Subtotal',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                ...filasProductos.cast(),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.Text(
                      'Bs. ${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    '¡Gracias por su compra!',
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Ticket_$ticketNumber',
        usePrinterSettings: true,
      );

      return true;
    } catch (e) {
      log('Error al imprimir el recibo: $e');
      return false;
    }
  }
}