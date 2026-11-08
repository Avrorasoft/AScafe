// Nombre del archivo: caja_service.dart

import 'database_service.dart';

class CajaService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future obtenerCajaActiva() async {
    final db = await _dbService.database;
    final List resultado = await db.query(
      'caja_sesiones',
      where: "estado = ?",
      whereArgs: ['Abierta'],
      limit: 1,
    );
    return resultado.isNotEmpty ? resultado.first : null;
  }

  Future abrirCaja(double montoInicial) async {
    final db = await _dbService.database;
    final cajaActiva = await obtenerCajaActiva();
    if (cajaActiva != null) {
      throw Exception('Ya existe una sesión de caja abierta.');
    }

    return await db.insert('caja_sesiones', {
      'fecha_apertura': DateTime.now().toIso8601String(),
      'monto_inicial': montoInicial,
      'estado': 'Abierta',
    });
  }

  Future calcularDesgloseVentasSesion(int cajaId) async {
    final db = await _dbService.database;
    final List ventas = await db.query(
      'ventas',
      where: 'caja_id = ?',
      whereArgs: [cajaId],
    );

    double efectivo = 0.0;
    double qr = 0.0;

    for (final elemento in ventas) {
      final v = elemento as Map;
      final double monto = (v['total'] as num).toDouble();
      final String metodo = v['metodo_pago'].toString();

      if (metodo == 'Efectivo') {
        efectivo = efectivo + monto;
      } else {
        qr = qr + monto;
      }
    }

    return {
      'efectivo': efectivo,
      'qr': qr,
      'total': efectivo + qr,
    };
  }

  Future cerrarCaja(int cajaId, double montoFinalReal) async {
    final db = await _dbService.database;
    await db.update(
      'caja_sesiones',
      {
        'fecha_cierre': DateTime.now().toIso8601String(),
        'monto_final': montoFinalReal,
        'estado': 'Cerrada',
      },
      where: 'id = ?',
      whereArgs: [cajaId],
    );
  }
}