// Nombre del archivo: database_service.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  get database async {
    if (_database != null) {
      await _asegurarEstructuraYCajeros(_database!);
      await _asegurarCatalogoInicial(_database!);
      return _database!;
    }
    _database = await _initDB('salteceria.db');
    await _asegurarEstructuraYCajeros(_database!);
    await _asegurarCatalogoInicial(_database!);
    return _database!;
  }

  _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _asegurarEstructuraYCajeros(db);
      },
    );
  }

  _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        stock_actual INTEGER DEFAULT 0,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lotes_produccion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER,
        cantidad_producida INTEGER NOT NULL,
        cantidad_disponible INTEGER NOT NULL,
        hora_salida TEXT NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT DEFAULT 'Disponible',
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        nombre_caja TEXT NOT NULL,
        password TEXT NOT NULL,
        rol TEXT NOT NULL DEFAULT 'cajero'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion_negocio (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_sesiones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        cajero_nombre TEXT DEFAULT 'Administrador',
        nombre_caja TEXT DEFAULT 'Caja Principal',
        fecha_apertura TEXT NOT NULL,
        fecha_cierre TEXT,
        monto_inicial REAL NOT NULL,
        monto_final REAL,
        estado TEXT DEFAULT 'Abierta'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caja_id INTEGER,
        cajero_nombre TEXT DEFAULT 'Administrador',
        nombre_caja TEXT DEFAULT 'Caja Principal',
        cliente_nombre TEXT DEFAULT 'Cliente Casual',
        nit_ci TEXT DEFAULT '0',
        fecha TEXT NOT NULL,
        total REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        monto_recibido REAL DEFAULT 0,
        cambio REAL DEFAULT 0,
        FOREIGN KEY (caja_id) REFERENCES caja_sesiones (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS detalle_ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER,
        producto_id INTEGER,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas (id),
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');
  }

  _asegurarEstructuraYCajeros(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        nombre_caja TEXT NOT NULL,
        password TEXT NOT NULL,
        rol TEXT NOT NULL DEFAULT 'cajero'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion_negocio (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    await db.insert('configuracion_negocio', {'clave': 'nombre_negocio', 'valor': 'AScafe'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('configuracion_negocio', {'clave': 'direccion_negocio', 'valor': 'Riberalta, Beni - Bolivia'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('configuracion_negocio', {'clave': 'celular_negocio', 'valor': '+591 70000000'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('configuracion_negocio', {'clave': 'logo_path', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final List colsSesiones = await db.rawQuery('PRAGMA table_info(caja_sesiones)');
    final List nombresSes = colsSesiones.map((e) => (e as Map)['name'].toString()).toList();
    if (!nombresSes.contains('usuario_id')) {
      await db.execute('ALTER TABLE caja_sesiones ADD COLUMN usuario_id INTEGER DEFAULT 1');
    }
    if (!nombresSes.contains('cajero_nombre')) {
      await db.execute("ALTER TABLE caja_sesiones ADD COLUMN cajero_nombre TEXT DEFAULT 'Administrador'");
    }
    if (!nombresSes.contains('nombre_caja')) {
      await db.execute("ALTER TABLE caja_sesiones ADD COLUMN nombre_caja TEXT DEFAULT 'Caja Principal'");
    }

    final List colsVentas = await db.rawQuery('PRAGMA table_info(ventas)');
    final List nombresVen = colsVentas.map((e) => (e as Map)['name'].toString()).toList();
    if (!nombresVen.contains('cajero_nombre')) {
      await db.execute("ALTER TABLE ventas ADD COLUMN cajero_nombre TEXT DEFAULT 'Administrador'");
    }
    if (!nombresVen.contains('nombre_caja')) {
      await db.execute("ALTER TABLE ventas ADD COLUMN nombre_caja TEXT DEFAULT 'Caja Principal'");
    }
    if (!nombresVen.contains('cliente_nombre')) {
      await db.execute("ALTER TABLE ventas ADD COLUMN cliente_nombre TEXT DEFAULT 'Cliente Casual'");
    }
    if (!nombresVen.contains('nit_ci')) {
      await db.execute("ALTER TABLE ventas ADD COLUMN nit_ci TEXT DEFAULT '0'");
    }
    if (!nombresVen.contains('monto_recibido')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN monto_recibido REAL DEFAULT 0');
    }
    if (!nombresVen.contains('cambio')) {
      await db.execute('ALTER TABLE ventas ADD COLUMN cambio REAL DEFAULT 0');
    }

    final List usuariosExistentes = await db.query('usuarios', limit: 1);
    if (usuariosExistentes.isEmpty) {
      await db.insert('usuarios', {
        'nombre': 'Administrador',
        'nombre_caja': 'Caja Central - Admin',
        'password': '123456',
        'rol': 'admin',
      });
      await db.insert('usuarios', {
        'nombre': 'Cajero 1',
        'nombre_caja': 'Caja 1 - Ventanilla',
        'password': '123',
        'rol': 'cajero',
      });
    }
  }

  _asegurarCatalogoInicial(Database db) async {
    final List existentes = await db.query('productos', limit: 1);
    if (existentes.isNotEmpty) return;

    final int catSaltenas = await db.insert('categorias', {'nombre': 'Salteñas'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final int catBebidas = await db.insert('categorias', {'nombre': 'Refrescos y Bebidas'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('productos', {'categoria_id': catSaltenas, 'nombre': 'Salteña de Pollo', 'precio': 10.0, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catSaltenas, 'nombre': 'Salteña de Carne', 'precio': 10.0, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catSaltenas, 'nombre': 'Salteña Picante Pollo', 'precio': 10.5, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catSaltenas, 'nombre': 'Salteña Picante Carne', 'precio': 10.5, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catSaltenas, 'nombre': 'Salteña Dulce', 'precio': 9.0, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catBebidas, 'nombre': 'Refresco Mocochinchi', 'precio': 5.0, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catBebidas, 'nombre': 'Refresco de Soya', 'precio': 5.0, 'stock_actual': 100});
    await db.insert('productos', {'categoria_id': catBebidas, 'nombre': 'Api con Pastel', 'precio': 12.0, 'stock_actual': 100});
  }

  obtenerConfiguracionNegocio() async {
    final db = await database;
    final List res = await db.query('configuracion_negocio');
    final Map<String, String> config = {
      'nombre_negocio': 'AScafe',
      'direccion_negocio': 'Riberalta, Beni - Bolivia',
      'celular_negocio': '+591 70000000',
      'logo_path': '',
    };
    for (final row in res) {
      final mapa = row as Map;
      final clave = mapa['clave']?.toString();
      final valor = mapa['valor']?.toString();
      if (clave != null && valor != null) {
        config[clave] = valor;
      }
    }
    return config;
  }

  guardarConfiguracionNegocio(Map<String, String> datos) async {
    final db = await database;
    for (final entry in datos.entries) {
      await db.insert(
        'configuracion_negocio',
        {'clave': entry.key, 'valor': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  obtenerUsuarios() async {
    final db = await database;
    return await db.query('usuarios', orderBy: 'id ASC');
  }

  autenticarUsuario(String nombre, String password) async {
    final db = await database;
    final List res = await db.query(
      'usuarios',
      where: 'nombre = ? AND password = ?',
      whereArgs: [nombre.trim(), password.trim()],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Map.from(res.first as Map);
    }
    return null;
  }

  crearActualizarUsuario({
    int? id,
    required String nombre,
    required String nombreCaja,
    required String password,
    required String rol,
  }) async {
    final db = await database;
    final datos = {
      'nombre': nombre.trim(),
      'nombre_caja': nombreCaja.trim(),
      'password': password.trim(),
      'rol': rol.trim(),
    };
    if (id != null) {
      await db.update('usuarios', datos, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.insert('usuarios', datos, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  eliminarUsuario(int id) async {
    final db = await database;
    await db.delete('usuarios', where: "id = ? AND rol != 'admin'", whereArgs: [id]);
  }

  restaurarValoresDeFabrica() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detalle_ventas');
      await txn.delete('ventas');
      await txn.delete('caja_sesiones');
      await txn.delete('lotes_produccion');
      await txn.delete('productos');
      await txn.delete('categorias');
      await txn.delete('usuarios');
      await txn.delete('configuracion_negocio');
      try {
        await txn.execute('DELETE FROM sqlite_sequence');
      } catch (_) {}
    });
    await _asegurarEstructuraYCajeros(db);
    await _asegurarCatalogoInicial(db);
  }

  obtenerCategorias() async {
    final db = await database;
    final List maps = await db.query('categorias', orderBy: 'nombre ASC');
    List lista = ['General'];
    for (var m in maps) {
      final nombre = m['nombre']?.toString();
      if (nombre != null && !lista.contains(nombre)) {
        lista.add(nombre);
      }
    }
    return lista;
  }

  insertarCategoria(String nombre) async {
    final db = await database;
    await db.insert(
      'categorias',
      {'nombre': nombre},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  eliminarCategoriaDB(String nombre) async {
    final db = await database;
    await db.delete(
      'categorias',
      where: 'nombre = ?',
      whereArgs: [nombre],
    );
  }

  obtenerProductos() async {
    final db = await database;
    final List result = await db.rawQuery('''
      SELECT p.id, p.nombre, p.precio, p.stock_actual as stock, 
             COALESCE(c.nombre, 'General') as categoria
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      ORDER BY p.id ASC
    ''');
    return result;
  }

  eliminarProducto(int id) async {
    final db = await database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  actualizarProducto(int id, double precio, int stock, String categoriaNombre) async {
    final db = await database;

    List catResult = await db.query(
      'categorias',
      where: 'nombre = ?',
      whereArgs: [categoriaNombre],
    );

    int categoriaId;
    if (catResult.isNotEmpty) {
      categoriaId = catResult.first['id'] as int;
    } else {
      categoriaId = await db.insert('categorias', {'nombre': categoriaNombre});
    }

    await db.update(
      'productos',
      {
        'precio': precio,
        'stock_actual': stock,
        'categoria_id': categoriaId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  registrarVentaCompleta({
    required int cajaId,
    required double total,
    required String metodoPago,
    required List detalles,
    String cajeroNombre = 'Administrador',
    String nombreCaja = 'Caja Principal',
    String clienteNombre = 'Cliente Casual',
    String nitCi = '0',
    double montoRecibido = 0.0,
    double cambio = 0.0,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final int ventaId = await txn.insert('ventas', {
        'caja_id': cajaId,
        'cajero_nombre': cajeroNombre,
        'nombre_caja': nombreCaja,
        'cliente_nombre': clienteNombre,
        'nit_ci': nitCi,
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
        'metodo_pago': metodoPago,
        'monto_recibido': montoRecibido,
        'cambio': cambio,
      });

      for (final item in detalles) {
        final mapa = item as Map;
        final int productoId = (mapa['producto_id'] as num).toInt();
        int cantidadAVender = (mapa['cantidad'] as num).toInt();
        final double precioUnitario = (mapa['precio_unitario'] as num).toDouble();
        final double subtotal = (mapa['subtotal'] as num).toDouble();

        await txn.insert('detalle_ventas', {
          'venta_id': ventaId,
          'producto_id': productoId,
          'cantidad': cantidadAVender,
          'precio_unitario': precioUnitario,
          'subtotal': subtotal,
        });

        final hoy = DateTime.now().toIso8601String().split('T')[0];
        final List lotesDisponibles = await txn.query(
          'lotes_produccion',
          where: "producto_id = ? AND fecha = ? AND cantidad_disponible > 0",
          whereArgs: [productoId, hoy],
          orderBy: "id ASC",
        );

        for (final loteFila in lotesDisponibles) {
          if (cantidadAVender <= 0) break;
          final loteMap = loteFila as Map;
          final int loteId = (loteMap['id'] as num).toInt();
          final int disponibleEnLote = (loteMap['cantidad_disponible'] as num).toInt();

          if (disponibleEnLote >= cantidadAVender) {
            await txn.update(
              'lotes_produccion',
              {'cantidad_disponible': disponibleEnLote - cantidadAVender},
              where: 'id = ?',
              whereArgs: [loteId],
            );
            cantidadAVender = 0;
          } else {
            cantidadAVender = cantidadAVender - disponibleEnLote;
            await txn.update(
              'lotes_produccion',
              {'cantidad_disponible': 0},
              where: 'id = ?',
              whereArgs: [loteId],
            );
          }
        }
      }

      return ventaId;
    });
  }

  close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}