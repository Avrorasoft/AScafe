import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class EventoPagoYape {
  final String id;
  final String origen;
  final String empresa;
  final double monto;
  final String moneda;
  final String pagador;
  final String titulo;
  final String mensaje;
  final DateTime fechaHora;

  const EventoPagoYape({
    required this.id,
    required this.origen,
    required this.empresa,
    required this.monto,
    required this.moneda,
    required this.pagador,
    required this.titulo,
    required this.mensaje,
    required this.fechaHora,
  });

  factory EventoPagoYape.desdeMapa(Map mapa) {
    final num montoNum = (mapa['monto'] is num)
        ? (mapa['monto'] as num)
        : (double.tryParse(mapa['monto']?.toString() ?? '0') ?? 0.0);

    final String tsTexto = mapa['timestamp']?.toString() ?? '';
    final DateTime fecha = DateTime.tryParse(tsTexto) ?? DateTime.now();

    return EventoPagoYape(
      id: mapa['id']?.toString() ?? 'YAPE-${DateTime.now().millisecondsSinceEpoch}',
      origen: mapa['origen']?.toString() ?? 'YAPE_BOLIVIA',
      empresa: mapa['empresa']?.toString() ?? 'Avrora Soft - Vibola LLC',
      monto: montoNum.toDouble(),
      moneda: mapa['moneda']?.toString() ?? 'BOB',
      pagador: mapa['pagador']?.toString() ?? 'Cliente Yape QR',
      titulo: mapa['titulo']?.toString() ?? 'Pago QR Recibido',
      mensaje: mapa['mensaje']?.toString() ?? '',
      fechaHora: fecha,
    );
  }
}

class YapeUdpService {
  static final YapeUdpService instance = YapeUdpService._interno();
  YapeUdpService._interno();

  RawDatagramSocket? _socket;
  final StreamController _controladorPagos = StreamController.broadcast();
  final Map _idsProcesados = {};
  bool _escuchando = false;
  int _puertoActivo = 45455;

  bool get estaEscuchando => _escuchando;
  int get puertoActivo => _puertoActivo;
  Stream get flujoPagos => _controladorPagos.stream;

  Future iniciarEscucha({int puerto = 45455}) async {
    if (_escuchando && _socket != null) {
      return;
    }

    _puertoActivo = puerto;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _puertoActivo,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _escuchando = true;

      debugPrint('AScafe UDP Receptor activo en el puerto $_puertoActivo');

      _socket!.listen(
        (RawSocketEvent evento) {
          if (evento == RawSocketEvent.read) {
            final Datagram? datagrama = _socket?.receive();
            if (datagrama != null) {
              _procesarDatagrama(datagrama);
            }
          }
        },
        onError: (Object error) {
          debugPrint('Error en socket UDP de AScafe: $error');
        },
        onDone: () {
          _escuchando = false;
        },
      );
    } catch (e) {
      _escuchando = false;
      debugPrint('No se pudo abrir el puerto UDP $_puertoActivo en AScafe: $e');
    }
  }

  void _procesarDatagrama(Datagram datagrama) {
    try {
      final String textoJson = utf8.decode(datagrama.data, allowMalformed: true).trim();
      if (textoJson.isEmpty) return;

      final dynamic decodificado = jsonDecode(textoJson);
      if (decodificado is! Map) return;

      final EventoPagoYape pago = EventoPagoYape.desdeMapa(decodificado);

      // Limpiar cache de IDs de hace mas de 90 segundos
      final DateTime ahora = DateTime.now();
      _idsProcesados.removeWhere((dynamic _, dynamic fechaGuardada) {
        final DateTime f = fechaGuardada as DateTime;
        return ahora.difference(f).inSeconds.compareTo(90) == 1;
      });

      // Ignorar los 2 paquetes de respaldo de la rafaga UDP si el primero ya entro
      if (_idsProcesados.containsKey(pago.id)) {
        return;
      }
      _idsProcesados[pago.id] = ahora;

      debugPrint(
        'PAGO YAPE VALIDADO EN ASCAFE: Bs. ${pago.monto.toStringAsFixed(2)} - Pagador: ${pago.pagador}',
      );

      _controladorPagos.add(pago);
    } catch (e) {
      debugPrint('Datagrama UDP descartado en AScafe: $e');
    }
  }

  /// Escucha y ejecuta [alConfirmarPago] automaticamente cuando entra un Yape
  /// cuyo monto coincide con [montoEsperado] (tolerancia de 1 centavo).
  StreamSubscription esperarPagoExacto({
    required double montoEsperado,
    required void Function(EventoPagoYape pagoConfirmado) alConfirmarPago,
  }) {
    if (!_escuchando) {
      iniciarEscucha(puerto: _puertoActivo);
    }

    return flujoPagos.listen((dynamic evento) {
      final EventoPagoYape pago = evento as EventoPagoYape;
      final double diferencia = (pago.monto - montoEsperado).abs();

      // Verifica que la diferencia sea menor a 0.015 (mismo monto exacto)
      if (diferencia.compareTo(0.015) == -1) {
        alConfirmarPago(pago);
      }
    });
  }

  void detenerEscucha() {
    _socket?.close();
    _socket = null;
    _escuchando = false;
  }
}