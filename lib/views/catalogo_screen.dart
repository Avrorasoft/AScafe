// Nombre del archivo: catalogo_screen.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State {
  final DatabaseService _dbService = DatabaseService.instance;
  List _productos = [];
  List _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future _cargarDatos() async {
    setState(() => _isLoading = true);
    final db = await _dbService.database;
    final List prods = await db.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre 
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      ORDER BY p.id ASC
    ''');
    final List cats = await db.query('categorias');

    setState(() {
      _productos = prods;
      _categorias = cats;
      _isLoading = false;
    });
  }

  void _mostrarFormularioProducto({Map? productoExistente}) {
    final TextEditingController nombreController = TextEditingController(
      text: productoExistente != null ? productoExistente['nombre'].toString() : '',
    );
    final TextEditingController precioController = TextEditingController(
      text: productoExistente != null ? productoExistente['precio'].toString() : '',
    );

    int? categoriaIdSeleccionada = productoExistente != null
        ? productoExistente['categoria_id'] as int?
        : (_categorias.isNotEmpty ? (_categorias.first as Map)['id'] as int : null);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131C31),
          title: Text(
            productoExistente == null ? 'Nuevo Producto / Ítem' : 'Editar Producto',
            style: const TextStyle(color: Color(0xFFF8FAFC)),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                  decoration: const InputDecoration(
                    labelText: 'Precio (Bs.)',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField(
                  value: categoriaIdSeleccionada,
                  dropdownColor: const Color(0xFF131C31),
                  style: const TextStyle(color: Color(0xFFF8FAFC)),
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  items: _categorias.map((cat) {
                    final c = cat as Map;
                    return DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['nombre'].toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    categoriaIdSeleccionada = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final String nombre = nombreController.text.trim();
                final double? precio = double.tryParse(precioController.text);

                if (nombre.isEmpty || precio == null || categoriaIdSeleccionada == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(backgroundColor: Colors.redAccent, content: Text('Complete todos los campos correctamente')),
                  );
                  return;
                }

                final db = await _dbService.database;
                if (productoExistente == null) {
                  await db.insert('productos', {
                    'categoria_id': categoriaIdSeleccionada,
                    'nombre': nombre,
                    'precio': precio,
                    'stock_actual': 100,
                  });
                } else {
                  await db.update(
                    'productos',
                    {
                      'categoria_id': categoriaIdSeleccionada,
                      'nombre': nombre,
                      'precio': precio,
                    },
                    where: 'id = ?',
                    whereArgs: [productoExistente['id']],
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _cargarDatos();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('¡Catálogo actualizado con éxito!')),
                );
              },
              child: Text(productoExistente == null ? 'Guardar' : 'Actualizar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('Gestión de Catálogo y Precios'),
        backgroundColor: const Color(0xFF0E1626),
        foregroundColor: const Color(0xFFFF5722),
        actions: [
          IconButton(
            onPressed: () => _mostrarFormularioProducto(),
            icon: const Icon(Icons.add_circle, size: 28),
            tooltip: 'Nuevo Producto',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          color: const Color(0xFF131C31),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lista de Productos Registrados',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _mostrarFormularioProducto(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Producto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 24),
                Expanded(
                  child: _productos.isEmpty
                      ? const Center(child: Text('No hay productos en el catálogo.', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.builder(
                          itemCount: _productos.length,
                          itemBuilder: (context, index) {
                            final p = _productos[index] as Map;
                            return Card(
                              color: const Color(0xFF1C2841),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.fastfood, color: Color(0xFFFF5722)),
                                title: Text(
                                  p['nombre'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                                ),
                                subtitle: Text(
                                  'Categoría: ${p['categoria_nombre'] ?? 'General'}',
                                  style: const TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Bs. ${(p['precio'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5722),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF00E5FF)),
                                      onPressed: () => _mostrarFormularioProducto(productoExistente: p),
                                      tooltip: 'Editar producto',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}