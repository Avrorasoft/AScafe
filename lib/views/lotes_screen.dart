// Nombre del archivo: lotes_screen.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';

class LotesScreen extends StatefulWidget {
  final dynamic parentState;

  const LotesScreen({super.key, this.parentState});

  @override
  State<LotesScreen> createState() => _LotesScreenState();
}

class _LotesScreenState extends State<LotesScreen> {
  final DatabaseService _dbService = DatabaseService.instance;

  List _lotes = [];
  List _productos = [];
  bool _cargando = true;
  bool _soloHoy = true;
  String _filtroEstado = 'Todos'; // 'Todos', 'Disponible', 'Agotado', 'Merma'

  @override
  void initState() {
    super.initState();
    _cargarLotesYProductos();
  }

  String _obtenerEmojiProducto(String nombre) {
    final nombreLower = nombre.trim().toLowerCase();
    if (nombreLower.contains('picante')) return '🌶️';
    if (nombreLower.contains('pollo')) return '🍗';
    if (nombreLower.contains('carne') || nombreLower.contains('res') || nombreLower.contains('charque')) return '🥩';
    if (nombreLower.contains('dulce') || nombreLower.contains('hoja')) return '🍯';
    if (nombreLower.contains('queso') || nombreLower.contains('pizza') || nombreLower.contains('cuñapé')) return '🧀';
    if (nombreLower.contains('mocochinchi') || nombreLower.contains('durazno')) return '🍑';
    if (nombreLower.contains('soya') || nombreLower.contains('linaza') || nombreLower.contains('somó')) return '🌾';
    if (nombreLower.contains('api')) return '🟣';
    if (nombreLower.contains('pastel')) return '🥮';
    if (nombreLower.contains('café') || nombreLower.contains('cafe') || nombreLower.contains('capuchino')) return '☕';
    if (nombreLower.contains('refresco') || nombreLower.contains('soda') || nombreLower.contains('jugo')) return '🥤';
    if (nombreLower.contains('postre') || nombreLower.contains('torta') || nombreLower.contains('queque')) return '🍰';
    return '🥟';
  }

  Future<void> _cargarLotesYProductos() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final db = await _dbService.database;
      final prodsRaw = await _dbService.obtenerProductos();

      final List tempProds = [];
      for (final p in prodsRaw) {
        if (p is Map) {
          tempProds.add(Map<String, dynamic>.from(p));
        }
      }

      final hoy = DateTime.now().toIso8601String().split('T').first;
      final String clausulaWhere = _soloHoy ? "WHERE l.fecha = '$hoy'" : "";

      final List filasLotes = await db.rawQuery('''
        SELECT l.id, l.producto_id, l.cantidad_producida, l.cantidad_disponible,
               l.hora_salida, l.fecha, l.estado,
               COALESCE(p.nombre, 'Producto Eliminado') AS producto_nombre,
               COALESCE(p.precio, 0.0) AS precio,
               COALESCE(p.stock_actual, 0) AS stock_actual
        FROM lotes_produccion l
        LEFT JOIN productos p ON l.producto_id = p.id
        $clausulaWhere
        ORDER BY l.id DESC
      ''');

      final List tempLotes = [];
      for (final fila in filasLotes) {
        if (fila is Map) {
          tempLotes.add(Map<String, dynamic>.from(fila));
        }
      }

