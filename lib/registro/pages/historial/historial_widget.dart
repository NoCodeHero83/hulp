import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/hulp_text_styles.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/components/desglose_servicio_widget.dart';
import '/components/encabezado_principal_widget.dart';
import '/components/menu_bar_widget.dart';
import '/components/notificaciones_modal_widget.dart';
import '/components/resenas_widget.dart';
import '/flutter_flow/estado_solicitud_cliente.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart' show ChatWidget;
import 'historial_model.dart';

export 'historial_model.dart';

const _fondo = HulpColors.background;
const _tarjeta = HulpColors.surface;
const _tinta = HulpTextStyles.primary;
const _secundario = HulpTextStyles.secondary;
const _verde = HulpTextStyles.link;
const _menta = HulpColors.brandSoft;
const _borde = HulpColors.border;
const _rojo = HulpTextStyles.error;
const _soporte = 'https://wa.me/573104829808';

class HistorialWidget extends StatefulWidget {
  const HistorialWidget({super.key});

  static String routeName = 'Historial';
  static String routePath = '/historial';

  @override
  State<HistorialWidget> createState() => _HistorialWidgetState();
}

class _TarjetaSolicitud extends StatefulWidget {
  const _TarjetaSolicitud({
    super.key,
    required this.solicitud,
    required this.estado,
    required this.usuarioId,
    required this.abierta,
    required this.onExpandir,
    required this.onActualizar,
  });

  final VwSolicitudesServiciosCompletaRow solicitud;
  final String estado;
  final String usuarioId;
  final bool abierta;
  final VoidCallback onExpandir;
  final VoidCallback onActualizar;

  @override
  State<_TarjetaSolicitud> createState() => _TarjetaSolicitudState();
}

class _TarjetaSolicitudState extends State<_TarjetaSolicitud> {
  Future<int>? _sinLeer;

  VwSolicitudesServiciosCompletaRow get _solicitud => widget.solicitud;
  String get _servicio =>
      valueOrDefault(_solicitud.servicioNombre?.trim(), 'Servicio');
  bool get _tieneChat =>
      (_solicitud.profesionalId?.isNotEmpty ?? false) &&
      (_solicitud.solicitudId?.isNotEmpty ?? false) &&
      widget.usuarioId.isNotEmpty;
  bool get _permiteCambios =>
      const {'entrantes', 'aceptadas'}.contains(_solicitud.estadoSolicitud);

  Future<int> _consultarSinLeer() async {
    if (!_tieneChat) return 0;
    final filas = await VwMensajesNoLeidosPorParticipanteTable().queryRows(
      queryFn: (q) => q
          .eq('usuario_id', widget.usuarioId)
          .eq('solicitud_id', _solicitud.solicitudId!),
      limit: 1,
    );
    return filas.firstOrNull?.cantidadNoLeidos ?? 0;
  }

