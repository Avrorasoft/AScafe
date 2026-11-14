// Nombre del archivo: lib/views/contaduria_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ContaduriaScreen extends StatefulWidget {
  final String cajeroActivo;
  final String cajaActiva;

  const ContaduriaScreen({
    super.key,
    this.cajeroActivo = 'Administrador',
    this.cajaActiva = 'Caja 1 - Principal',
  });

  @override
  State<ContaduriaScreen> createState() => _ContaduriaScreenState();
}

class _ContaduriaScreenState extends State<ContaduriaScreen> {
  final DatabaseService _dbService = DatabaseService.instance;

  // Modos: 'Hoy', 'Semana', 'FechaExacta', 'RangoFechas', 'PorMes', 'PorAnio'
  String _modoFiltro = 'Hoy';
  bool _cargando = true;

  // Variables para consultas históricas por fecha, mes y año
  DateTime _fechaExactaSeleccionada = DateTime.now();
  DateTime _rangoFechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangoFechaFin = DateTime.now();
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  static const List<String> _nombresMeses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  double _ingresosTotales = 0.0;
  double _ingresosEfectivo = 0.0;
  double _ingresosQr = 0.0;
  double _totalEgresos = 0.0;
  int _cantidadVentas = 0;
  int _totalUnidadesVendidas = 0;

  List _rankingProductos = [];
  List _listaEgresos = [];
  Map<String, String> _configNegocio = {};

  static const List<Color> _paletaColoresGrafico = [
    Color(0xFFFFAB00),
    Color(0xFF00E5FF),
    Color(0xFF00E676),
    Color(0xFFFF4081),
    Color(0xFF7C4DFF),
    Color(0xFFFF6D00),
    Color(0xFF1DE9B6),
    Color(0xFFFFEA00),
    Color(0xFF2979FF),
    Color(0xFFF50057),
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosContaduria();
  }

  List<int> _obtenerListaAniosDisponibles() {
    final int anioActual = DateTime.now().year;
    final List<int> lista = [];
    for (int a = 2023; a <= anioActual + 2; a++) {
      lista.add(a);
    }
    if (!lista.contains(_anioSeleccionado)) {
      lista.add(_anioSeleccionado);
    }
    return lista;
  }

  String _formatearFechaCorta(DateTime f) {
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    return '$d/$m/${f.year}';
  }

  String _obtenerEtiquetaPeriodoActual() {
    final ahora = DateTime.now();
    if (_modoFiltro == 'Hoy') {
      return 'Ventas de Hoy (${_formatearFechaCorta(ahora)})';
    } else if (_modoFiltro == 'Semana') {
      final haceSiete = ahora.subtract(const Duration(days: 6));
      return 'Últimos 7 Días (${_formatearFechaCorta(haceSiete)} al ${_formatearFechaCorta(ahora)})';
    } else if (_modoFiltro == 'FechaExacta') {
      return 'Fecha Exacta: ${_formatearFechaCorta(_fechaExactaSeleccionada)}';
    } else if (_modoFiltro == 'RangoFechas') {
      return 'Rango: ${_formatearFechaCorta(_rangoFechaInicio)} al ${_formatearFechaCorta(_rangoFechaFin)}';
    } else if (_modoFiltro == 'PorMes') {
      final nombreMes = _nombresMeses[_mesSeleccionado - 1];
      return 'Informe Mensual: $nombreMes $_anioSeleccionado';
    } else {
      return 'Informe Anual Completo: Gestión $_anioSeleccionado';
    }
  }

