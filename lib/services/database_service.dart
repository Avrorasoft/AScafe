// Nombre del archivo: lib/services/database_service.dart
import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future get database async {
    if (_database != null) return _database!;
    _database = await _initDB('salteceria.db');
    return _database!;
  }

  Future _initDB(String filePath) async {
    final directorioDocs = await getApplicationDocumentsDirectory();
    final rutaDirectorio = join(directorioDocs.path, 'AScafe_Data');

    await Directory(rutaDirectorio).create(recursive: true);

    final path = join(rutaDirectorio, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion_negocio (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        password TEXT NOT NULL,
        rol TEXT NOT NULL,
        nombre_caja TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        stock_actual INTEGER NOT NULL DEFAULT 0,
        categoria TEXT DEFAULT 'General',
        imagen_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL NOT NULL,
        fecha TEXT NOT NULL,
        usuario_id INTEGER,
        caja_id INTEGER,
        metodo_pago TEXT,
        cajero_nombre TEXT,
        nombre_caja TEXT,
        cliente_nombre TEXT,
        nit_ci TEXT,
        monto_recibido REAL,
        cambio REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_sesiones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cajero_nombre TEXT,
        nombre_caja TEXT,
        fecha_apertura TEXT,
        fecha_cierre TEXT,
        monto_inicial REAL,
        monto_final REAL,
        estado TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER,
        producto_nombre TEXT,
        nombre_producto TEXT,
        categoria TEXT,
        cantidad INTEGER DEFAULT 0,
        cantidad_producida INTEGER DEFAULT 0,
        merma INTEGER DEFAULT 0,
        estado TEXT DEFAULT 'En Horno',
        fecha TEXT,
        fecha_hora TEXT,
        cajero_nombre TEXT,
        responsable TEXT,
        observaciones TEXT,
        notas TEXT
      )
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO usuarios (id, nombre, password, rol, nombre_caja)
      VALUES (1, 'Administrador', 'admin123', 'admin', 'Caja 1 - Principal')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO configuracion_negocio (clave, valor)
      VALUES ('nombre_negocio', 'AScafe')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO configuracion_negocio (clave, valor)
      VALUES ('direccion_negocio', 'Riberalta, Beni - Bolivia')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO configuracion_negocio (clave, valor)
      VALUES ('celular_negocio', '+591 70000000')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO configuracion_negocio (clave, valor)
      VALUES ('logo_path', '')
    ''');

    var categoriasDefault = ['Bebidas', 'Horneados', 'Combos', 'Postres', 'General'];
    for (var cat in categoriasDefault) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO categorias (nombre) VALUES (?)',
        [cat],
      );
    }

    var demoProductos = [
      <String, dynamic>{'nombre': 'Café Americano Caliente', 'categoria': 'Bebidas', 'categoria_id': 1, 'precio': 10.0, 'stock': 50, 'stock_actual': 50},
      <String, dynamic>{'nombre': 'Jugo Natural de Naranja', 'categoria': 'Bebidas', 'categoria_id': 1, 'precio': 15.0, 'stock': 40, 'stock_actual': 40},
      <String, dynamic>{'nombre': 'Refresco Tradicional Mocochinchi', 'categoria': 'Bebidas', 'categoria_id': 1, 'precio': 8.0, 'stock': 60, 'stock_actual': 60},
      <String, dynamic>{'nombre': 'Empanada de Pollo Especial', 'categoria': 'Horneados', 'categoria_id': 2, 'precio': 12.0, 'stock': 30, 'stock_actual': 30},
      <String, dynamic>{'nombre': 'Empanada de Carne Picante', 'categoria': 'Horneados', 'categoria_id': 2, 'precio': 12.0, 'stock': 25, 'stock_actual': 25},
      <String, dynamic>{'nombre': 'Cuñapé Tradicional con Queso', 'categoria': 'Horneados', 'categoria_id': 2, 'precio': 7.0, 'stock': 80, 'stock_actual': 80},
      <String, dynamic>{'nombre': 'Combo Ejecutivo Familiar', 'categoria': 'Combos', 'categoria_id': 3, 'precio': 45.0, 'stock': 15, 'stock_actual': 15},
      <String, dynamic>{'nombre': 'Torta Húmeda de Chocolate', 'categoria': 'Postres', 'categoria_id': 4, 'precio': 18.0, 'stock': 10, 'stock_actual': 10},
    ];

    for (var prod in demoProductos) {
      await db.insert(
        'productos',
        prod,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future obtenerConfiguracionNegocio() async {
    final Database db = await instance.database;
    final List resultado = await db.query('configuracion_negocio');
    final Map config = <String, String>{
      'nombre_negocio': 'AScafe',
      'direccion_negocio': 'Riberalta, Beni - Bolivia',
      'celular_negocio': '+591 70000000',
      'logo_path': '',
    };
    for (final row in resultado) {
      if (row is Map) {
        final String k = row['clave']?.toString() ?? '';
        final String v = row['valor']?.toString() ?? '';
        if (k.isNotEmpty) {
          config[k] = v;
        }
      }
    }
    return config.cast();
  }

  Future guardarConfiguracionNegocio(Map valores) async {
    final Database db = await instance.database;
    for (final entry in valores.entries) {
      await db.insert(
        'configuracion_negocio',
        {
          'clave': entry.key.toString(),
          'valor': entry.value?.toString() ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future obtenerUsuarios() async {
    final Database db = await instance.database;
    return await db.query('usuarios');
  }

  Future autenticarUsuario(String nombre, String password) async {
    final Database db = await instance.database;
    final List resultado = await db.query(
      'usuarios',
      where: 'nombre = ? AND password = ?',
      whereArgs: [nombre, password],
    );
    if (resultado.isNotEmpty) {
      return Map.from(resultado.first as Map);
    }
    return null;
  }

  Future crearActualizarUsuario({
    int? id,
    required String nombre,
    required String password,
    required String rol,
    required String nombreCaja,
  }) async {
    final Database db = await instance.database;
    if (id == null) {
      await db.insert('usuarios', {
        'nombre': nombre,
        'password': password,
        'rol': rol,
        'nombre_caja': nombreCaja,
      });
    } else {
      await db.update(
        'usuarios',
        {
          'nombre': nombre,
          'password': password,
          'rol': rol,
          'nombre_caja': nombreCaja,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future eliminarUsuario(int id) async {
    final Database db = await instance.database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  Future obtenerCategorias() async {
    final Database db = await instance.database;
    try {
      final List res = await db.query('categorias');
      final List lista = [];
      for (final r in res) {
        if (r is Map && r['nombre'] != null) {
          lista.add(r['nombre'].toString());
        }
      }
      if (lista.isEmpty) {
        return ['General'].cast();
      }
      return lista.cast();
    } catch (_) {
      return ['General'].cast();
    }
  }

  Future insertarCategoria(String nombre) async {
    final Database db = await instance.database;
    final List existing = await db.query(
      'categorias',
      where: 'nombre = ?',
      whereArgs: [nombre],
    );
    if (existing.isEmpty) {
      await db.insert('categorias', {'nombre': nombre});
    }
  }

  Future eliminarCategoriaDB(dynamic cat) async {
    final Database db = await instance.database;
    if (cat is int) {
      await db.delete('categorias', where: 'id = ?', whereArgs: [cat]);
    } else {
      await db.delete('categorias', where: 'nombre = ?', whereArgs: [cat.toString()]);
    }
  }

  Future obtenerProductos() async {
    final Database db = await instance.database;
    try {
      final List rows = await db.query('productos');
      final List cats = await db.query('categorias');
      final Map mapaCats = {};
      for (final c in cats) {
        if (c is Map && c['id'] != null) {
          mapaCats[(c['id'] as num).toInt()] = c['nombre']?.toString() ?? 'General';
        }
      }

      final List resultado = [];
      for (final r in rows) {
        if (r is Map) {
          final Map m = Map.from(r);
          final int st = (m['stock_actual'] as num?)?.toInt() ?? (m['stock'] as num?)?.toInt() ?? 0;
          m['stock'] = st;
          m['stock_actual'] = st;

          String catNombre = m['categoria']?.toString() ?? '';
          if (catNombre.isEmpty && m['categoria_id'] != null) {
            final int cid = (m['categoria_id'] as num).toInt();
            catNombre = mapaCats[cid]?.toString() ?? 'General';
          }
          if (catNombre.isEmpty) {
            catNombre = 'General';
          }
          m['categoria'] = catNombre;
          resultado.add(m);
        }
      }
      return resultado;
    } catch (_) {
      return [];
    }
  }

  Future insertarProducto({
    required String nombre,
    required double precio,
    required int stock,
    int? categoriaId,
    String? categoria,
    String? imagenPath,
  }) async {
    final Database db = await instance.database;
    await db.insert('productos', {
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'stock_actual': stock,
      'categoria_id': categoriaId ?? 1,
      'categoria': categoria ?? 'General',
      'imagen_path': imagenPath,
    });
  }

  Future actualizarProducto(
    int id,
    double precio,
    int stock,
    String categoria,
  ) async {
    final Database db = await instance.database;
    await insertarCategoria(categoria);
    final List catRows = await db.query(
      'categorias',
      where: 'nombre = ?',
      whereArgs: [categoria],
    );
    final int catId = catRows.isNotEmpty ? (catRows.first['id'] as num).toInt() : 1;

    await db.update(
      'productos',
      {
        'precio': precio,
        'stock': stock,
        'stock_actual': stock,
        'categoria': categoria,
        'categoria_id': catId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future eliminarProducto(int id) async {
    final Database db = await instance.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future registrarVentaCompleta({
    required double total,
    int? usuarioId,
    int? cajaId,
    String? metodoPago,
    List? detalles,
    String? cajeroNombre,
    String? nombreCaja,
    String? clienteNombre,
    String? nitCi,
    double? montoRecibido,
    double? cambio,
  }) async {
    final Database db = await instance.database;
    int ventaId = 0;
    await db.transaction((txn) async {
      ventaId = await txn.insert('ventas', {
        'total': total,
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': usuarioId ?? 1,
        'caja_id': cajaId ?? 1,
        'metodo_pago': metodoPago ?? 'Efectivo',
        'cajero_nombre': cajeroNombre ?? '',
        'nombre_caja': nombreCaja ?? '',
        'cliente_nombre': clienteNombre ?? 'Cliente Casual',
        'nit_ci': nitCi ?? '0',
        'monto_recibido': montoRecibido ?? total,
        'cambio': cambio ?? 0.0,
      });
    });
    return ventaId;
  }

  Future obtenerLotes() async {
    final Database db = await instance.database;
    try {
      return await db.query('lotes', orderBy: 'id DESC');
    } catch (_) {
      return [];
    }
  }

  Future registrarLote(Map datos) async {
    final Database db = await instance.database;
    final Map row = Map.from(datos);
    return await db.insert('lotes', row.cast());
  }

  Future eliminarLote(int id) async {
    final Database db = await instance.database;
    await db.delete('lotes', where: 'id = ?', whereArgs: [id]);
  }

  Future restaurarValoresDeFabrica() async {
    final Database db = await instance.database;
    await db.delete('productos');
    await db.delete('categorias');
    await db.delete('ventas');
    await db.delete('caja_sesiones');
    try {
      await db.delete('lotes');
    } catch (_) {}
  }
}