      if (mounted) {
        setState(() {
          _productos = tempProds;
          _lotes = tempLotes;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  int get _totalProducidoVista {
    int suma = 0;
    for (final l in _lotes) {
      if (l is Map) {
        suma += (l['cantidad_producida'] as num?)?.toInt() ?? 0;
      }
    }
    return suma;
  }

  int get _totalDisponibleVista {
    int suma = 0;
    for (final l in _lotes) {
      if (l is Map) {
        if ((l['estado']?.toString() ?? 'Disponible') != 'Merma') {
          suma += (l['cantidad_disponible'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return suma;
  }

  int get _totalVendidoLotesVista {
    int suma = 0;
    for (final l in _lotes) {
      if (l is Map) {
        final prod = (l['cantidad_producida'] as num?)?.toInt() ?? 0;
        final disp = (l['cantidad_disponible'] as num?)?.toInt() ?? 0;
        if (prod >= disp) {
          suma += (prod - disp);
        }
      }
    }
    return suma;
  }

  void _mostrarDialogoNuevoLote() {
    if (_productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ No hay productos registrados en el catálogo.'),
        ),
      );
      return;
    }

    int productoIdSeleccionado = (_productos.first['id'] as num).toInt();
    final ctrlCantidad = TextEditingController(text: '30');

    final ahora = DateTime.now();
    final horaDefecto =
        '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
    final ctrlHora = TextEditingController(text: horaDefecto);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: const Row(
                children: [
                  Text('🔥 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Registrar Nueva Tanda / Horneada',
                    style: TextStyle(
                      color: Color(0xFFFFAB00),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona el Producto salido del horno o cocina:',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFAB00)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: productoIdSeleccionado,
                          dropdownColor: const Color(0xFF131C31),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: _productos.map((p) {
                            final id = (p['id'] as num).toInt();
                            final nombre = p['nombre']?.toString() ?? 'Producto';
                            final stock = (p['stock'] as num?)?.toInt() ?? 0;
                            final em = _obtenerEmojiProducto(nombre);
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text('$em $nombre (Stock actual: $stock)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                productoIdSeleccionado = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrlCantidad,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Cantidad Producida',
                              labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: ctrlHora,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Hora de Salida (HH:MM)',
                              labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.local_fire_department, size: 18),
                  label: const Text(
                    'Registrar y Sumar al Stock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final cant = int.tryParse(ctrlCantidad.text.trim()) ?? 0;
                    if (cant <= 0) return;

                    final hora = ctrlHora.text.trim().isEmpty
                        ? horaDefecto
                        : ctrlHora.text.trim();
                    final hoy = DateTime.now().toIso8601String().split('T').first;

                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);

                    final db = await _dbService.database;

                    await db.insert('lotes_produccion', {
                      'producto_id': productoIdSeleccionado,
                      'cantidad_producida': cant,
                      'cantidad_disponible': cant,
                      'hora_salida': hora,
                      'fecha': hoy,
                      'estado': 'Disponible',
                    });

                    final List prodRows = await db.query(
                      'productos',
                      where: 'id = ?',
                      whereArgs: [productoIdSeleccionado],
                    );
                    if (prodRows.isNotEmpty) {
                      final filaProd = prodRows.first as Map;
                      final stockPrevio = (filaProd['stock_actual'] as num?)?.toInt() ?? 0;
                      await db.update(
                        'productos',
                        {'stock_actual': stockPrevio + cant},
                        where: 'id = ?',
                        whereArgs: [productoIdSeleccionado],
                      );
                    }

                    navigator.pop();
                    await _cargarLotesYProductos();

                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('🔥 Lote de +$cant unidades registrado y sumado al inventario POS.'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoAjustarLote(Map<String, dynamic> lote) {
    final int loteId = (lote['id'] as num).toInt();
    final int prodId = (lote['producto_id'] as num?)?.toInt() ?? 0;
    final String nombreProd = lote['producto_nombre']?.toString() ?? 'Producto';
    final int dispActual = (lote['cantidad_disponible'] as num?)?.toInt() ?? 0;
    final ctrlNuevaDisponible = TextEditingController(text: dispActual.toString());
    String estadoSeleccionado = lote['estado']?.toString() ?? 'Disponible';
    if (!['Disponible', 'Agotado', 'Merma'].contains(estadoSeleccionado)) {
      estadoSeleccionado = 'Disponible';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: Text(
                '⚙️ Ajustar Lote #$loteId - $nombreProd',
                style: const TextStyle(
                  color: Color(0xFFFFAB00),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: ctrlNuevaDisponible,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Cantidad Disponible en Bandeja / Lote',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF131C31),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Estado del Lote:',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFAB00)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: estadoSeleccionado,
                          dropdownColor: const Color(0xFF131C31),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'Disponible', child: Text('🟢 Disponible para Venta')),
                            DropdownMenuItem(value: 'Agotado', child: Text('⚪ Agotado')),
                            DropdownMenuItem(value: 'Merma', child: Text('🔴 Retirado por Merma / Frío')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                estadoSeleccionado = val;
                                if (val == 'Agotado' || val == 'Merma') {
                                  ctrlNuevaDisponible.text = '0';
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    final db = await _dbService.database;

                    if (dispActual > 0 && prodId > 0) {
                      final List rows = await db.query(
                        'productos',
                        where: 'id = ?',
                        whereArgs: [prodId],
                      );
                      if (rows.isNotEmpty) {
                        final fila = rows.first as Map;
                        final st = (fila['stock_actual'] as num?)?.toInt() ?? 0;
                        final nuevoSt = (st - dispActual) < 0 ? 0 : (st - dispActual);
                        await db.update(
                          'productos',
                          {'stock_actual': nuevoSt},
                          where: 'id = ?',
                          whereArgs: [prodId],
                        );
                      }
                    }

                    await db.delete('lotes_produccion', where: 'id = ?', whereArgs: [loteId]);
                    navigator.pop();
                    await _cargarLotesYProductos();

                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.redAccent,
                        content: Text('🗑️ Registro de lote eliminado y stock sincronizado.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Borrar Lote', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final nuevaDisp = int.tryParse(ctrlNuevaDisponible.text.trim()) ?? 0;
                    final diferencia = nuevaDisp - dispActual;

                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    final db = await _dbService.database;

                    final estadoFinal = nuevaDisp <= 0 && estadoSeleccionado == 'Disponible'
                        ? 'Agotado'
                        : estadoSeleccionado;

                    await db.update(
                      'lotes_produccion',
                      {
                        'cantidad_disponible': nuevaDisp < 0 ? 0 : nuevaDisp,
                        'estado': estadoFinal,
                      },
                      where: 'id = ?',
                      whereArgs: [loteId],
                    );

                    if (diferencia != 0 && prodId > 0) {
                      final List rows = await db.query(
                        'productos',
                        where: 'id = ?',
                        whereArgs: [prodId],
                      );
                      if (rows.isNotEmpty) {
                        final fila = rows.first as Map;
                        final st = (fila['stock_actual'] as num?)?.toInt() ?? 0;
                        final nuevoSt = (st + diferencia) < 0 ? 0 : (st + diferencia);
                        await db.update(
                          'productos',
                          {'stock_actual': nuevoSt},
                          where: 'id = ?',
                          whereArgs: [prodId],
                        );
                      }
                    }

                    navigator.pop();
                    await _cargarLotesYProductos();

                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✅ Lote actualizado y sincronizado con el Punto de Venta.'),
                      ),
                    );
                  },
                  child: const Text('Guardar Ajuste', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lotesFiltrados = _lotes.where((l) {
      if (l is! Map) return false;
      if (_filtroEstado == 'Todos') return true;
      final disp = (l['cantidad_disponible'] as num?)?.toInt() ?? 0;
      final est = l['estado']?.toString() ?? 'Disponible';
      if (_filtroEstado == 'Disponible') return disp > 0 && est == 'Disponible';
      if (_filtroEstado == 'Agotado') return disp <= 0 || est == 'Agotado';
      if (_filtroEstado == 'Merma') return est == 'Merma';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text('🔥 Control de Lotes de Producción y Horneado'),
        backgroundColor: const Color(0xFF0E1626),
        actions: [
          FilterChip(
            label: Text(_soloHoy ? '📅 Solo Hoy' : '📅 Todo el Historial'),
            selected: _soloHoy,
            selectedColor: const Color(0xFFFFAB00),
            backgroundColor: const Color(0xFF131C31),
            labelStyle: TextStyle(
              color: _soloHoy ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            onSelected: (val) {
              setState(() => _soloHoy = val);
              _cargarLotesYProductos();
            },
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFAB00),
              foregroundColor: Colors.black,
            ),
            onPressed: _mostrarDialogoNuevoLote,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Nueva Horneada', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            tooltip: 'Actualizar Lotes',
            onPressed: _cargarLotesYProductos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF0E1626),
            child: Row(
              children: [
                _construirTarjetaResumen(
                  titulo: 'Total Horneado',
                  valor: '$_totalProducidoVista unds',
                  icono: '🥐',
                  colorBorde: const Color(0xFFFFAB00),
                ),
                const SizedBox(width: 12),
                _construirTarjetaResumen(
                  titulo: 'Disponible en Vitrina',
                  valor: '$_totalDisponibleVista unds',
                  icono: '🟢',
                  colorBorde: Colors.greenAccent,
                ),
                const SizedBox(width: 12),
                _construirTarjetaResumen(
                  titulo: 'Despachado de Lotes',
                  valor: '$_totalVendidoLotesVista unds',
                  icono: '🛒',
                  colorBorde: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 12),
                _construirTarjetaResumen(
                  titulo: 'Tandas Registradas',
                  valor: '${_lotes.length} lotes',
                  icono: '📋',
                  colorBorde: Colors.purpleAccent,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: ['Todos', 'Disponible', 'Agotado', 'Merma'].map((est) {
                final sel = _filtroEstado == est;
                return ChoiceChip(
                  label: Text(est),
                  selected: sel,
                  selectedColor: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF131C31),
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _filtroEstado = est),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
                : lotesFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            const Text(
                              'No hay tandas de producción registradas para este filtro.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFAB00),
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _mostrarDialogoNuevoLote,
                              icon: const Icon(Icons.local_fire_department),
                              label: const Text('Registrar Primera Tanda del Día'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: lotesFiltrados.length,
                        itemBuilder: (context, index) {
                          final lote = lotesFiltrados[index];
                          final id = (lote['id'] as num).toInt();
                          final nombre = lote['producto_nombre']?.toString() ?? 'Producto';
                          final emoji = _obtenerEmojiProducto(nombre);
                          final prodCant = (lote['cantidad_producida'] as num?)?.toInt() ?? 1;
                          final dispCant = (lote['cantidad_disponible'] as num?)?.toInt() ?? 0;
                          final hora = lote['hora_salida']?.toString() ?? '--:--';
                          final fecha = lote['fecha']?.toString() ?? '';
                          final estado = lote['estado']?.toString() ?? 'Disponible';

                          final double porcentajeDisponible =
                              prodCant > 0 ? (dispCant / prodCant).clamp(0.0, 1.0) : 0.0;
                          final bool agotado = dispCant <= 0 || estado == 'Agotado';
                          final bool esMerma = estado == 'Merma';

                          return Card(
                            color: const Color(0xFF131C31),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: esMerma
                                    ? Colors.redAccent.withOpacity(0.5)
                                    : agotado
                                        ? Colors.white24
                                        : const Color(0xFFFFAB00).withOpacity(0.5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A0F1D),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Lote #$id - $nombre',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: esMerma
                                                    ? Colors.red.withOpacity(0.2)
                                                    : agotado
                                                        ? Colors.grey.withOpacity(0.2)
                                                        : Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                esMerma
                                                    ? 'MERMA'
                                                    : agotado
                                                        ? 'AGOTADO'
                                                        : 'DISPONIBLE',
                                                style: TextStyle(
                                                  color: esMerma
                                                      ? Colors.redAccent
                                                      : agotado
                                                          ? Colors.white60
                                                          : Colors.greenAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '🕒 Salida de horno: $hora  |  📅 Fecha: $fecha',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Quedan: $dispCant de $prodCant',
                                              style: const TextStyle(
                                                color: Color(0xFF00E5FF),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${(porcentajeDisponible * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: porcentajeDisponible,
                                            minHeight: 8,
                                            backgroundColor: const Color(0xFF0A0F1D),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              esMerma
                                                  ? Colors.redAccent
                                                  : porcentajeDisponible > 0.3
                                                      ? Colors.greenAccent
                                                      : Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFAB00),
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () => _mostrarDialogoAjustarLote(lote),
                                    icon: const Icon(Icons.tune, size: 16),
                                    label: const Text('Ajustar'),
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
    );
  }

  Widget _construirTarjetaResumen({
    required String titulo,
    required String valor,
    required String icono,
    required Color colorBorde,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131C31),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorBorde.withOpacity(0.5), width: 1.2),
        ),
        child: Row(
          children: [
            Text(icono, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    style: TextStyle(
                      color: colorBorde,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}