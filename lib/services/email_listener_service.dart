// Nombre del archivo: lib/services/email_listener_service.dart

import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import '../models/email_config.dart';

class EmailListenerService {
  Timer? _timer;
  bool _isChecking = false;
  bool _primeraSincronizacion = true;
  final Set<int> _idsProcesados = <int>{};

  final Function(double monto, String cliente, String fecha) onPagoDetectado;

  EmailListenerService({required this.onPagoDetectado});

  static Future probarConexion(EmailConfig config) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client
          .connectToServer(config.host, config.port, isSecure: config.useSsl)
          .timeout(const Duration(seconds: 12));
      await client
          .login(config.email, config.password)
          .timeout(const Duration(seconds: 12));
      final mailbox = await client
          .selectInbox()
          .timeout(const Duration(seconds: 10));
      final int totalMensajes = mailbox.messagesExists;
      await client.logout();
      return {
        'exito': true,
        'mensaje':
            '✅ Conexión IMAP exitosa (${config.host}:${config.port}). Bandeja de entrada accesible ($totalMensajes correos).',
      };
    } catch (e) {
      try {
        await client.disconnect();
      } catch (_) {}
      return {
        'exito': false,
        'mensaje': '❌ Error al conectar: $e',
      };
    }
  }

  void iniciarMonitoreo(EmailConfig config) {
    detenerMonitoreo();
    _primeraSincronizacion = true;
    _idsProcesados.clear();

    // Ejecuta la primera sincronización de inmediato para ignorar correos viejos
    _ejecutarCicloSeguro(config);

    // Revisa correos nuevos cada 10 segundos para respuesta rápida en caja
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _ejecutarCicloSeguro(config);
    });
  }

  Future _ejecutarCicloSeguro(EmailConfig config) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      await _revisarBandeja(config);
    } catch (_) {
      // Error controlado de red o credenciales
    } finally {
      _isChecking = false;
    }
  }

  void detenerMonitoreo() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatearFechaImapHoy() {
    const meses = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final ahora = DateTime.now();
    return '${ahora.day}-${meses[ahora.month - 1]}-${ahora.year}';
  }

  Future _revisarBandeja(EmailConfig config) async {
    final client = ImapClient(isLogEnabled: false);

    try {
      await client
          .connectToServer(config.host, config.port, isSecure: config.useSsl)
          .timeout(const Duration(seconds: 12));
      await client
          .login(config.email, config.password)
          .timeout(const Duration(seconds: 12));
      await client.selectInbox().timeout(const Duration(seconds: 10));

      final criterioFecha = 'UNSEEN SINCE ${_formatearFechaImapHoy()}';
      final searchResult = await client.searchMessages(
        searchCriteria: criterioFecha,
      );

      final sequence = searchResult.matchingSequence;
      if (sequence != null && sequence.isNotEmpty) {
        final ids = sequence.toList();

        // En el primer arranque registramos los correos ya existentes hoy sin lanzar ventanas
        if (_primeraSincronizacion) {
          for (final id in ids) {
            _idsProcesados.add(id);
          }
          _primeraSincronizacion = false;
          await client.logout();
          return;
        }

        // Filtramos únicamente los IDs que no hayan sido procesados en esta sesión
        final idsNuevos = ids.where((id) => !_idsProcesados.contains(id)).toList();

        if (idsNuevos.isNotEmpty) {
          // Registramos todos los IDs nuevos para no procesarlos dos veces
          for (final id in idsNuevos) {
            _idsProcesados.add(id);
          }

          final ultimoId = idsNuevos.last;
          final fetchResult = await client.fetchMessage(ultimoId, 'BODY.PEEK[]');

          if (fetchResult.messages.isNotEmpty) {
            final message = fetchResult.messages.first;
            final asunto = message.decodeSubject() ?? '';
            final textoPlano = message.decodeTextPlainPart() ?? '';
            final textoHtml = message.decodeTextHtmlPart() ?? '';

            final cuerpoCrudo = textoPlano.trim().isNotEmpty
                ? '$asunto\n$textoPlano'
                : '$asunto\n$textoHtml';

            final bodyLimpio = _limpiarTextoCorreo(cuerpoCrudo);
            final bodyUpper = bodyLimpio.toUpperCase();

            // Soporte extendido para Banco BISA (Aviso de recibo de dinero / Movimiento de cuenta), QR Simple y Yape
            if (bodyUpper.contains('QR') ||
                bodyUpper.contains('ABONO') ||
                bodyUpper.contains('RECIBO DE DINERO') ||
                bodyUpper.contains('MOVIMIENTO DE CUENTA') ||
                bodyUpper.contains('BISA') ||
                bodyUpper.contains('YAPE') ||
                bodyUpper.contains('TRANSFERENCIA') ||
                bodyUpper.contains('CREDITO') ||
                bodyUpper.contains('CRÉDITO') ||
                bodyUpper.contains('PAGO') ||
                bodyUpper.contains('DEPOSITO') ||
                bodyUpper.contains('DEPÓSITO')) {
              final double montoExtraido = _extraerMonto(bodyLimpio);
              final String clienteExtraido = _extraerCliente(bodyLimpio);

              try {
                await client.store(
                  MessageSequence.fromId(ultimoId),
                  [MessageFlags.seen],
                );
              } catch (_) {}

              onPagoDetectado(
                montoExtraido,
                clienteExtraido,
                DateTime.now().toIso8601String(),
              );
            }
          }
        }
      } else {
        _primeraSincronizacion = false;
      }

      await client.logout();
    } catch (_) {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  String _limpiarTextoCorreo(String input) {
    String sinEstilos = input
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>|</tr>|</div>|</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');

    sinEstilos = sinEstilos
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&aacute;', 'á')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&ntilde;', 'ñ');

    final lineas = sinEstilos
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lineas.join('\n');
  }

  double _extraerMonto(String cuerpo) {
    try {
      final patrones = [
        RegExp(
          r'(?:Monto|Importe|Valor|Total|Abono|Recibido|Crédito|Credito)\s*(?:de\s+la\s+transacci[oó]n|Recibido|Transferido|Pagado|Abonado)?\s*[:\-]?\s*(?:Bs\.?|BOB|BOLIVIANOS|\$)?\s*([\d]{1,3}(?:[\.,][\d]{3})*(?:[\.,][\d]{1,2})|[\d]+(?:[\.,][\d]{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:Bs\.?|BOB|BOLIVIANOS)\s*[:\-]?\s*([\d]{1,3}(?:[\.,][\d]{3})*(?:[\.,][\d]{1,2})|[\d]+(?:[\.,][\d]{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'([\d]{1,3}(?:[\.,][\d]{3})*(?:[\.,][\d]{2}))\s*(?:Bs\.?|BOB|BOLIVIANOS)',
          caseSensitive: false,
        ),
      ];

      for (final regExp in patrones) {
        final match = regExp.firstMatch(cuerpo);
        if (match != null && match.group(1) != null) {
          final valor = _normalizarNumero(match.group(1)!);
          if (valor > 0) return valor;
        }
      }
    } catch (_) {}
    return 0.0;
  }

  double _normalizarNumero(String rawInput) {
    String raw = rawInput.trim().replaceAll(RegExp(r'[^\d\.,]'), '');
    if (raw.isEmpty) return 0.0;

    if (raw.contains(',') && raw.contains('.')) {
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains(',')) {
      final partes = raw.split(',');
      if (partes.last.length == 2 || partes.last.length == 1) {
        raw = '${partes.sublist(0, partes.length - 1).join('')}.${partes.last}';
      } else {
        raw = raw.replaceAll(',', '');
      }
    }
    return double.tryParse(raw) ?? 0.0;
  }

  String _extraerCliente(String cuerpo) {
    try {
      final regExp = RegExp(
        r'(?:Origen|Ordenante|Remitente|Titular|Depositante|Nombre\s+del\s+Ordenante|Cuenta\s+Origen|Cliente|Pagador|Enviado\s+por|De)\s*[:\-]\s*([^\r\n]+)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(cuerpo);
      if (match != null && match.group(1) != null) {
        String nombre = match.group(1)!.trim();
        // Corta si en la misma línea vienen más etiquetas bancarias
        nombre = nombre
            .split(RegExp(
              r'\b(?:Monto|Importe|Cuenta|Banco|Fecha|Hora|Glosa|Referencia|Nro|Moneda|CI|NIT|Concepto|Detalle)\b',
              caseSensitive: false,
            ))
            .first
            .trim();

        if (nombre.length > 42) {
          nombre = nombre.substring(0, 42).trim();
        }
        if (nombre.isNotEmpty) return nombre;
      }
    } catch (_) {}
    return 'Cliente vía QR (Banco BISA)';
  }
}