  @override
  void didUpdateWidget(covariant _TarjetaSolicitud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.abierta ||
        oldWidget.usuarioId != widget.usuarioId ||
        oldWidget.solicitud.solicitudId != _solicitud.solicitudId ||
        oldWidget.solicitud.profesionalId != _solicitud.profesionalId) {
      _sinLeer = null;
    }
  }

  Future<void> _abrirChat() async {
    await context.pushNamed<void>(
      ChatWidget.routeName,
      queryParameters: {
        'servicio': serializeParam(_solicitud, ParamType.SupabaseRow),
      }.withoutNulls,
      extra: const {
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(milliseconds: 500),
        ),
      },
    );
    if (mounted && widget.abierta) {
      setState(() => _sinLeer = null);
    }
  }

  Future<void> _pedirCambio(String accion) => _mostrarDialogo(
        NotificacionesModalWidget(
          titulo: '$accion servicio',
          descripcion: '¿Está seguro de ${accion.toLowerCase()} el servicio?',
          estadosucess: false,
          textobutton: accion,
          action1: () => launchURL(
            '$_soporte?text=${Uri.encodeComponent('Hola, quiero ${accion.toLowerCase()} mi servicio.')}',
          ),
        ),
      );

  Future<void> _puntuar(String id) async {
    await _mostrarDialogo(ResenasWidget(idsolicitud: id));
    if (mounted) widget.onActualizar();
  }

  Future<void> _mostrarDialogo(Widget contenido) => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: contenido,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      side: const BorderSide(color: _borde),
      borderRadius: BorderRadius.circular(13),
    );
    return Material(
      color: _tarjeta,
      shape: forma,
      elevation: 1.5,
      shadowColor: const Color(0x26000000),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: widget.abierta,
            child: InkWell(
              onTap: widget.onExpandir,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: _resumen(context),
              ),
            ),
          ),
          if (widget.abierta) _detalles(),
        ],
      ),
    );
  }

  Widget _resumen(BuildContext context) {
    final fecha = _solicitud.fecha;
    final hora = _solicitud.hora?.time;
    final cita = [
      if (fecha != null)
        DateFormat('d MMM', 'es').format(fecha).replaceAll('.', ''),
      if (hora != null) DateFormat('HH:mm').format(hora),
    ].join(' · ');
    final pastilla = _PastillaEstado(widget.estado);
    return LayoutBuilder(
      builder: (context, medidas) {
        final estadoDebajo = medidas.maxWidth < 305 ||
            MediaQuery.textScalerOf(context).scale(14) > 17;
        return Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _menta,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: FaIcon(_iconoServicio(), size: 25, color: _verde),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 48, color: _borde),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_solicitud.ticket != null)
                    Text(
                      '#${_solicitud.ticket}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  Text(
                    _servicio,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (cita.isNotEmpty)
                    Text(cita,
                        style:
                            const TextStyle(color: _secundario, fontSize: 13)),
                  if (estadoDebajo) ...[const SizedBox(height: 4), pastilla],
                ],
              ),
            ),
            if (!estadoDebajo) ...[const SizedBox(width: 6), pastilla],
            const SizedBox(width: 9),
            Icon(
              widget.abierta
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: _tinta,
              size: 22,
            ),
          ],
        );
      },
    );
  }

  IconData _iconoServicio() {
    final nombre = [
      _solicitud.servicioNombre,
      _solicitud.subcategoriaNombre,
      _solicitud.categoriaNombre,
    ].whereType<String>().join(' ').toLowerCase();
    if (nombre.contains('jardin') || nombre.contains('césped')) {
      return FontAwesomeIcons.leaf;
    }
    if (nombre.contains('tuber') ||
        nombre.contains('plomer') ||
        nombre.contains('fontaner')) {
      return FontAwesomeIcons.faucetDrip;
    }
    return FontAwesomeIcons.screwdriverWrench;
  }

  Widget _detalles() {
    final id = _solicitud.solicitudId;
    final fecha = _solicitud.fecha;
    final hora = _solicitud.hora?.time;
    final muestraDesglose =
        _solicitud.finanzasVersion == 1 && id != null && id.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _menta,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Detalles de la solicitud',
              style: TextStyle(
                  color: _verde, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          _filaDetalle(
              Icons.person_outline,
              'Proveedor',
              valueOrDefault(
                  _solicitud.proveedorNombreCompleto?.trim(), 'Sin asignar')),
          _filaDetalle(Icons.work_outline, 'Servicio', _servicio),
          _filaDetalle(
              Icons.calendar_today_outlined,
              'Fecha',
              fecha == null
                  ? 'Sin fecha'
                  : DateFormat.yMMMMd('es').format(fecha)),
          _filaDetalle(Icons.access_time, 'Hora',
              hora == null ? 'Sin hora' : DateFormat('HH:mm').format(hora)),
          _filaDetalle(Icons.location_on_outlined, 'Dirección',
              valueOrDefault(_solicitud.ubicacion?.trim(), 'Sin dirección')),
          const SizedBox(height: 6),
          if (muestraDesglose)
            DesgloseServicioWidget(
              solicitudId: id,
              actualizacion:
                  '${_solicitud.finanzasRevision}:${_solicitud.estadoPago}',
            )
          else
            _filaDetalle(
              Icons.receipt_long_outlined,
              'Precio',
              _solicitud.finanzasVersion == 1
                  ? 'No disponible'
                  : NumberFormat.currency(locale: 'es_CO', symbol: r'$')
                      .format(_solicitud.precioCalculado ?? 0),
            ),
          const SizedBox(height: 2),
          _acciones(id),
        ],
      ),
    );
  }

  Widget _filaDetalle(IconData icono, String etiqueta, String valor) {
    final etiquetaTexto = Text(
      etiqueta,
      style: HulpTextStyles.body.copyWith(color: _secundario),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: LayoutBuilder(builder: (context, constraints) {
        final fontSize = MediaQuery.textScalerOf(context).scale(14);
        final apilar = constraints.maxWidth < fontSize * 15;
        final valorTexto = Text(
          valor,
          textAlign: apilar ? TextAlign.start : TextAlign.end,
          style: HulpTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        );
        if (apilar) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 17, color: _secundario),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [etiquetaTexto, valorTexto],
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 17, color: _secundario),
            const SizedBox(width: 9),
            Expanded(flex: 2, child: etiquetaTexto),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: valorTexto),
          ],
        );
      }),
    );
  }

  Widget _acciones(String? id) {
    final principales = [
      if (_tieneChat)
        FutureBuilder<int>(
          future: _sinLeer ??= _consultarSinLeer(),
          builder: (context, snapshot) => _AccionSolicitud(
            icono: Icons.chat_bubble_outline,
            texto: 'Chat',
            sinLeer: snapshot.data ?? 0,
            onPressed: _abrirChat,
          ),
        ),
      _AccionSolicitud(
        icono: FontAwesomeIcons.whatsapp,
        texto: 'Soporte',
        onPressed: () => launchURL(_soporte),
      ),
      if (_solicitud.estadoSolicitud == 'finalizadas' &&
          _solicitud.puntuacion == null &&
          id != null &&
          id.isNotEmpty)
        _AccionSolicitud(
          icono: Icons.star_border_rounded,
          texto: 'Puntuar servicio',
          onPressed: () => _puntuar(id),
        ),
    ];
    final cambios = [
      if (_permiteCambios) ...[
        _AccionSolicitud(
          icono: Icons.calendar_today_outlined,
          texto: 'Reprogramar',
          color: _verde,
          onPressed: () => _pedirCambio('Reprogramar'),
        ),
        _AccionSolicitud(
          icono: Icons.delete_outline,
          texto: 'Cancelar',
          color: _rojo,
          onPressed: () => _pedirCambio('Cancelar'),
        ),
      ],
    ];

    if (principales.length + cambios.length <= 3) {
      return _filaAcciones([...principales, ...cambios]);
    }
    return Column(
      children: [_filaAcciones(principales), _filaAcciones(cambios)],
    );
  }

  Widget _filaAcciones(List<Widget> acciones) {
    return LayoutBuilder(
      builder: (context, medidas) {
        if (MediaQuery.textScalerOf(context).scale(12) > 12) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 4,
            children: acciones,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: medidas.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 7,
              children: acciones,
            ),
          ),
        );
      },
    );
  }
}