  Map<String, DateTime> _calcularRangoFechasConsulta() {
    final ahora = DateTime.now();

    if (_modoFiltro == 'Hoy') {
      return {
        'desde': DateTime(ahora.year, ahora.month, ahora.day, 0, 0, 0),
        'hasta': DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59),
      };
    } else if (_modoFiltro == 'Semana') {
      final haceSieteDias = ahora.subtract(const Duration(days: 6));
      return {
        'desde': DateTime(haceSieteDias.year, haceSieteDias.month, haceSieteDias.day, 0, 0, 0),
        'hasta': DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59),
      };
    } else if (_modoFiltro == 'FechaExacta') {
      return {
        'desde': DateTime(
          _fechaExactaSeleccionada.year,
          _fechaExactaSeleccionada.month,
          _fechaExactaSeleccionada.day,
          0,
          0,
          0,
        ),
        'hasta': DateTime(
          _fechaExactaSeleccionada.year,
          _fechaExactaSeleccionada.month,
          _fechaExactaSeleccionada.day,
          23,
          59,
          59,
        ),
      };
    } else if (_modoFiltro == 'RangoFechas') {
      DateTime ini = _rangoFechaInicio;
      DateTime fin = _rangoFechaFin;
      if (fin.isBefore(ini)) {
        final temp = ini;
        ini = fin;
        fin = temp;
      }
      return {
        'desde': DateTime(ini.year, ini.month, ini.day, 0, 0, 0),
        'hasta': DateTime(fin.year, fin.month, fin.day, 23, 59, 59),
      };
    } else if (_modoFiltro == 'PorMes') {
      // Último día del mes seleccionado (día 0 del mes siguiente)
      final ultimoDiaMes = DateTime(_anioSeleccionado, _mesSeleccionado + 1, 0);
      return {
        'desde': DateTime(_anioSeleccionado, _mesSeleccionado, 1, 0, 0, 0),
        'hasta': DateTime(_anioSeleccionado, _mesSeleccionado, ultimoDiaMes.day, 23, 59, 59),
      };
    } else {
      // Por Año Entero (1 de Enero 00:00:00 al 31 de Diciembre 23:59:59)
      return {
        'desde': DateTime(_anioSeleccionado, 1, 1, 0, 0, 0),
        'hasta': DateTime(_anioSeleccionado, 12, 31, 23, 59, 59),
      };
    }
  }

  Future _cargarDatosContaduria() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final conf = await _dbService.obtenerConfiguracionNegocio();
      final rango = _calcularRangoFechasConsulta();
      final DateTime desde = rango['desde']!;
      final DateTime hasta = rango['hasta']!;

      final resumen = await _dbService.obtenerResumenContaduria(
        desdeIso: desde.toIso8601String(),
        hastaIso: hasta.toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _configNegocio = Map<String, String>.from(conf);
          _ingresosTotales = (resumen['ingresos_totales'] as num?)?.toDouble() ?? 0.0;
          _ingresosEfectivo = (resumen['ingresos_efectivo'] as num?)?.toDouble() ?? 0.0;
          _ingresosQr = (resumen['ingresos_qr'] as num?)?.toDouble() ?? 0.0;
          _totalEgresos = (resumen['total_egresos'] as num?)?.toDouble() ?? 0.0;
          _cantidadVentas = (resumen['cantidad_ventas'] as num?)?.toInt() ?? 0;
          _totalUnidadesVendidas = (resumen['total_unidades'] as num?)?.toInt() ?? 0;
          _rankingProductos = (resumen['ranking_productos'] as List?) ?? [];
          _listaEgresos = (resumen['lista_egresos'] as List?) ?? [];
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _seleccionarFechaExactaCalendario() async {
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: _fechaExactaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECCIONAR FECHA DEL INFORME CONTABLE',
      cancelText: 'Cancelar',
      confirmText: 'Consultar Fecha',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFAB00),
              onPrimary: Colors.black,
              surface: Color(0xFF0E1626),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (elegida != null) {
      setState(() {
        _fechaExactaSeleccionada = elegida;
        _modoFiltro = 'FechaExacta';
      });
      await _cargarDatosContaduria();
    }
  }

  Future<void> _seleccionarFechaRango({required bool esInicio}) async {
    final DateTime fechaInicial = esInicio ? _rangoFechaInicio : _rangoFechaFin;
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: esInicio ? 'FECHA DESDE (INICIO)' : 'FECHA HASTA (FIN)',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              onPrimary: Colors.black,
              surface: Color(0xFF0E1626),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (elegida != null) {
      setState(() {
        if (esInicio) {
          _rangoFechaInicio = elegida;
          if (_rangoFechaFin.isBefore(_rangoFechaInicio)) {
            _rangoFechaFin = _rangoFechaInicio;
          }
        } else {
          _rangoFechaFin = elegida;
          if (_rangoFechaInicio.isAfter(_rangoFechaFin)) {
            _rangoFechaInicio = _rangoFechaFin;
          }
        }
        _modoFiltro = 'RangoFechas';
      });
      await _cargarDatosContaduria();
    }
  }

  void _mostrarDialogoSacarEfectivo() {
    final ctrlMonto = TextEditingController();
    final ctrlMotivo = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.money_off_csred_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sacar Efectivo de Caja (Retiro / Gasto)',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registra cualquier salida de dinero en efectivo de la gaveta (pago a proveedores, compra de insumos, adelantos o retiros):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrlMonto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Monto a Retirar (Bs.)',
                    labelStyle: const TextStyle(color: Color(0xFFFFAB00)),
                    prefixIcon: const Icon(Icons.attach_money, color: Color(0xFFFFAB00)),
                    filled: true,
                    fillColor: const Color(0xFF131C31),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlMotivo,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Motivo / Concepto (Ej: Compra de hielo, servilletas...)',
                    labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                    prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF00E5FF)),
                    filled: true,
                    fillColor: const Color(0xFF131C31),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.outbox_rounded, size: 18),
              label: const Text('Registrar Retiro de Efectivo', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final monto = double.tryParse(ctrlMonto.text.trim()) ?? 0.0;
                final motivo = ctrlMotivo.text.trim();

                if (monto <= 0 || motivo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.orangeAccent,
                      content: Text('⚠️ Ingresa un monto válido mayor a 0 y el motivo del retiro.'),
                    ),
                  );
                  return;
                }

                final nav = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                await _dbService.registrarEgresoCaja(
                  monto: monto,
                  motivo: motivo,
                  cajeroNombre: widget.cajeroActivo,
                  nombreCaja: widget.cajaActiva,
                );

                nav.pop();
                await _cargarDatosContaduria();

                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('✅ Retiro de Bs. ${monto.toStringAsFixed(2)} registrado en Contaduría.'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _construirControlesSecundariosDeFecha() {
    final anios = _obtenerListaAniosDisponibles();

    if (_modoFiltro == 'FechaExacta') {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: Color(0xFFFFAB00), size: 18),
            const SizedBox(width: 8),
            const Text(
              'Día consultado:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF131C31),
                foregroundColor: const Color(0xFFFFAB00),
                side: const BorderSide(color: Color(0xFFFFAB00)),
              ),
              onPressed: _seleccionarFechaExactaCalendario,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _formatearFechaCorta(_fechaExactaSeleccionada),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _seleccionarFechaExactaCalendario,
              child: const Text(
                'Cambiar fecha en calendario',
                style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_modoFiltro == 'RangoFechas') {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.date_range, color: Color(0xFF00E5FF), size: 18),
            const Text(
              'Desde:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF131C31),
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
              ),
              onPressed: () => _seleccionarFechaRango(esInicio: true),
              icon: const Icon(Icons.calendar_today, size: 15),
              label: Text(
                _formatearFechaCorta(_rangoFechaInicio),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Text(
              'Hasta:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF131C31),
                foregroundColor: const Color(0xFFFFAB00),
                side: const BorderSide(color: Color(0xFFFFAB00)),
              ),
              onPressed: () => _seleccionarFechaRango(esInicio: false),
              icon: const Icon(Icons.event, size: 15),
              label: Text(
                _formatearFechaCorta(_rangoFechaFin),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (_modoFiltro == 'PorMes') {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.calendar_view_month, color: Color(0xFFFFAB00), size: 18),
            const Text(
              'Seleccionar Mes:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFAB00)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _mesSeleccionado,
                  dropdownColor: const Color(0xFF131C31),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  items: List.generate(12, (index) {
                    final numMes = index + 1;
                    return DropdownMenuItem<int>(
                      value: numMes,
                      child: Text('${numMes.toString().padLeft(2, '0')} - ${_nombresMeses[index]}'),
                    );
                  }),
                  onChanged: (nuevoMes) {
                    if (nuevoMes != null) {
                      setState(() => _mesSeleccionado = nuevoMes);
                      _cargarDatosContaduria();
                    }
                  },
                ),
              ),
            ),
            const Text(
              'Año:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _anioSeleccionado,
                  dropdownColor: const Color(0xFF131C31),
                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                  items: anios.map((int a) {
                    return DropdownMenuItem<int>(
                      value: a,
                      child: Text('Año $a'),
                    );
                  }).toList(),
                  onChanged: (nuevoAnio) {
                    if (nuevoAnio != null) {
                      setState(() => _anioSeleccionado = nuevoAnio);
                      _cargarDatosContaduria();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_modoFiltro == 'PorAnio') {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.insights_rounded, color: Color(0xFF00E676), size: 18),
            const Text(
              'Seleccionar Año Entero (1 Enero al 31 Diciembre):',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E676), width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _anioSeleccionado,
                  dropdownColor: const Color(0xFF131C31),
                  style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 14),
                  items: anios.map((int a) {
                    return DropdownMenuItem<int>(
                      value: a,
                      child: Text('📅 Gestión Anual $a'),
                    );
                  }).toList(),
                  onChanged: (nuevoAnio) {
                    if (nuevoAnio != null) {
                      setState(() => _anioSeleccionado = nuevoAnio);
                      _cargarDatosContaduria();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _construirTarjetaKPI({
    required String titulo,
    required String valorPrincipal,
    required String subtitulo,
    required IconData icono,
    required Color colorBorde,
    required Color colorValor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF131C31),
              colorBorde.withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorBorde.withOpacity(0.75), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icono, color: colorBorde, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valorPrincipal,
              style: TextStyle(
                color: colorValor,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirGraficoBarrasProductos() {
    if (_rankingProductos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            '📊 Aún no hay ventas registradas en este periodo o fecha para graficar.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    int maxUnidades = 1;
    for (final p in _rankingProductos) {
      final m = p as Map;
      final u = (m['unidades'] as num?)?.toInt() ?? 0;
      if (u > maxUnidades) maxUnidades = u;
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rankingProductos.length,
      itemBuilder: (context, index) {
        final item = _rankingProductos[index] as Map;
        final String nombre = item['nombre']?.toString() ?? 'Producto';
        final int unidades = (item['unidades'] as num?)?.toInt() ?? 0;
        final double totalBs = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
        final double porcentaje = _totalUnidadesVendidas > 0
            ? (unidades / _totalUnidadesVendidas) * 100
            : 0.0;
        final double factorAncho = maxUnidades > 0 ? (unidades / maxUnidades) : 0.0;
        final Color colorBarra = _paletaColoresGrafico[index % _paletaColoresGrafico.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorBarra.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colorBarra, width: 1.2),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: colorBarra,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$unidades unds (${porcentaje.toStringAsFixed(1)}%)   |   Bs. ${totalBs.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colorBarra,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final anchoMaximo = constraints.maxWidth;
                  final anchoCalculado = (anchoMaximo * factorAncho).clamp(12.0, anchoMaximo);
                  return Stack(
                    children: [
                      Container(
                        height: 16,
                        width: anchoMaximo,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        height: 16,
                        width: anchoCalculado,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorBarra.withOpacity(0.65),
                              colorBarra,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: colorBarra.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirGraficoCircularDonut() {
    if (_rankingProductos.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Sin datos para el gráfico circular',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    final topItems = _rankingProductos.take(6).toList();
    final List<double> valores = [];
    final List<Color> colores = [];

    for (int i = 0; i < topItems.length; i++) {
      final m = topItems[i] as Map;
      valores.add(((m['unidades'] as num?)?.toDouble() ?? 0.0));
      colores.add(_paletaColoresGrafico[i % _paletaColoresGrafico.length]);
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          width: 170,
          child: CustomPaint(
            painter: _DonutChartPainter(valores: valores, colores: colores),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_totalUnidadesVendidas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const Text(
                    'Unidades',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(topItems.length, (i) {
            final m = topItems[i] as Map;
            final nom = m['nombre']?.toString() ?? '';
            final unds = (m['unidades'] as num?)?.toInt() ?? 0;
            final col = colores[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  '$nom ($unds)',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double efectivoNetoEnCaja = _ingresosEfectivo - _totalEgresos;
    final String nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        title: Row(
          children: [
            const Text('📊 ', style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                'Módulo de Contaduría y Estadísticas — $nombreNeg',
                style: const TextStyle(
                  color: Color(0xFFFFAB00),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _mostrarDialogoSacarEfectivo,
            icon: const Icon(Icons.money_off_csred_rounded, size: 18),
            label: const Text(
              'Sacar Efectivo de Caja',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            tooltip: 'Actualizar Estadísticas',
            onPressed: _cargarDatosContaduria,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARRA DE FILTROS DE PERIODO (HOY, SEMANA, POR FECHA, RANGO, POR MES, POR AÑO ENTERO)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1626),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFF00E5FF), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _obtenerEtiquetaPeriodoActual(),
                                  style: const TextStyle(
                                    color: Color(0xFFFFAB00),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _botonFiltroModo('Hoy', '📅 Hoy'),
                                _botonFiltroModo('Semana', '📆 7 Días'),
                                _botonFiltroModo(
                                  'FechaExacta',
                                  '🎯 Por Fecha',
                                  alPresionarEspecial: _seleccionarFechaExactaCalendario,
                                ),
                                _botonFiltroModo('RangoFechas', '↔️ Rango Fechas'),
                                _botonFiltroModo('PorMes', '🗓️ Por Mes'),
                                _botonFiltroModo('PorAnio', '📈 Por Año Entero'),
                              ],
                            ),
                          ],
                        ),
                        _construirControlesSecundariosDeFecha(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TARJETAS DE RESUMEN FINANCIERO (KPIs)
                  Row(
                    children: [
                      _construirTarjetaKPI(
                        titulo: 'INGRESOS BRUTOS TOTALES',
                        valorPrincipal: 'Bs. ${_ingresosTotales.toStringAsFixed(2)}',
                        subtitulo: '$_cantidadVentas ventas | $_totalUnidadesVendidas productos vendidos',
                        icono: Icons.trending_up_rounded,
                        colorBorde: const Color(0xFFFFAB00),
                        colorValor: const Color(0xFFFFAB00),
                      ),
                      const SizedBox(width: 12),
                      _construirTarjetaKPI(
                        titulo: 'VENTAS EN EFECTIVO',
                        valorPrincipal: 'Bs. ${_ingresosEfectivo.toStringAsFixed(2)}',
                        subtitulo: 'Cobrado en billetes y monedas',
                        icono: Icons.payments_outlined,
                        colorBorde: const Color(0xFF00E676),
                        colorValor: const Color(0xFF00E676),
                      ),
                      const SizedBox(width: 12),
                      _construirTarjetaKPI(
                        titulo: 'INGRESOS POR PAGO QR',
                        valorPrincipal: 'Bs. ${_ingresosQr.toStringAsFixed(2)}',
                        subtitulo: 'Transferencias bancarias QR',
                        icono: Icons.qr_code_2_rounded,
                        colorBorde: const Color(0xFF00E5FF),
                        colorValor: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 12),
                      _construirTarjetaKPI(
                        titulo: 'RETIROS / GASTOS DE CAJA',
                        valorPrincipal: '- Bs. ${_totalEgresos.toStringAsFixed(2)}',
                        subtitulo: '${_listaEgresos.length} salidas de efectivo registradas',
                        icono: Icons.money_off_csred_rounded,
                        colorBorde: Colors.redAccent,
                        colorValor: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      _construirTarjetaKPI(
                        titulo: 'EFECTIVO NETO EN GAVETA',
                        valorPrincipal: 'Bs. ${efectivoNetoEnCaja.toStringAsFixed(2)}',
                        subtitulo: 'Efectivo cobrado menos retiros',
                        icono: Icons.account_balance_wallet_rounded,
                        colorBorde: const Color(0xFF7C4DFF),
                        colorValor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // SECCIÓN CENTRAL: GRÁFICOS DE PRODUCTOS INDIVIDUALES VENDIDOS
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GRÁFICO DE BARRAS DETALLADO POR PRODUCTO INDIVIDUAL
                      Expanded(
                        flex: 7,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131C31),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFFAB00).withOpacity(0.5),
                              width: 1.3,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bar_chart_rounded, color: Color(0xFFFFAB00), size: 22),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ranking Detallado de Ventas por Producto Individual',
                                      style: TextStyle(
                                        color: Color(0xFFFFAB00),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Unidades exactas vendidas e ingresos generados por cada producto (Salteñas, Refrescos, Jugos, etc.):',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              _construirGraficoBarrasProductos(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // COLUMNA DERECHA: GRÁFICO DONUT + HISTORIAL DE RETIROS DE EFECTIVO
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131C31),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                                  width: 1.3,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.pie_chart_rounded, color: Color(0xFF00E5FF), size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Distribución de Productos Más Vendidos',
                                          style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white24, height: 20),
                                  _construirGraficoCircularDonut(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // HISTORIAL DE RETIROS DE EFECTIVO DE CAJA
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131C31),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.5),
                                  width: 1.3,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.receipt_long_rounded, color: Colors.redAccent, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Historial de Efectivo Sacado de Caja',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        onPressed: _mostrarDialogoSacarEfectivo,
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent, size: 16),
                                        label: const Text(
                                          'Nuevo Retiro',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white24, height: 16),
                                  if (_listaEgresos.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.0),
                                      child: Center(
                                        child: Text(
                                          'No se ha sacado efectivo de la caja en este periodo.',
                                          style: TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _listaEgresos.length,
                                      itemBuilder: (context, i) {
                                        final eg = _listaEgresos[i] as Map;
                                        final int idEg = (eg['id'] as num?)?.toInt() ?? 0;
                                        final double montoEg = (eg['monto'] as num?)?.toDouble() ?? 0.0;
                                        final String motivoEg = eg['motivo']?.toString() ?? '';
                                        final String cajeroEg = eg['cajero_nombre']?.toString() ?? '';
                                        final String fechaEg = (eg['fecha']?.toString() ?? '')
                                            .replaceFirst('T', ' ')
                                            .split('.')
                                            .first;

                                        return Card(
                                          color: const Color(0xFF0A0F1D),
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          child: ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.output_rounded, color: Colors.redAccent),
                                            title: Text(
                                              '$motivoEg  —  Bs. ${montoEg.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '$fechaEg | Por: $cajeroEg',
                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                                              tooltip: 'Anular retiro',
                                              onPressed: () async {
                                                await _dbService.eliminarEgresoCaja(idEg);
                                                await _cargarDatosContaduria();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _botonFiltroModo(String clave, String etiqueta, {VoidCallback? alPresionarEspecial}) {
    final bool activo = _modoFiltro == clave;
    return ChoiceChip(
      label: Text(etiqueta, style: const TextStyle(fontSize: 12)),
      selected: activo,
      selectedColor: const Color(0xFFFFAB00),
      backgroundColor: const Color(0xFF131C31),
      labelStyle: TextStyle(
        color: activo ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) {
        if (alPresionarEspecial != null && _modoFiltro == clave) {
          alPresionarEspecial();
          return;
        }
        setState(() {
          _modoFiltro = clave;
        });
        if (alPresionarEspecial != null) {
          alPresionarEspecial();
        } else {
          _cargarDatosContaduria();
        }
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> colores;

  _DonutChartPainter({required this.valores, required this.colores});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = valores.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final Offset centro = Offset(size.width / 2, size.height / 2);
    final double radio = math.min(size.width, size.height) / 2 - 14;
    final Rect rect = Rect.fromCircle(center: centro, radius: radio);

    double anguloInicio = -math.pi / 2;

    for (int i = 0; i < valores.length; i++) {
      final double barrido = (valores[i] / total) * 2 * math.pi;
      final Paint paint = Paint()
        ..color = colores[i % colores.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, anguloInicio, barrido - 0.03, false, paint);
      anguloInicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}