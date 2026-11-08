// Nombre del archivo: producto_model.dart

class Producto {
  final int? id;
  final int categoriaId;
  final String nombre;
  final double precio;
  final int stockActual;

  Producto({
    this.id,
    required this.categoriaId,
    required this.nombre,
    required this.precio,
    this.stockActual = 0,
  });

  Map toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'precio': precio,
      'stock_actual': stockActual,
    };
  }

  factory Producto.fromMap(Map map) {
    return Producto(
      id: map['id'] as int?,
      categoriaId: (map['categoria_id'] as num).toInt(),
      nombre: map['nombre'].toString(),
      precio: (map['precio'] as num).toDouble(),
      stockActual: map['stock_actual'] != null ? (map['stock_actual'] as num).toInt() : 0,
    );
  }
}