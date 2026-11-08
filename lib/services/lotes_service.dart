// Nombre del archivo: lotes_service.dart

import 'database_service.dart';

class LotesService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future registrarLote({
    required int productoId,
    required int cantidadProducida,
    required String horaSalida,
    required String fecha,
  }) async {
    final db = await _dbService.database;
    return await db.insert('lotes_produccion', {
      'producto_id': productoId,
      'cantidad_producida': cantidadProducida,
      'cantidad_disponible': cantidadProducida,
      'hora_salida': horaSalida,
      'fecha': fecha,
      'estado': 'Disponible',
    });
  }

  Future obtenerLotesActivos(String fecha) async {
    final db = await _dbService.database;
    return await db.rawQuery('''
      SELECT l.*, p.nombre as producto_nombre 
      FROM lotes_produccion l
      INNER JOIN productos p ON l.producto_id = p.id
      WHERE l.fecha = ? AND l.cantidad_disponible > 0
      ORDER BY l.hora_salida ASC
    ''', [fecha]);
  }
}