class _PastillaEstado extends StatelessWidget {
  const _PastillaEstado(this.estado);

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (estado) {
      'Aceptado' || 'Finalizado' => (
          const Color(0xFFD8F6D8),
          const Color(0xFF08752B)
        ),
      'Pendiente' => (const Color(0xFFFFEDB7), const Color(0xFF7C5700)),
      'Activo' => (const Color(0xFFD9E9FB), const Color(0xFF15579C)),
      'En curso' => (const Color(0xFFFFE9D1), const Color(0xFF844411)),
      'Cancelado' || 'Reagendada' || 'Reagendado' => (
          const Color(0xFFF9DFE2),
          _rojo
        ),
      _ => (const Color(0xFFEDEAEA), _secundario),
    };
    return DecoratedBox(
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          estado,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: texto, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AccionSolicitud extends StatelessWidget {
  const _AccionSolicitud({
    required this.icono,
    required this.texto,
    required this.onPressed,
    this.color = _tinta,
    this.sinLeer = 0,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;
  final Color color;
  final int sinLeer;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icono, size: 15),
      label: sinLeer == 0
          ? Text(texto)
          : Badge(
              backgroundColor: const Color(0xFFBC4B12),
              offset: const Offset(8, -8),
              label: Text(sinLeer > 99 ? '99+' : '$sinLeer'),
              child: Padding(
                padding: const EdgeInsets.only(right: 11),
                child: Text(texto),
              ),
            ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 32),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: HulpTextStyles.compact,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        side: const BorderSide(color: Color(0xFFB8B5B5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _HistorialWidgetState extends State<HistorialWidget> {
  late final HistorialModel _model;
  final _auth = AppStateNotifier.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _cambios;
  late Future<List<VwSolicitudesServiciosCompletaRow>> _solicitudes;
  String _usuarioId = '';
  PestanaSolicitudes _pestana = PestanaSolicitudes.enProceso;
  String? _tarjetaAbierta;
  final _filtros = {
    for (final pestana in PestanaSolicitudes.values)
      pestana: const FiltrosSolicitudes(masRecientes: true),
  };

  @override
  void initState() {
    super.initState();
    _model = createModel(context, HistorialModel.new);
    _conectarUsuario();
    _auth.addListener(_actualizarUsuario);
  }

  void _actualizarUsuario() {
    if (_usuarioId == currentUserUid) return;
    setState(() {
      _tarjetaAbierta = null;
      _conectarUsuario();
    });
  }

  void _conectarUsuario() {
    unawaited(_cambios?.cancel());
    final uid = currentUserUid;
    _usuarioId = uid;
    _solicitudes = _consultarSolicitudes();
    if (uid.isEmpty) return;

    _cambios = SupaFlow.solicitudesStream().eq('usuario_id', uid).listen((_) {
      if (mounted && _usuarioId == uid) _recargar();
    }, onError: (Object error, StackTrace trace) {
      debugPrint('No se pudo escuchar el estado de las solicitudes: $error');
    });
  }

  Future<List<VwSolicitudesServiciosCompletaRow>> _consultarSolicitudes() {
    final uid = _usuarioId;
    if (uid.isEmpty) return Future.value([]);
    return VwSolicitudesServiciosCompletaTable().queryRows(
      queryFn: (q) => q.eq('usuario_id', uid),
    );
  }

  void _recargar() => setState(() => _solicitudes = _consultarSolicitudes());

  @override
  void dispose() {
    _auth.removeListener(_actualizarUsuario);
    unawaited(_cambios?.cancel());
    _model.dispose();
    super.dispose();
  }

  bool get _enProceso => _pestana == PestanaSolicitudes.enProceso;

  FiltrosSolicitudes get _filtro => _filtros[_pestana]!;

  String _estado(VwSolicitudesServiciosCompletaRow solicitud) =>
      estadoVisibleDeSolicitud(
        solicitud.estadoSolicitud,
        sprint3: usaEstadosSprint3Cliente,
      );

  Future<void> _abrirFiltros() async {
    FocusScope.of(context).unfocus();
    final pestana = _pestana;
    final estados = _enProceso
        ? [
            'Pendiente',
            if (usaEstadosSprint3Cliente) 'Aceptado',
            'Activo',
            'En curso',
          ]
        : [
            'Finalizado',
            'Cancelado',
            if (usaEstadosSprint3Cliente) 'Reagendada' else 'Reagendado',
          ];
    final resultado = await showModalBottomSheet<FiltrosSolicitudes>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _tarjeta,
      builder: (context) => _PanelFiltros(
        filtro: _filtro,
        estados: estados,
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _filtros[pestana] = resultado;
      _tarjetaAbierta = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: HulpTextStyles.textTheme,
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _verde),
      ),
      child: Scaffold(
        backgroundColor: _fondo,
        resizeToAvoidBottomInset: false,
        appBar: const EncabezadoPrincipalWidget(titulo: 'Mis solicitudes'),
        bottomNavigationBar: const MenuBarWidget(index: 2),
        body: FutureBuilder<List<VwSolicitudesServiciosCompletaRow>>(
          key: ValueKey(_usuarioId),
          future: _solicitudes,
          builder: (context, snapshot) {
            final pendientes = snapshot.data
                ?.where((fila) =>
                    pestanaDeSolicitud(fila.estadoSolicitud) ==
                    PestanaSolicitudes.enProceso)
                .length;
            final cabecera = _cabecera(pendientes);
            if (MediaQuery.textScalerOf(context).scale(14) > 18) {
              return CustomScrollView(
                key: PageStorageKey(_pestana),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: cabecera),
                  _contenido(snapshot),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cabecera,
                Expanded(
                  child: CustomScrollView(
                    key: PageStorageKey(_pestana),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [_contenido(snapshot)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cabecera(int? pendientes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _borde),
              borderRadius: BorderRadius.circular(11),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _botonPestana(
                  PestanaSolicitudes.enProceso,
                  pendientes == null
                      ? 'En proceso'
                      : 'En proceso ($pendientes)',
                ),
                _botonPestana(PestanaSolicitudes.historial, 'Historial'),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: _borde),
          const SizedBox(height: 10),
          Text(
            _enProceso ? 'Tus próximos servicios' : 'Historial de servicios',
            style: HulpTextStyles.section,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _model.busqueda,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Buscar servicio...',
                    hintStyle: const TextStyle(color: _secundario),
                    prefixIcon:
                        const Icon(Icons.search_rounded, ),
                    suffixIcon: _model.busqueda.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            onPressed: () => setState(_model.busqueda.clear),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    isDense: true,
                    constraints: const BoxConstraints(minHeight: 44),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: _bordeBusqueda(_borde),
                    enabledBorder: _bordeBusqueda(_borde),
                    focusedBorder: _bordeBusqueda(_verde),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _abrirFiltros,
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: const Text('Filtrar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tinta,
                  backgroundColor:
                      _filtro.estado != null || _filtro.fechas != null
                          ? _menta
                          : null,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: _borde),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _bordeBusqueda(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  Widget _botonPestana(PestanaSolicitudes pestana, String texto) {
    final seleccionada = _pestana == pestana;
    final forma = BorderRadius.circular(10);
    return Expanded(
      child: Semantics(
        selected: seleccionada,
        button: true,
        child: Material(
          color: seleccionada ? _verde : Colors.transparent,
          borderRadius: forma,
          child: InkWell(
            borderRadius: forma,
            onTap: () {
              if (seleccionada) return;
              FocusScope.of(context).unfocus();
              setState(() {
                _pestana = pestana;
                _tarjetaAbierta = null;
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Center(
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: seleccionada ? Colors.white : _tinta,
                      fontWeight:
                          seleccionada ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(
      AsyncSnapshot<List<VwSolicitudesServiciosCompletaRow>> snapshot) {
    if (snapshot.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No pudimos cargar tus solicitudes.'),
            TextButton(onPressed: _recargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (!snapshot.hasData) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _verde)),
      );
    }

    final busqueda = _model.busqueda.text.trim().toLowerCase();
    final filas = snapshot.data!
        .where((fila) =>
            pestanaDeSolicitud(fila.estadoSolicitud) == _pestana &&
            _filtro.coincide(fila, _estado(fila), busqueda))
        .toList()
      ..sort(_filtro.comparar);
    if (filas.isEmpty) {
      final filtrando = busqueda.isNotEmpty ||
          _filtro.estado != null ||
          _filtro.fechas != null;
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          filtrando
              ? 'No hay solicitudes que coincidan.'
              : _enProceso
                  ? 'No tienes solicitudes en proceso.'
                  : 'Aún no tienes solicitudes en el historial.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _secundario),
        ),
      ));
    }
    return SliverPadding(
        padding: const EdgeInsets.fromLTRB(13, 17, 13, 20),
        sliver: SliverList.separated(
          itemCount: filas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final fila = filas[index];
            final clave = fila.solicitudId ?? 'ticket:${fila.ticket ?? index}';
            final abierta = _tarjetaAbierta == clave;
            return _TarjetaSolicitud(
              key: ValueKey(clave),
              solicitud: fila,
              estado: _estado(fila),
              usuarioId: _usuarioId,
              abierta: abierta,
              onExpandir: () {
                FocusScope.of(context).unfocus();
                setState(() => _tarjetaAbierta = abierta ? null : clave);
              },
              onActualizar: _recargar,
            );
          },
        ));
  }
}

class _PanelFiltros extends StatefulWidget {
  const _PanelFiltros({
    required this.filtro,
    required this.estados,
  });

  final FiltrosSolicitudes filtro;
  final List<String> estados;

  @override
  State<_PanelFiltros> createState() => _PanelFiltrosState();
}

class _PanelFiltrosState extends State<_PanelFiltros> {
  String? _estado;
  DateTimeRange? _fechas;
  late bool _masRecientes;

  @override
  void initState() {
    super.initState();
    _estado = widget.filtro.estado;
    _fechas = widget.filtro.fechas;
    _masRecientes = widget.filtro.masRecientes;
  }

  Future<void> _elegirFechas() async {
    final hoy = DateTime.now();
    final fechas = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 100),
      lastDate: DateTime(hoy.year + 100, 12, 31),
      initialDateRange: _fechas,
      helpText: 'Fecha del servicio',
    );
    if (fechas != null && mounted) setState(() => _fechas = fechas);
  }

  void _limpiar() => setState(() {
        _estado = null;
        _fechas = null;
        _masRecientes = true;
      });

  ChoiceChip _opcion(String texto, bool seleccionada, VoidCallback accion) {
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionada,
      showCheckmark: false,
      onSelected: (_) => accion(),
      backgroundColor: _tarjeta,
      selectedColor: _menta,
      side: BorderSide(color: seleccionada ? _verde : _borde),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: seleccionada ? _verde : _tinta,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechas = _fechas;
    final formato = DateFormat('d MMM yyyy', 'es');
    final titulo = HulpTextStyles.card.copyWith(color: _tinta);
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: HulpTextStyles.textTheme,
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _verde),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borde,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar solicitudes',
                      style: HulpTextStyles.section.copyWith(color: _tinta),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: _tinta),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text('Estado', style: titulo),
              Wrap(
                spacing: 6,
                children: [
                  for (final estado in [null, ...widget.estados])
                    _opcion(estado ?? 'Todos', _estado == estado,
                        () => setState(() => _estado = estado)),
                ],
              ),
              const Divider(color: _borde),
              Text('Fecha del servicio', style: titulo),
              Wrap(
                spacing: 6,
                children: [
                  _opcion('Todas las fechas', fechas == null,
                      () => setState(() => _fechas = null)),
                  _opcion('Elegir rango', fechas != null, _elegirFechas),
                ],
              ),
              if (fechas != null)
                Text(
                  '${formato.format(fechas.start)} – ${formato.format(fechas.end)}',
                  style: const TextStyle(color: _secundario),
                ),
              const Divider(color: _borde),
              Text('Ordenar por', style: titulo),
              Wrap(
                spacing: 6,
                children: [
                  _opcion('Más recientes', _masRecientes,
                      () => setState(() => _masRecientes = true)),
                  _opcion('Más antiguos', !_masRecientes,
                      () => setState(() => _masRecientes = false)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _limpiar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _verde,
                        side: const BorderSide(color: _verde),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        FiltrosSolicitudes(
                          estado: _estado,
                          fechas: fechas,
                          masRecientes: _masRecientes,
                        ),
                      ),
                      style: FilledButton.styleFrom(backgroundColor: _verde),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
