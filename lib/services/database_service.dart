// Nombre del archivo: lib/services/database_service.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  Future get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future _initDatabase() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    final String dbDir = p.join(Directory.current.path, 'data_ascafe');
    final Directory dir = Directory(dbDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final String dbPath = p.join(dbDir, 'ascafe_pos.db');

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT UNIQUE NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        stock_actual INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        rol TEXT NOT NULL DEFAULT 'cajero',
        nombre_caja TEXT DEFAULT 'Caja 1 - Principal',
        caja_asignada TEXT DEFAULT 'Caja 1 - Principal',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_sesiones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cajero_nombre TEXT,
        nombre_caja TEXT,
        fecha_apertura TEXT,
        fecha_cierre TEXT,
        monto_inicial REAL DEFAULT 0,
        monto_final REAL DEFAULT 0,
        estado TEXT DEFAULT 'Abierta'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caja_id INTEGER,
        fecha TEXT,
        total REAL,
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
      CREATE TABLE IF NOT EXISTS detalle_ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER,
        producto_id INTEGER,
        nombre_producto TEXT,
        cantidad INTEGER,
        precio_unitario REAL,
        subtotal REAL,
        FOREIGN KEY (venta_id) REFERENCES ventas (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS egresos_caja (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        monto REAL NOT NULL DEFAULT 0,
        motivo TEXT NOT NULL,
        cajero_nombre TEXT,
        nombre_caja TEXT
      )
    ''');

    await _insertarDatosIniciales(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _onCreate(db, newVersion);
  }

  Future _insertarDatosIniciales(Database db) async {
    final Map<String, String> configDefault = {
      'nombre_negocio': 'AScafe',
      'direccion_negocio': 'Riberalta, Beni - Bolivia',
      'celular_negocio': '+591 70000000',
      'logo_path': '',
      'imap_host': 'imap.gmail.com',
      'imap_port': '993',
      'imap_email': '',
      'imap_password': '',
      'lista_mesas': '1,2,3,4,5,6,7,8,9,10',
      'imagenes_productos_json': '{}',
      'emojis_productos_json': '{}',
      'admin_password': 'admin',
      'modulo_contaduria_activo': 'true',
    };

    for (final entry in configDefault.entries) {
      await db.insert(
        'configuracion',
        {'clave': entry.key, 'valor': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await db.insert(
      'usuarios',
      {
        'nombre': 'Administrador',
        'password': 'admin',
        'rol': 'admin',
        'nombre_caja': 'Caja 1 - Principal',
        'caja_asignada': 'Caja 1 - Principal',
        'activo': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'usuarios',
      {
        'nombre': 'Cajero 1',
        'password': '1234',
        'rol': 'cajero',
        'nombre_caja': 'Caja 1 - Principal',
        'caja_asignada': 'Caja 1 - Principal',
        'activo': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final List catsIniciales = [
      'Salteñas',
      'Horneados',
      'Bebidas',
      'Café',
      'Postres',
      'Combos',
      'General',
    ];

    for (final c in catsIniciales) {
      await db.insert(
        'categorias',
        {'nombre': c},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final List prodExistentes = await db.query('productos', limit: 1);
    if (prodExistentes.isEmpty) {
      final List demoProds = [
        {'cat': 'Salteñas', 'nom': 'Salteña de Pollo', 'pre': 10.0, 'stk': 50},
        {'cat': 'Salteñas', 'nom': 'Salteña de Carne', 'pre': 10.0, 'stk': 50},
        {'cat': 'Salteñas', 'nom': 'Salteña Picante', 'pre': 11.0, 'stk': 40},
        {'cat': 'Horneados', 'nom': 'Empanada de Pollo Especial', 'pre': 12.0, 'stk': 24},
        {'cat': 'Horneados', 'nom': 'Empanada de Carne Picante', 'pre': 12.0, 'stk': 19},
        {'cat': 'Horneados', 'nom': 'Cuñapé Tradicional con Queso', 'pre': 7.0, 'stk': 70},
        {'cat': 'Combos', 'nom': 'Combo Ejecutivo Familiar', 'pre': 45.0, 'stk': 12},
        {'cat': 'Postres', 'nom': 'Torta Húmeda de Chocolate', 'pre': 18.0, 'stk': 7},
        {'cat': 'General', 'nom': 'Panetón', 'pre': 10.0, 'stk': 47},
      ];

      for (final pItem in demoProds) {
        final List catRow = await db.query(
          'categorias',
          where: 'nombre = ?',
          whereArgs: [pItem['cat']],
        );
        final int catId = catRow.isNotEmpty ? (catRow.first['id'] as num).toInt() : 1;
        await db.insert('productos', {
          'categoria_id': catId,
          'nombre': pItem['nom'],
          'precio': pItem['pre'],
          'stock_actual': pItem['stk'],
        });
      }
    }
  }

  Future obtenerConfiguracionNegocio() async {
    final db = await database;
    final List rows = await db.query('configuracion');
    final Map<String, String> map = {};
    for (final r in rows) {
      final k = r['clave']?.toString() ?? '';
      final v = r['valor']?.toString() ?? '';
      if (k.isNotEmpty) {
        map[k] = v;
      }
    }
    return map;
  }

  Future guardarConfiguracionNegocio(Map<String, String> datos) async {
    final db = await database;
    final batch = db.batch();
    datos.forEach((clave, valor) {
      batch.insert(
        'configuracion',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  // ==================== LICENCIA MODULAR DE CONTADURÍA ====================

  Future<bool> estaModuloContaduriaActivo() async {
    final conf = await obtenerConfiguracionNegocio();
    final val = (conf['modulo_contaduria_activo'] ?? 'true').toString().toLowerCase();
    return val == 'true' || val == '1';
  }

  Future configurarModuloContaduriaPorLicencia(bool activo) async {
    final db = await database;
    await db.insert(
      'configuracion',
      {'clave': 'modulo_contaduria_activo', 'valor': activo ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== CONTADURÍA, EGRESOS Y ESTADÍSTICAS ====================

  Future registrarEgresoCaja({
    required double monto,
    required String motivo,
    required String cajeroNombre,
    required String nombreCaja,
  }) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS egresos_caja (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        monto REAL NOT NULL DEFAULT 0,
        motivo TEXT NOT NULL,
        cajero_nombre TEXT,
        nombre_caja TEXT
      )
    ''');
    await db.insert('egresos_caja', {
      'fecha': DateTime.now().toIso8601String(),
      'monto': monto,
      'motivo': motivo.trim(),
      'cajero_nombre': cajeroNombre.trim(),
      'nombre_caja': nombreCaja.trim(),
    });
  }

  Future eliminarEgresoCaja(int id) async {
    final db = await database;
    await db.delete('egresos_caja', where: 'id = ?', whereArgs: [id]);
  }

  Future obtenerResumenContaduria({
    required String desdeIso,
    required String hastaIso,
  }) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS egresos_caja (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        monto REAL NOT NULL DEFAULT 0,
        motivo TEXT NOT NULL,
        cajero_nombre TEXT,
        nombre_caja TEXT
      )
    ''');

    final List ventasRows = await db.query(
      'ventas',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desdeIso, hastaIso],
    );

    double ingresosTotales = 0.0;
    double ingresosEfectivo = 0.0;
    double ingresosQr = 0.0;

    for (final v in ventasRows) {
      final m = v as Map;
      final t = (m['total'] as num?)?.toDouble() ?? 0.0;
      final met = (m['metodo_pago']?.toString() ?? 'Efectivo').toUpperCase();
      ingresosTotales += t;
      if (met.contains('QR')) {
        ingresosQr += t;
      } else {
        ingresosEfectivo += t;
      }
    }

    final List rankingProductos = await db.rawQuery('''
      SELECT d.nombre_producto AS nombre,
             SUM(d.cantidad) AS unidades,
             SUM(d.subtotal) AS subtotal
      FROM detalle_ventas d
      INNER JOIN ventas v ON d.venta_id = v.id
      WHERE v.fecha >= ? AND v.fecha <= ?
      GROUP BY d.nombre_producto
      ORDER BY unidades DESC, subtotal DESC
    ''', [desdeIso, hastaIso]);

    int totalUnidades = 0;
    for (final r in rankingProductos) {
      final rm = r as Map;
      totalUnidades += (rm['unidades'] as num?)?.toInt() ?? 0;
    }

    final List listaEgresos = await db.query(
      'egresos_caja',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desdeIso, hastaIso],
      orderBy: 'id DESC',
    );

    double totalEgresos = 0.0;
    for (final e in listaEgresos) {
      final em = e as Map;
      totalEgresos += (em['monto'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'ingresos_totales': ingresosTotales,
      'ingresos_efectivo': ingresosEfectivo,
      'ingresos_qr': ingresosQr,
      'total_egresos': totalEgresos,
      'cantidad_ventas': ventasRows.length,
      'total_unidades': totalUnidades,
      'ranking_productos': rankingProductos,
      'lista_egresos': listaEgresos,
    };
  }

  Future obtenerCategorias() async {
    final db = await database;
    final List rows = await db.query('categorias', orderBy: 'id ASC');
    return rows.map((r) => r['nombre']?.toString() ?? 'General').toList();
  }

  Future insertarCategoria(String nombre) async {
    final db = await database;
    await db.insert(
      'categorias',
      {'nombre': nombre.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future eliminarCategoriaDB(String nombre) async {
    final db = await database;
    await db.delete('categorias', where: 'nombre = ?', whereArgs: [nombre.trim()]);
  }

  Future obtenerProductos() async {
    final db = await database;
    final List rows = await db.rawQuery('''
      SELECT p.id, p.nombre, p.precio, p.stock_actual AS stock, p.stock_actual,
             COALESCE(c.nombre, 'General') AS categoria
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      ORDER BY p.id ASC
    ''');
    return rows;
  }

  Future actualizarProducto(int id, double precio, int stock, String categoriaNombre) async {
    final db = await database;
    await insertarCategoria(categoriaNombre);
    final List catRows = await db.query(
      'categorias',
      where: 'nombre = ?',
      whereArgs: [categoriaNombre.trim()],
    );
    final int catId = catRows.isNotEmpty ? (catRows.first['id'] as num).toInt() : 1;

    await db.update(
      'productos',
      {
        'precio': precio,
        'stock_actual': stock,
        'categoria_id': catId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future eliminarProducto(int id) async {
    final db = await database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future registrarVentaCompleta({
    required int cajaId,
    required double total,
    required String metodoPago,
    required List detalles,
    required String cajeroNombre,
    required String nombreCaja,
    required String clienteNombre,
    required String nitCi,
    required double montoRecibido,
    required double cambio,
  }) async {
    final db = await database;
    final int ventaId = await db.insert('ventas', {
      'caja_id': cajaId,
      'fecha': DateTime.now().toIso8601String(),
      'total': total,
      'metodo_pago': metodoPago,
      'cajero_nombre': cajeroNombre,
      'nombre_caja': nombreCaja,
      'cliente_nombre': clienteNombre,
      'nit_ci': nitCi,
      'monto_recibido': montoRecibido,
      'cambio': cambio,
    });

    for (final d in detalles) {
      final m = d as Map;
      await db.insert('detalle_ventas', {
        'venta_id': ventaId,
        'producto_id': m['producto_id'],
        'nombre_producto': m['nombre'],
        'cantidad': m['cantidad'],
        'precio_unitario': m['precio_unitario'],
        'subtotal': m['subtotal'],
      });
    }

    return ventaId;
  }

  // ==================== AUTENTICACIÓN Y GESTIÓN DE USUARIOS ====================

  Future autenticarUsuario(String nombre, String password) async {
    final db = await database;
    final List rows = await db.query(
      'usuarios',
      where: 'LOWER(nombre) = LOWER(?) AND password = ? AND activo = 1',
      whereArgs: [nombre.trim(), password.trim()],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first);
    }

    if (nombre.trim().toLowerCase() == 'administrador' || nombre.trim().toLowerCase() == 'admin') {
      final conf = await obtenerConfiguracionNegocio();
      final adminPass = conf['admin_password'] ?? 'admin';
      if (password.trim() == adminPass) {
        return {
          'id': 1,
          'nombre': 'Administrador',
          'rol': 'admin',
          'nombre_caja': 'Caja 1 - Principal',
          'caja_asignada': 'Caja 1 - Principal',
        };
      }
    }
    return null;
  }

  Future obtenerUsuarios() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        rol TEXT NOT NULL DEFAULT 'cajero',
        nombre_caja TEXT DEFAULT 'Caja 1 - Principal',
        caja_asignada TEXT DEFAULT 'Caja 1 - Principal',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    final List rows = await db.query('usuarios', orderBy: 'id ASC');
    if (rows.isEmpty) {
      await _insertarDatosIniciales(db);
      return await db.query('usuarios', orderBy: 'id ASC');
    }
    return rows;
  }

  Future crearActualizarUsuario({
    int? id,
    required String nombre,
    required String nombreCaja,
    required String password,
    required String rol,
  }) async {
    final db = await database;
    if (id != null) {
      await db.update(
        'usuarios',
        {
          'nombre': nombre.trim(),
          'nombre_caja': nombreCaja.trim(),
          'caja_asignada': nombreCaja.trim(),
          'password': password.trim(),
          'rol': rol.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert(
        'usuarios',
        {
          'nombre': nombre.trim(),
          'nombre_caja': nombreCaja.trim(),
          'caja_asignada': nombreCaja.trim(),
          'password': password.trim(),
          'rol': rol.trim(),
          'activo': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (rol.toLowerCase() == 'admin' || nombre.toLowerCase() == 'administrador') {
      await db.insert(
        'configuracion',
        {'clave': 'admin_password', 'valor': password.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future crearOActualizarUsuario({
    int? id,
    required String nombre,
    required String password,
    required String rol,
    String cajaAsignada = 'Caja 1 - Principal',
  }) async {
    await crearActualizarUsuario(
      id: id,
      nombre: nombre,
      nombreCaja: cajaAsignada,
      password: password,
      rol: rol,
    );
  }

  Future cambiarPasswordUsuario(int id, String nuevaPassword, {bool esAdmin = false}) async {
    final db = await database;
    await db.update(
      'usuarios',
      {'password': nuevaPassword.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (esAdmin) {
      await db.insert(
        'configuracion',
        {'clave': 'admin_password', 'valor': nuevaPassword.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future cambiarPasswordAdministradorGlobal(String nuevaPassword) async {
    final db = await database;
    await db.insert(
      'configuracion',
      {'clave': 'admin_password', 'valor': nuevaPassword.trim()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.update(
      'usuarios',
      {'password': nuevaPassword.trim()},
      where: "LOWER(rol) = 'admin' OR LOWER(nombre) = 'administrador'",
    );
  }

  Future eliminarUsuario(int id) async {
    final db = await database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  Future restaurarValoresDeFabrica() async {
    final db = await database;
    await db.delete('detalle_ventas');
    await db.delete('ventas');
    await db.delete('caja_sesiones');
    await db.delete('egresos_caja');
    await db.delete('productos');
    await db.delete('configuracion');
    await _insertarDatosIniciales(db);
  }
}