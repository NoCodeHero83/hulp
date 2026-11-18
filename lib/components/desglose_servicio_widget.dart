import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/hulp_text_styles.dart';

/// Lee importes guardados; abrir este panel no cotiza ni modifica el cobro.
class DesgloseServicioWidget extends StatefulWidget {
  const DesgloseServicioWidget(
      {super.key, required this.solicitudId, this.actualizacion, this.cargar});
  final String solicitudId;
  final Object? actualizacion;
  final Future<Map<String, dynamic>> Function()? cargar;

  @override
  State<DesgloseServicioWidget> createState() => _DesgloseServicioWidgetState();
}

class _DesgloseServicioWidgetState extends State<DesgloseServicioWidget> {
  static const verde = Color(0xFF086349);
  static const _menta = Color(0xFFE8F1EA);
  static const _textoSecundario = HulpTextStyles.secondary;
  late Future<Map<String, dynamic>> _datos;
  bool _abierto = false;
  final _moneda =
      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 2);
  @override
  void didUpdateWidget(covariant DesgloseServicioWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_abierto &&
        (oldWidget.solicitudId != widget.solicitudId ||
            oldWidget.actualizacion != widget.actualizacion)) {
      _datos = _iniciarConsulta();
    }
  }

  Future<Map<String, dynamic>> _iniciarConsulta() {
    final consulta = _consultar();
    // El panel se monta en el siguiente frame; FutureBuilder mostrará el error.
    consulta.ignore();
    return consulta;
  }

  Future<Map<String, dynamic>> _consultar() async {
    if (widget.cargar != null) return widget.cargar!();
    final r = await SupaFlow.client.functions.invoke('solicitudes-finanzas',
        body: {'accion': 'desglose_app', 'id': widget.solicitudId});
    final data = Map<String, dynamic>.from(r.data as Map);
    if (data['version'] != 1) throw StateError('Desglose no disponible');
    return data;
  }

  void _recargar() => setState(() {
        _datos = _iniciarConsulta();
      });
  String _importe(dynamic valor) => _moneda.format(num.parse(valor.toString()));
  Widget _fila(String texto, dynamic valor,
      {bool total = false, bool descuento = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: LayoutBuilder(builder: (context, constraints) {
        final estilo = Theme.of(context).textTheme.bodyMedium!;
        final etiqueta = Text(texto,
            style: estilo.copyWith(
              color: total ? verde : _textoSecundario,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
            ));
        final importe = Text(
          '${descuento ? '− ' : ''}${_importe(valor)}',
          textAlign: TextAlign.end,
          style: estilo.copyWith(
            color: total ? verde : null,
            fontWeight: total ? FontWeight.w700 : FontWeight.w600,
          ),
        );
        final fontSize = MediaQuery.textScalerOf(context).scale(14);
        if (constraints.maxWidth < fontSize * 17) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [etiqueta, importe],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: etiqueta),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: importe),
          ],
        );
      }),
    );
  }

  Widget _nota(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 5),
      child: Text(text, style: const TextStyle(color: _textoSecundario)));

  Widget _bloque(Color color, Widget contenido) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: contenido,
      );
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD2D6CE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
            color: _menta,
            child: InkWell(
                onTap: () {
                  setState(() {
                    _abierto = !_abierto;
                    if (_abierto) _datos = _iniciarConsulta();
                  });
                },
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_outlined,
                          color: verde, size: 18),
                      const SizedBox(width: 9),
                      const Expanded(
                          child: Text('Desglose del precio',
                              style: TextStyle(
                                  color: verde,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700))),
                      Icon(_abierto ? Icons.expand_less : Icons.expand_more,
                          color: verde)
                    ])))),
        if (_abierto)
          FutureBuilder<Map<String, dynamic>>(
              future: _datos,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        const Text('No se pudo cargar el desglose.'),
                        TextButton(
                            onPressed: _recargar,
                            child: const Text('Reintentar'))
                      ]));
                }
                if (!snapshot.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))));
                }
                final d = snapshot.data!;
                return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _bloque(
                            const Color(0xFFF1F2F3),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _fila('Servicio', d['precio']),
                                _fila('Materiales', d['materiales_total']),
                                for (final item in (d['items'] as List? ?? [])
                                    .where((i) => i['tipo_item'] == 'material'))
                                  _nota(
                                      '${item['descripcion']} · ${item['cantidad']} × ${_importe(item['precio_unitario'])}'),
                                _fila('Ajuste IVA', d['ajuste_iva_valor']),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          _fila('Subtotal', d['subtotal']),
                          _fila('Recargo Wompi (5 %)', d['wompi_valor']),
                          const Divider(),
                          _fila('Total del servicio', d['total_cliente'],
                              total: true),
                          if (num.parse(d['wompi_valor'].toString()) > 0)
                            _nota(
                                'El recargo aplica a tarjeta, Nequi y otros pagos por Wompi.'),
                          if ((d['pagos'] as List? ?? []).isNotEmpty) ...[
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 9),
                              child: Text('Pagos realizados',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            for (final pago in d['pagos'] as List) ...[
                              _fila(
                                  pago['recibo_id'] == null
                                      ? 'Pago del servicio'
                                      : 'Recibo del chat · ${pago['titulo']}',
                                  pago['monto'],
                                  descuento: true),
                              if (pago['recibo_id'] != null)
                                _nota(
                                    'Pagado · Incluye el recargo aplicado al cobro.'),
                            ],
                            _fila('Total pagado', d['pagos_realizados']),
                            const Divider(),
                          ],
                          const SizedBox(height: 4),
                          _bloque(
                            _menta,
                            _fila('Saldo pendiente', d['saldo_pendiente'],
                                total: true),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Chip(
                                  avatar: Icon(
                                      num.parse(d['saldo_pendiente']
                                                  .toString()) <=
                                              0
                                          ? Icons.check_circle_outline
                                          : Icons.payment,
                                      color: verde,
                                      size: 18),
                                  label: Text(
                                      num.parse(
                                                  d[
                                                          'saldo_pendiente']
                                                      .toString()) <=
                                              0
                                          ? 'Pago recibido'
                                          : 'Pago pendiente'),
                                  labelStyle:
                                      Theme.of(context).textTheme.bodyMedium,
                                  side: BorderSide.none,
                                  backgroundColor: _menta),
                              TextButton.icon(
                                  onPressed: _recargar,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Actualizar'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: verde,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .bodyMedium)),
                            ],
                          ),
                        ]));
              }),
      ]));
}
