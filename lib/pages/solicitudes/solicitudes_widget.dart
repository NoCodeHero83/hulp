import '/backend/transiciones_solicitud.dart';
import '/backend/solicitudes_stream.dart';
import '/components/desglose_servicio_widget.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/cancelar_servicio_widget.dart';
import '/components/enlace_mapa_widget.dart';
import '/flutter_flow/filtros_seguros.dart';
import '/components/nombre_cliente_widget.dart';
import '/components/finalizar_servicio_widget.dart';
import '/components/lista_vacia_widget.dart';
import '/components/men_widget.dart';
import '/components/nueva_version_widget.dart';
import '/components/servicio_asignado_inicio_widget.dart';
import '/components/soporte_seleccion_widget.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/hulp_text_styles.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'solicitudes_model.dart';
export 'solicitudes_model.dart';

class SolicitudesWidget extends StatefulWidget {
  const SolicitudesWidget({super.key});

  static String routeName = 'Solicitudes';
  static String routePath = '/solicitudes';

  @override
  State<SolicitudesWidget> createState() => _SolicitudesWidgetState();
}

enum _PestanaSolicitudesProveedor { entrantes, aceptadas, historial }

const _ofertasValidadasEnServidor =
    FFDevEnvironmentValues.currentEnvironment == 'Test';

IconData _iconoServicioSolicitud(String? nombre) {
  final servicio = nombre?.toLowerCase() ?? '';
  if (servicio.contains('limpieza') ||
      servicio.contains('aseo') ||
      servicio.contains('lavado')) {
    return Icons.cleaning_services_outlined;
  }
  if (servicio.contains('plomer') || servicio.contains('tuber')) {
    return Icons.plumbing_outlined;
  }
  if (servicio.contains('jard') || servicio.contains('césped')) {
    return Icons.grass_outlined;
  }
  if (servicio.contains('electric')) return Icons.electrical_services_outlined;
  if (servicio.contains('pint')) return Icons.format_paint_outlined;
  return Icons.home_repair_service_outlined;
}

Widget _iconoTarjetaServicio(String? nombre) => Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: HulpColors.brandSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(
        _iconoServicioSolicitud(nombre),
        color: HulpColors.brand,
        size: 25,
      ),
    );

class _FiltrosSolicitudesProveedor {
  const _FiltrosSolicitudesProveedor({
    this.estado,
    this.fechas,
    this.masRecientes = true,
  });

  final String? estado;
  final DateTimeRange? fechas;
  final bool masRecientes;
}

class _SolicitudesWidgetState extends State<SolicitudesWidget> {
  late SolicitudesModel _model;
  StreamSubscription<List<SolicitudesServicioRow>>? _conexionEntrantes;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _transicionesPendientes = <String>{};
  final _tarjetasExpandidas = <String>{};
  final _clientesEnPrecarga = <String>{};
  final _busquedaSolicitudes = TextEditingController();
  _PestanaSolicitudesProveedor _pestana =
      _PestanaSolicitudesProveedor.entrantes;
  final _filtros = <_PestanaSolicitudesProveedor, _FiltrosSolicitudesProveedor>{
    _PestanaSolicitudesProveedor.entrantes:
        const _FiltrosSolicitudesProveedor(),
    _PestanaSolicitudesProveedor.aceptadas:
        const _FiltrosSolicitudesProveedor(),
    _PestanaSolicitudesProveedor.historial:
        const _FiltrosSolicitudesProveedor(),
  };

  _FiltrosSolicitudesProveedor get _filtro => _filtros[_pestana]!;

  void _alternarTarjetaSolicitud(String clave) {
    setState(() {
      if (!_tarjetasExpandidas.add(clave)) {
        _tarjetasExpandidas.remove(clave);
      }
    });
  }

  void _precargarNombresClientes(Iterable<SolicitudesServicioRow> solicitudes) {
    final ids = solicitudes
        .map((solicitud) => solicitud.usuarioId)
        .whereType<String>()
        .where((id) =>
            NombreClienteWidget.nombreEnCache(id) == null &&
            _clientesEnPrecarga.add(id))
        .toList();
    if (ids.isEmpty) return;

    unawaited(NombreClienteWidget.precargarNombres(ids).whenComplete(() {
      _clientesEnPrecarga.removeAll(ids);
      if (mounted) safeSetState(() {});
    }));
  }

  Widget _cabeceraDetalleSolicitud() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HulpColors.brandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                color: HulpColors.brand, size: 18),
            const SizedBox(width: 8),
            Text(
              'Detalles de la solicitud',
              style: HulpTextStyles.card.copyWith(color: HulpColors.brand),
            ),
          ],
        ),
      );

  List<String> get _estadosDelFiltro => switch (_pestana) {
        _PestanaSolicitudesProveedor.entrantes => ['Pendiente'],
        _PestanaSolicitudesProveedor.aceptadas => [
            if (usaTransicionesSprint3) 'Aceptado' else 'Activo',
            if (usaTransicionesSprint3) 'Activo',
            'En curso',
          ],
        _PestanaSolicitudesProveedor.historial => [
            'Finalizado',
            'Cancelado',
            if (usaTransicionesSprint3) 'Reagendada' else 'Reagendado',
          ],
      };

  bool get _hayFiltrosActivos =>
      _filtro.estado != null || _filtro.fechas != null;

  bool _esEntrante(SolicitudesServicioRow solicitud) =>
      solicitud.estado == 'entrantes';

  bool _esAceptada(SolicitudesServicioRow solicitud) => const {
        'aceptadas',
        'iniciadas',
        'en camino',
        'en proceso',
      }.contains(solicitud.estado);

  bool _esHistorial(SolicitudesServicioRow solicitud) => const {
        'finalizadas',
        'canceladas',
        'cancelada',
        'reagendada',
        'reagendadas',
      }.contains(solicitud.estado);

  bool _esEntranteDisponible(
    SolicitudesServicioRow solicitud,
    List<ProfesionalServiciosRow> servicios,
  ) {
    if (!_esEntrante(solicitud)) return false;
    if (_ofertasValidadasEnServidor) return true;
    if (!usaTransicionesSprint3) return _model.esDeMiCiudad(solicitud.ciudadId);
    if (solicitud.profesionalId != null) {
      return solicitud.profesionalId == currentUserUid;
    }
    return (_model.switchValue ?? true) &&
        _model.ciudadIdProveedor != null &&
        solicitud.ciudadId == _model.ciudadIdProveedor &&
        servicios
            .any((servicio) => servicio.servicioId == solicitud.servicioId);
  }

  String _estadoVisible(String estado) {
    if (usaTransicionesSprint3) return etiquetaEstadoSolicitud(estado);
    return switch (estado) {
      'entrantes' => 'Pendiente',
      'aceptadas' => 'Activo',
      'iniciadas' || 'en camino' || 'en proceso' => 'En curso',
      'finalizadas' => 'Finalizado',
      'canceladas' || 'cancelada' => 'Cancelado',
      'reagendada' || 'reagendadas' => 'Reagendado',
      _ => etiquetaEstadoSolicitud(estado),
    };
  }

  bool _coincideFiltro(SolicitudesServicioRow solicitud) {
    final estado = _filtro.estado;
    if (estado != null && _estadoVisible(solicitud.estado) != estado) {
      return false;
    }
    final fechas = _filtro.fechas;
    if (fechas != null) {
      final dia = DateUtils.dateOnly(solicitud.fecha);
      if (dia.isBefore(fechas.start) || dia.isAfter(fechas.end)) return false;
    }
    final busqueda = _busquedaSolicitudes.text.trim().toLowerCase();
    if (busqueda.isEmpty) return true;
    final ticketBuscado =
        busqueda.startsWith('#') ? busqueda.substring(1) : busqueda;
    final nombreCliente =
        NombreClienteWidget.nombreEnCache(solicitud.usuarioId)?.toLowerCase() ??
            '';
    return (solicitud.servicioNombre ?? '').toLowerCase().contains(busqueda) ||
        nombreCliente.contains(busqueda) ||
        (solicitud.ticket?.toString() ?? '').contains(ticketBuscado);
  }

  int _compararSolicitudes(SolicitudesServicioRow a, SolicitudesServicioRow b) {
    final ticketA = a.ticket;
    final ticketB = b.ticket;
    if (ticketA == null) return ticketB == null ? 0 : 1;
    if (ticketB == null) return -1;
    return _filtro.masRecientes
        ? ticketB.compareTo(ticketA)
        : ticketA.compareTo(ticketB);
  }

  Future<void> _abrirFiltros() async {
    FocusScope.of(context).unfocus();
    final resultado = await showModalBottomSheet<_FiltrosSolicitudesProveedor>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (_) => _PanelFiltrosSolicitudesProveedor(
        filtro: _filtro,
        estados: _estadosDelFiltro,
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() => _filtros[_pestana] = resultado);
  }

  Widget _pestanasSolicitudes({
    required int entrantes,
    required int aceptadas,
    required int historial,
  }) {
    final borde = FlutterFlowTheme.of(context).alternate;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _botonPestana(
              _PestanaSolicitudesProveedor.entrantes, 'Entrantes ($entrantes)'),
          _botonPestana(
              _PestanaSolicitudesProveedor.aceptadas, 'Aceptadas ($aceptadas)'),
          _botonPestana(
              _PestanaSolicitudesProveedor.historial, 'Historial ($historial)'),
        ],
      ),
    );
  }

  Widget _botonPestana(_PestanaSolicitudesProveedor pestana, String texto) {
    final seleccionada = _pestana == pestana;
    final color = FlutterFlowTheme.of(context).primary;
    final forma = BorderRadius.circular(9);
    return Expanded(
      child: Semantics(
        selected: seleccionada,
        button: true,
        child: Material(
          color: seleccionada ? color : Colors.transparent,
          borderRadius: forma,
          child: InkWell(
            borderRadius: forma,
            onTap: () {
              if (seleccionada) return;
              FocusScope.of(context).unfocus();
              setState(() => _pestana = pestana);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: Center(
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: seleccionada
                          ? FlutterFlowTheme.of(context).secondaryBackground
                          : FlutterFlowTheme.of(context).primaryText,
                      fontSize: 12,
                      fontWeight:
                          seleccionada ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buscadorYFiltros() {
    final theme = FlutterFlowTheme.of(context);
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.alternate),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _busquedaSolicitudes,
                onChanged: (_) => safeSetState(() {}),
                textInputAction: TextInputAction.search,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Buscar servicio, cliente o ticket…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busquedaSolicitudes.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          onPressed: () =>
                              safeSetState(_busquedaSolicitudes.clear),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: borde,
                  enabledBorder: borde,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _abrirFiltros,
            icon: const Icon(Icons.tune_rounded, size: 19),
            label: const Text('Filtrar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryText,
              backgroundColor: _hayFiltrosActivos ? theme.alternate : null,
              minimumSize: const Size(0, 48),
              side: BorderSide(color: theme.alternate),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccionSolicitudes() {
    final theme = FlutterFlowTheme.of(context);
    final titulo = switch (_pestana) {
      _PestanaSolicitudesProveedor.entrantes => 'Solicitudes Entrantes',
      _PestanaSolicitudesProveedor.aceptadas => 'Solicitudes Aceptadas',
      _PestanaSolicitudesProveedor.historial => 'Historial de solicitudes',
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 26, 16, 0),
        child: Text(
          titulo,
          style: HulpTextStyles.section.copyWith(color: theme.primary),
        ),
      ),
    );
  }

  Widget _controlDisponibilidad(UsuariosRow? usuario) {
    final theme = FlutterFlowTheme.of(context);
    final disponible = _model.switchValue ?? usuario?.disponibilidad ?? true;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border.all(color: theme.alternate),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Estado',
            style: theme.bodySmall.copyWith(
              color: theme.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            disponible ? 'Activo' : 'Inactivo',
            style: theme.bodySmall.copyWith(
              color: disponible ? theme.primary : theme.secondaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Switch.adaptive(
            value: disponible,
            onChanged: usuario == null
                ? null
                : (newValue) async {
                    final nuevoEstado = newValue!;
                    safeSetState(() => _model.switchValue = nuevoEstado);
                    await UsuariosTable().update(
                      data: {'disponibilidad': nuevoEstado},
                      matchingRows: (rows) => rows.eqOrNull('id', usuario.id),
                    );
                  },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: theme.primary,
            activeTrackColor: theme.primary,
            inactiveTrackColor: theme.alternate,
            inactiveThumbColor: theme.secondaryBackground,
          ),
        ],
      ),
    );
  }

  void _recargarSolicitudes() {
    safeSetState(() {
      _model.containerSupabaseStream2 = null;
      _model.containerSupabaseStream4 = null;
    });
  }

  Stream<List<SolicitudesServicioRow>> _solicitudesPorServicio(
      List<ProfesionalServiciosRow> servicios) {
    if (_ofertasValidadasEnServidor) {
      // Las ofertas sin proveedor no llegan por Realtime al dispositivo.
      final entrantes = SolicitudesStream(
        SupaFlow.client,
        filters: const {'estado': 'entrantes'},
        refreshInterval: const Duration(seconds: 8),
      )
          .map((rows) => rows.map(SolicitudesServicioRow.new).toList())
          .publishReplay(maxSize: 1);
      // La lista y el contador comparten la lectura aunque cambie la pestaña.
      unawaited(_conexionEntrantes?.cancel());
      _conexionEntrantes = entrantes.connect();
      return entrantes;
    }
    if (usaTransicionesSprint3 && servicios.isEmpty) {
      return Stream.multi((controller) {
        controller.add(const <SolicitudesServicioRow>[]);
        controller.close();
      }, isBroadcast: true);
    }
    // El stream de Supabase ya comparte y reenvía la última lista a cada
    // suscriptor. Entrantes se vuelve a suscribir al regresar a la pestaña.
    return SupaFlow.client
        .from('solicitudes_servicio')
        .stream(primaryKey: ['id'])
        .inFilterOrNull(
            'servicio_id', servicios.map((e) => e.servicioId).toList())
        .map((rows) => rows.map(SolicitudesServicioRow.new).toList());
  }

  bool _estadoAzul(String estado) =>
      estado == 'aceptadas' ||
      (usaTransicionesSprint3 &&
          (estado == 'iniciadas' || estado == 'en camino'));

  AccionSolicitud? _siguiente(SolicitudesServicioRow solicitud) =>
      siguienteAccionSolicitud(
        estado: solicitud.estado,
        fechaServicio: solicitud.fecha,
        fechaAceptacion: solicitud.fechaAceptacion,
        ahora: DateTime.now(),
      );

  Future<void> _registrarAccion(
      SolicitudesServicioRow solicitud, AccionSolicitud accion) async {
    if (!_transicionesPendientes.add(solicitud.id)) return;
    safeSetState(() {});
    try {
      final nueva = await transicionarSolicitud(
        solicitud.id,
        accion,
        publicacionId: solicitud.getField<String>('publicacion_id'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accion.notificacion)),
        );
      }
      if (nueva && accion != AccionSolicitud.rechazar) {
        try {
          await SendNotificationUserCall.call(
            userIdSupabase: solicitud.usuarioId,
            title: accion.notificacion,
            message: 'Consulta los detalles de tu solicitud en Hulp.',
          );
        } catch (_) {
          // El servidor ya confirmó el cambio de estado.
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeTransicionSolicitud(error))),
        );
      }
    } finally {
      _transicionesPendientes.remove(solicitud.id);
      _recargarSolicitudes();
    }
  }

  Future<void> _abrirCierre(BuildContext context, String id) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: FinalizarServicioWidget(idservicio: id),
      ),
    );
    _recargarSolicitudes();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SolicitudesModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _model.cargarCiudadDelProveedor();
      safeSetState(() {});
      _model.notificacionActiva = await actions.areNotificationsEnabled();
      _model.notificationEnabled = _model.notificacionActiva!;
      safeSetState(() {});
      if (FFDevEnvironmentValues().isProduction) {
        _model.versionDb2 = await AppVersionTable().queryRows(
          queryFn: (q) => q,
        );
        _model.appVersion2 = await actions.getVersion();
        if (isAndroid == true) {
          if (_model.appVersion2 !=
              _model.versionDb2?.firstOrNull?.versionProveedores) {
            await showDialog(
              context: context,
              builder: (dialogContext) {
                return Dialog(
                  elevation: 0,
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  alignment: AlignmentDirectional(0.0, 0.0)
                      .resolve(Directionality.of(context)),
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(dialogContext).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: NuevaVersionWidget(),
                  ),
                );
              },
            );
          }
        } else {
          if (_model.versionDb2?.firstOrNull?.testFlight != true) {
            if (_model.appVersion2 ==
                _model.versionDb2?.firstOrNull?.versionProveedoresIos) {
              return;
            }

            await showDialog(
              context: context,
              builder: (dialogContext) {
                return Dialog(
                  elevation: 0,
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  alignment: AlignmentDirectional(0.0, 0.0)
                      .resolve(Directionality.of(context)),
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(dialogContext).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: NuevaVersionWidget(),
                  ),
                );
              },
            );

            return;
          }
        }
      }
    });

    _model.aceptadasExpandableController =
        ExpandableController(initialExpanded: true)
          ..addListener(() => safeSetState(() {}));
    _model.finalizadasExpandableController =
        ExpandableController(initialExpanded: true)
          ..addListener(() => safeSetState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    unawaited(_conexionEntrantes?.cancel());
    _busquedaSolicitudes.dispose();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: PopScope(
          canPop: false,
          child: Scaffold(
            key: scaffoldKey,
            body: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: StreamBuilder<List<AppVersionRow>>(
                    stream: _model.containerSupabaseStream1 ??= SupaFlow.client
                        .from("AppVersion")
                        .stream(primaryKey: ['id']).map((list) =>
                            list.map((item) => AppVersionRow(item)).toList()),
                    builder: (context, snapshot) {
                      // Customize what your widget looks like when it's loading.
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 50.0,
                            height: 50.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }
                      List<AppVersionRow> containerAppVersionRowList =
                          snapshot.data!;

                      final containerAppVersionRow =
                          containerAppVersionRowList.isNotEmpty
                              ? containerAppVersionRowList.first
                              : null;

                      return Container(
                        decoration: BoxDecoration(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child:
                                  FutureBuilder<List<ProfesionalServiciosRow>>(
                                future: ProfesionalServiciosTable().queryRows(
                                  queryFn: (q) => q.eqOrNull(
                                    'usuario_id',
                                    currentUserUid,
                                  ),
                                ),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 50.0,
                                        height: 50.0,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  List<ProfesionalServiciosRow>
                                      containerProfesionalServiciosRowList =
                                      snapshot.data!;

                                  return Container(
                                    decoration: BoxDecoration(),
                                    child: StreamBuilder<
                                        List<SolicitudesServicioRow>>(
                                      stream: _model
                                              .containerSupabaseStream2 ??=
                                          SupaFlow.client
                                              .from("solicitudes_servicio")
                                              .stream(primaryKey: ['id'])
                                              .eqOrNull(
                                                'profesional_id',
                                                currentUserUid,
                                              )
                                              .map((list) => list
                                                  .map((item) =>
                                                      SolicitudesServicioRow(
                                                          item))
                                                  .toList()),
                                      builder: (context, snapshot) {
                                        // Customize what your widget looks like when it's loading.
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: SizedBox(
                                              width: 50.0,
                                              height: 50.0,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        List<SolicitudesServicioRow>
                                            containerSolicitudesServicioRowList =
                                            snapshot.data!;

                                        return Container(
                                          decoration: BoxDecoration(),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Expanded(
                                                child: StreamBuilder<
                                                    List<UsuariosRow>>(
                                                  stream: _model
                                                          .containerSupabaseStream3 ??=
                                                      SupaFlow.client
                                                          .from("usuarios")
                                                          .stream(primaryKey: [
                                                            'id'
                                                          ])
                                                          .eqOrNull(
                                                            'id',
                                                            currentUserUid,
                                                          )
                                                          .map((list) => list
                                                              .map((item) =>
                                                                  UsuariosRow(
                                                                      item))
                                                              .toList()),
                                                  builder: (context, snapshot) {
                                                    // Customize what your widget looks like when it's loading.
                                                    if (!snapshot.hasData) {
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 50.0,
                                                          height: 50.0,
                                                          child:
                                                              CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    List<UsuariosRow>
                                                        containerUsuariosRowList =
                                                        snapshot.data!;

                                                    final containerUsuariosRow =
                                                        containerUsuariosRowList
                                                                .isNotEmpty
                                                            ? containerUsuariosRowList
                                                                .first
                                                            : null;

                                                    final cantidadEntrantesHeader =
                                                        containerSolicitudesServicioRowList
                                                            .where((solicitud) =>
                                                                _esEntranteDisponible(
                                                                  solicitud,
                                                                  containerProfesionalServiciosRowList,
                                                                ))
                                                            .length;
                                                    final cantidadAceptadasHeader =
                                                        containerSolicitudesServicioRowList
                                                            .where((solicitud) =>
                                                                (!usaTransicionesSprint3 ||
                                                                    solicitud
                                                                            .profesionalId ==
                                                                        currentUserUid) &&
                                                                _esAceptada(
                                                                    solicitud))
                                                            .length;
                                                    final cantidadHistorialHeader =
                                                        containerSolicitudesServicioRowList
                                                            .where((solicitud) =>
                                                                (!usaTransicionesSprint3 ||
                                                                    solicitud
                                                                            .profesionalId ==
                                                                        currentUserUid) &&
                                                                _esHistorial(
                                                                    solicitud))
                                                            .length;

                                                    return Container(
                                                      decoration:
                                                          BoxDecoration(),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Padding(
                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                16.0,
                                                                MediaQuery.paddingOf(
                                                                            context)
                                                                        .top +
                                                                    8.0,
                                                                16.0,
                                                                8.0),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Image.asset(
                                                                  'assets/images/28.png',
                                                                  width: 72.0,
                                                                  height: 30.0,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                                Expanded(
                                                                  child: Center(
                                                                    child:
                                                                        _controlDisponibilidad(
                                                                      containerUsuariosRow,
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 72.0,
                                                                  child: Align(
                                                                    alignment:
                                                                        AlignmentDirectional
                                                                            .centerEnd,
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          children: [
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                if (_model.notificationEnabled == false)
                                                                                  InkWell(
                                                                                    splashColor: Colors.transparent,
                                                                                    focusColor: Colors.transparent,
                                                                                    hoverColor: Colors.transparent,
                                                                                    highlightColor: Colors.transparent,
                                                                                    onTap: () async {
                                                                                      await actions.assignUserTags(
                                                                                        currentUserUid,
                                                                                      );
                                                                                      _model.notificationEnabled = true;
                                                                                      safeSetState(() {});
                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        SnackBar(
                                                                                          content: Text(
                                                                                            'Notificaciones activadas, a partir de ahora recibiras notificaciones',
                                                                                            style: FlutterFlowTheme.of(context).labelMedium.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                                                  ),
                                                                                                  color: FlutterFlowTheme.of(context).primaryBackground,
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                                                ),
                                                                                          ),
                                                                                          duration: Duration(milliseconds: 4000),
                                                                                          backgroundColor: FlutterFlowTheme.of(context).primary,
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                    child: Icon(
                                                                                      Icons.notifications_off_outlined,
                                                                                      color: FlutterFlowTheme.of(context).primaryText,
                                                                                      size: 26.0,
                                                                                    ),
                                                                                  ),
                                                                                if (_model.notificationEnabled == true)
                                                                                  InkWell(
                                                                                    splashColor: Colors.transparent,
                                                                                    focusColor: Colors.transparent,
                                                                                    hoverColor: Colors.transparent,
                                                                                    highlightColor: Colors.transparent,
                                                                                    onTap: () async {
                                                                                      await actions.toggleNotification(
                                                                                        false,
                                                                                      );
                                                                                      _model.notificationEnabled = false;
                                                                                      safeSetState(() {});
                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        SnackBar(
                                                                                          content: Text(
                                                                                            'Notificaciones desactivadas, ya no recibiras notificaciones',
                                                                                            style: FlutterFlowTheme.of(context).labelMedium.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                                                  ),
                                                                                                  color: FlutterFlowTheme.of(context).primaryBackground,
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                                                ),
                                                                                          ),
                                                                                          duration: Duration(milliseconds: 4000),
                                                                                          backgroundColor: FlutterFlowTheme.of(context).primary,
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                    child: Icon(
                                                                                      Icons.notifications_none,
                                                                                      color: FlutterFlowTheme.of(context).primaryText,
                                                                                      size: 26.0,
                                                                                    ),
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                            Text(
                                                                              _model.notificationEnabled == true ? 'Activado' : 'Desactivado',
                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                    font: GoogleFonts.inter(
                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                    fontSize: 12.0,
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          StreamBuilder<
                                                              List<
                                                                  SolicitudesServicioRow>>(
                                                            stream: _model
                                                                    .containerSupabaseStream4 ??=
                                                                _solicitudesPorServicio(
                                                                    containerProfesionalServiciosRowList),
                                                            builder: (context,
                                                                solicitudesSnapshot) {
                                                              var entrantesDisponibles =
                                                                  _ofertasValidadasEnServidor
                                                                      ? 0
                                                                      : cantidadEntrantesHeader;
                                                              if (solicitudesSnapshot
                                                                  .hasData) {
                                                                final porServicio =
                                                                    solicitudesSnapshot
                                                                        .data!;
                                                                final solicitudesEntrantes =
                                                                    usaTransicionesSprint3 && !_ofertasValidadasEnServidor
                                                                        ? {
                                                                            for (final solicitud
                                                                                in porServicio)
                                                                              solicitud.id: solicitud,
                                                                            for (final solicitud
                                                                                in containerSolicitudesServicioRowList)
                                                                              solicitud.id: solicitud,
                                                                          }.values
                                                                        : porServicio;
                                                                entrantesDisponibles =
                                                                    solicitudesEntrantes
                                                                        .where((solicitud) =>
                                                                            _esEntranteDisponible(
                                                                              solicitud,
                                                                              containerProfesionalServiciosRowList,
                                                                            ))
                                                                        .length;
                                                                if (_busquedaSolicitudes
                                                                    .text
                                                                    .trim()
                                                                    .isNotEmpty) {
                                                                  final solicitudesParaBuscar =
                                                                      switch (
                                                                          _pestana) {
                                                                    _PestanaSolicitudesProveedor
                                                                          .entrantes =>
                                                                      solicitudesEntrantes.where(
                                                                          (solicitud) =>
                                                                              _esEntranteDisponible(
                                                                                solicitud,
                                                                                containerProfesionalServiciosRowList,
                                                                              )),
                                                                    _PestanaSolicitudesProveedor
                                                                          .aceptadas =>
                                                                      containerSolicitudesServicioRowList.where((solicitud) =>
                                                                          (!usaTransicionesSprint3 ||
                                                                              solicitud.profesionalId ==
                                                                                  currentUserUid) &&
                                                                          _esAceptada(
                                                                              solicitud)),
                                                                    _PestanaSolicitudesProveedor
                                                                          .historial =>
                                                                      containerSolicitudesServicioRowList.where((solicitud) =>
                                                                          (!usaTransicionesSprint3 ||
                                                                              solicitud.profesionalId ==
                                                                                  currentUserUid) &&
                                                                          _esHistorial(
                                                                              solicitud)),
                                                                  };
                                                                  _precargarNombresClientes(
                                                                      solicitudesParaBuscar);
                                                                }
                                                              }
                                                              return _pestanasSolicitudes(
                                                                entrantes:
                                                                    entrantesDisponibles,
                                                                aceptadas:
                                                                    cantidadAceptadasHeader,
                                                                historial:
                                                                    cantidadHistorialHeader,
                                                              );
                                                            },
                                                          ),
                                                          _tituloSeccionSolicitudes(),
                                                          _buscadorYFiltros(),
                                                          if (_pestana ==
                                                                  _PestanaSolicitudesProveedor
                                                                      .entrantes &&
                                                              (usaTransicionesSprint3 ||
                                                                  (_model.switchValue ??
                                                                      true)))
                                                            Expanded(
                                                              child:
                                                                  SingleChildScrollView(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .fromLTRB(
                                                                        0,
                                                                        17,
                                                                        0,
                                                                        24),
                                                                child: StreamBuilder<
                                                                    List<
                                                                        SolicitudesServicioRow>>(
                                                                  stream: _model
                                                                          .containerSupabaseStream4 ??=
                                                                      _solicitudesPorServicio(
                                                                          containerProfesionalServiciosRowList),
                                                                  builder: (context,
                                                                      snapshot) {
                                                                    if (snapshot
                                                                        .hasError) {
                                                                      return Column(
                                                                        children: [
                                                                          const ListaVaciaWidget(
                                                                            texto: 'No se pudieron cargar las solicitudes entrantes.',
                                                                          ),
                                                                          TextButton(
                                                                            onPressed: () {
                                                                              setState(() => _model.containerSupabaseStream4 = null);
                                                                            },
                                                                            child: const Text('Reintentar'),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    }
                                                                    // Customize what your widget looks like when it's loading.
                                                                    if (!snapshot
                                                                        .hasData) {
                                                                      return Center(
                                                                        child:
                                                                            SizedBox(
                                                                          width:
                                                                              50.0,
                                                                          height:
                                                                              50.0,
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                            valueColor:
                                                                                AlwaysStoppedAnimation<Color>(
                                                                              FlutterFlowTheme.of(context).primary,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }
                                                                    final solicitudesPorServicio =
                                                                        snapshot
                                                                            .data!;
                                                                    final solicitudesEntrantes =
                                                                        usaTransicionesSprint3 && !_ofertasValidadasEnServidor
                                                                            ? {
                                                                                for (final solicitud in solicitudesPorServicio) solicitud.id: solicitud,
                                                                                for (final solicitud in containerSolicitudesServicioRowList) solicitud.id: solicitud,
                                                                              }.values
                                                                            : solicitudesPorServicio;
                                                                    return Container(
                                                                      decoration:
                                                                          BoxDecoration(),
                                                                      child:
                                                                          Padding(
                                                                        padding: EdgeInsetsDirectional.fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                        child:
                                                                            Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            if (_pestana ==
                                                                                _PestanaSolicitudesProveedor.entrantes)
                                                                              Padding(
                                                                                padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                child: Builder(
                                                                                  builder: (context) {
                                                                                    final serviciosent = solicitudesEntrantes.where((e) => _esEntranteDisponible(e, containerProfesionalServiciosRowList) && _coincideFiltro(e)).toList()..sort(_compararSolicitudes);
                                                                                    if (serviciosent.isEmpty) {
                                                                                      return ListaVaciaWidget(
                                                                                        texto: _hayFiltrosActivos || _busquedaSolicitudes.text.isNotEmpty ? 'No hay solicitudes que coincidan con los filtros' : 'No hay solicitudes entrantes',
                                                                                      );
                                                                                    }

                                                                                    return ListView.separated(
                                                                                      padding: EdgeInsets.zero,
                                                                                      primary: false,
                                                                                      shrinkWrap: true,
                                                                                      scrollDirection: Axis.vertical,
                                                                                      itemCount: serviciosent.length,
                                                                                      separatorBuilder: (_, __) => SizedBox(height: 9.0),
                                                                                      itemBuilder: (context, serviciosentIndex) {
                                                                                        final serviciosentItem = serviciosent[serviciosentIndex];
                                                                                        final tarjetaExpandida = _tarjetasExpandidas.contains('entrantes:${serviciosentItem.id}');
                                                                                        final citaTarjeta = [
                                                                                          if (serviciosentItem.fecha != null) dateTimeFormat('d MMM', serviciosentItem.fecha, locale: FFLocalizations.of(context).languageCode),
                                                                                          if (serviciosentItem.hora != null) dateTimeFormat('jm', serviciosentItem.hora.time, locale: FFLocalizations.of(context).languageCode),
                                                                                        ].join(' · ');
                                                                                        return Container(
                                                                                          decoration: BoxDecoration(
                                                                                            color: HulpColors.surface,
                                                                                            borderRadius: BorderRadius.circular(13.0),
                                                                                            border: Border.all(
                                                                                              color: HulpColors.border,
                                                                                              width: 1.0,
                                                                                            ),
                                                                                            boxShadow: const [
                                                                                              BoxShadow(
                                                                                                color: Color(0x14000000),
                                                                                                blurRadius: 8,
                                                                                                offset: Offset(0, 2),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                          child: Padding(
                                                                                            padding: EdgeInsets.all(6.0),
                                                                                            child: Column(
                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                              children: [
                                                                                                Padding(
                                                                                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                                  child: InkWell(
                                                                                                    onTap: () => _alternarTarjetaSolicitud('entrantes:${serviciosentItem.id}'),
                                                                                                    borderRadius: BorderRadius.circular(20.0),
                                                                                                    child: Container(
                                                                                                      decoration: BoxDecoration(
                                                                                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                        borderRadius: BorderRadius.circular(20.0),
                                                                                                      ),
                                                                                                      child: Padding(
                                                                                                        padding: EdgeInsets.all(8.0),
                                                                                                        child: Row(
                                                                                                          mainAxisSize: MainAxisSize.max,
                                                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                          children: [
                                                                                                            _iconoTarjetaServicio(serviciosentItem.servicioNombre),
                                                                                                            SizedBox(width: 9.0),
                                                                                                            Container(width: 1.0, height: 48.0, color: HulpColors.border),
                                                                                                            SizedBox(width: 9.0),
                                                                                                            Expanded(
                                                                                                              child: Column(
                                                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                                children: [
                                                                                                                  Text('#${serviciosentItem.ticket ?? '-'}', style: HulpTextStyles.compact.copyWith(color: HulpColors.textSecondary)),
                                                                                                                  Text(valueOrDefault<String>(serviciosentItem.servicioNombre, '-'), style: HulpTextStyles.card.copyWith(color: HulpColors.brand)),
                                                                                                                  NombreClienteWidget(
                                                                                                                    usuarioId: serviciosentItem.usuarioId,
                                                                                                                    compacto: true,
                                                                                                                    onNombreCargado: () {
                                                                                                                      if (mounted) safeSetState(() {});
                                                                                                                    },
                                                                                                                  ),
                                                                                                                  if (citaTarjeta.isNotEmpty) Text(citaTarjeta, style: HulpTextStyles.help),
                                                                                                                ],
                                                                                                              ),
                                                                                                            ),
                                                                                                            Container(
                                                                                                              padding: EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                                                                                                              decoration: BoxDecoration(color: Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(20.0)),
                                                                                                              child: Text('Pendiente', style: HulpTextStyles.compact.copyWith(color: Color(0xFF9A6700))),
                                                                                                            ),
                                                                                                            Icon(tarjetaExpandida ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: HulpColors.textPrimary, size: 22.0),
                                                                                                          ],
                                                                                                        ),
                                                                                                      ),
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                                if (tarjetaExpandida) ...[
                                                                                                  _cabeceraDetalleSolicitud(),
                                                                                                  Padding(
                                                                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                                    child: Container(
                                                                                                      decoration: BoxDecoration(
                                                                                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                                      ),
                                                                                                      child: Column(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        children: [
                                                                                                          Padding(
                                                                                                            padding: EdgeInsets.all(8.0),
                                                                                                            child: Row(
                                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                              children: [
                                                                                                                Row(
                                                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                                                  children: [
                                                                                                                    Icon(Icons.confirmation_number_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                    SizedBox(width: 6.0),
                                                                                                                    Text(
                                                                                                                      'Ticket ',
                                                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                            font: GoogleFonts.inter(
                                                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                            color: FlutterFlowTheme.of(context).accent3,
                                                                                                                            fontSize: 14.0,
                                                                                                                            letterSpacing: 0.0,
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                    ),
                                                                                                                  ],
                                                                                                                ),
                                                                                                                Flexible(
                                                                                                                  child: Text(
                                                                                                                    valueOrDefault<String>(
                                                                                                                      serviciosentItem.ticket?.toString(),
                                                                                                                      '0000',
                                                                                                                    ),
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).secondary,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ].divide(SizedBox(width: 8.0)),
                                                                                                            ),
                                                                                                          ),
                                                                                                          Padding(
                                                                                                            padding: EdgeInsets.all(8.0),
                                                                                                            child: Row(
                                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                              children: [
                                                                                                                Row(
                                                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                                                  children: [
                                                                                                                    Icon(Icons.location_on_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                    SizedBox(width: 6.0),
                                                                                                                    Text(
                                                                                                                      'Ubicación',
                                                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                            font: GoogleFonts.inter(
                                                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                            color: FlutterFlowTheme.of(context).accent3,
                                                                                                                            fontSize: 14.0,
                                                                                                                            letterSpacing: 0.0,
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                    ),
                                                                                                                  ],
                                                                                                                ),
                                                                                                                Flexible(
                                                                                                                  child: Text(
                                                                                                                    valueOrDefault<String>(
                                                                                                                      serviciosentItem.ubicacion,
                                                                                                                      'Sin ubicación',
                                                                                                                    ),
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).secondary,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ].divide(SizedBox(width: 8.0)),
                                                                                                            ),
                                                                                                          ),
                                                                                                          NombreClienteWidget(
                                                                                                            usuarioId: serviciosentItem.usuarioId,
                                                                                                          ),
                                                                                                          EnlaceMapaWidget(
                                                                                                            latitud: serviciosentItem.latitud,
                                                                                                            longitud: serviciosentItem.longitud,
                                                                                                            direccion: serviciosentItem.ubicacion,
                                                                                                            navegacion: false,
                                                                                                          ),
                                                                                                          Padding(
                                                                                                            padding: EdgeInsets.all(8.0),
                                                                                                            child: Row(
                                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                              children: [
                                                                                                                Row(
                                                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                                                  children: [
                                                                                                                    Icon(Icons.calendar_today_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                    SizedBox(width: 6.0),
                                                                                                                    Text(
                                                                                                                      'Fecha',
                                                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                            font: GoogleFonts.inter(
                                                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                            color: FlutterFlowTheme.of(context).accent3,
                                                                                                                            fontSize: 14.0,
                                                                                                                            letterSpacing: 0.0,
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                    ),
                                                                                                                  ],
                                                                                                                ),
                                                                                                                Flexible(
                                                                                                                  child: Text(
                                                                                                                    valueOrDefault<String>(
                                                                                                                      dateTimeFormat(
                                                                                                                        "d \'de\' MMMM \'de\' yyyy",
                                                                                                                        serviciosentItem.fecha,
                                                                                                                        locale: FFLocalizations.of(context).languageCode,
                                                                                                                      ),
                                                                                                                      'Sin fecha',
                                                                                                                    ),
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).secondary,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ].divide(SizedBox(width: 8.0)),
                                                                                                            ),
                                                                                                          ),
                                                                                                          Padding(
                                                                                                            padding: EdgeInsets.all(8.0),
                                                                                                            child: Row(
                                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                              children: [
                                                                                                                Row(
                                                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                                                  children: [
                                                                                                                    Icon(Icons.access_time_rounded, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                    SizedBox(width: 6.0),
                                                                                                                    Text(
                                                                                                                      'Hora',
                                                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                            font: GoogleFonts.inter(
                                                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                            color: FlutterFlowTheme.of(context).accent3,
                                                                                                                            fontSize: 14.0,
                                                                                                                            letterSpacing: 0.0,
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                    ),
                                                                                                                  ],
                                                                                                                ),
                                                                                                                Flexible(
                                                                                                                  child: Text(
                                                                                                                    valueOrDefault<String>(
                                                                                                                      dateTimeFormat(
                                                                                                                        "jm",
                                                                                                                        serviciosentItem.hora.time,
                                                                                                                        locale: FFLocalizations.of(context).languageCode,
                                                                                                                      ),
                                                                                                                      'Sin hora',
                                                                                                                    ),
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).secondary,
                                                                                                                          fontSize: 15.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ].divide(SizedBox(width: 8.0)),
                                                                                                            ),
                                                                                                          ),
                                                                                                          if (serviciosentItem.finanzasVersion == 1 && serviciosentItem.profesionalId == currentUserUid)
                                                                                                            DesgloseServicioWidget(solicitudId: serviciosentItem.id, actualizacion: '${serviciosentItem.finanzasRevision}:${serviciosentItem.estadoPago}')
                                                                                                          else
                                                                                                            Padding(
                                                                                                              padding: EdgeInsets.all(8.0),
                                                                                                              child: Row(
                                                                                                                mainAxisSize: MainAxisSize.max,
                                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                                children: [
                                                                                                                  Row(
                                                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                                                    children: [
                                                                                                                      Icon(Icons.account_balance_wallet_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                      SizedBox(width: 6.0),
                                                                                                                      Text(
                                                                                                                        'Tu pago',
                                                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                              font: GoogleFonts.inter(
                                                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                              ),
                                                                                                                              color: FlutterFlowTheme.of(context).accent3,
                                                                                                                              fontSize: 14.0,
                                                                                                                              letterSpacing: 0.0,
                                                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                      ),
                                                                                                                    ],
                                                                                                                  ),
                                                                                                                  Flexible(
                                                                                                                    child: Text(
                                                                                                                      valueOrDefault<String>(
                                                                                                                        '${functions.formatPrices(serviciosentItem.importeProveedor(() => functions.calcularIngresoProveedor(valueOrDefault<double>(
                                                                                                                              serviciosentItem.precio,
                                                                                                                              0.0,
                                                                                                                            ) + valueOrDefault<double>(
                                                                                                                              serviciosentItem.precioAdicionales,
                                                                                                                              0.0,
                                                                                                                            ))))} COP',
                                                                                                                        '\$0 COP',
                                                                                                                      ),
                                                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                            font: GoogleFonts.inter(
                                                                                                                              fontWeight: FontWeight.w600,
                                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                            ),
                                                                                                                            color: Color(0xFF3D91F4),
                                                                                                                            fontSize: 14.0,
                                                                                                                            letterSpacing: 0.0,
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ].divide(SizedBox(width: 8.0)),
                                                                                                              ),
                                                                                                            ),
                                                                                                        ],
                                                                                                      ),
                                                                                                    ),
                                                                                                  ),
                                                                                                  Row(
                                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                    children: [
                                                                                                      Flexible(
                                                                                                        child: Row(
                                                                                                          mainAxisSize: MainAxisSize.max,
                                                                                                          mainAxisAlignment: MainAxisAlignment.end,
                                                                                                          children: [
                                                                                                            if (SupaFlow.sprint4Habilitado && serviciosentItem.getField<String>('tipo_asignacion') == 'directa')
                                                                                                              TextButton(
                                                                                                                onPressed: _transicionesPendientes.contains(serviciosentItem.id) ? null : () => _registrarAccion(serviciosentItem, AccionSolicitud.rechazar),
                                                                                                                child: const Text('Rechazar'),
                                                                                                              ),
                                                                                                            Flexible(
                                                                                                              child: Builder(
                                                                                                                builder: (context) => FFButtonWidget(
                                                                                                                  onPressed: usaTransicionesSprint3 && (containerUsuariosRow?.verificado != 'verificado' || _transicionesPendientes.contains(serviciosentItem.id))
                                                                                                                      ? null
                                                                                                                      : () async {
                                                                                                                          if (usaTransicionesSprint3) {
                                                                                                                            await _registrarAccion(serviciosentItem, AccionSolicitud.aceptar);
                                                                                                                            return;
                                                                                                                          }
                                                                                                                          await SolicitudesServicioTable().update(
                                                                                                                            data: {
                                                                                                                              'estado': 'aceptadas',
                                                                                                                              'profesional_id': currentUserUid,
                                                                                                                            },
                                                                                                                            matchingRows: (rows) => rows.eqOrNull(
                                                                                                                              'id',
                                                                                                                              serviciosentItem.id,
                                                                                                                            ),
                                                                                                                          );
                                                                                                                          unawaited(
                                                                                                                            () async {
                                                                                                                              _model.apiResultwgo21 = await SendNotificationUserCall.call(
                                                                                                                                userIdSupabase: serviciosentItem.usuarioId,
                                                                                                                                title: 'Solicitud aceptaada',
                                                                                                                                message: 'Tu solicitud ha sido aceptada',
                                                                                                                              );
                                                                                                                            }(),
                                                                                                                          );
                                                                                                                          await showDialog(
                                                                                                                            context: context,
                                                                                                                            builder: (dialogContext) {
                                                                                                                              return Dialog(
                                                                                                                                elevation: 0,
                                                                                                                                insetPadding: EdgeInsets.zero,
                                                                                                                                backgroundColor: Colors.transparent,
                                                                                                                                alignment: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                                                                child: GestureDetector(
                                                                                                                                  onTap: () {
                                                                                                                                    FocusScope.of(dialogContext).unfocus();
                                                                                                                                    FocusManager.instance.primaryFocus?.unfocus();
                                                                                                                                  },
                                                                                                                                  child: ServicioAsignadoInicioWidget(),
                                                                                                                                ),
                                                                                                                              );
                                                                                                                            },
                                                                                                                          );

                                                                                                                          safeSetState(() {});
                                                                                                                        },
                                                                                                                  text: 'Aceptar',
                                                                                                                  icon: Icon(
                                                                                                                    Icons.check,
                                                                                                                    size: 16.0,
                                                                                                                  ),
                                                                                                                  options: FFButtonOptions(
                                                                                                                    height: 32.0,
                                                                                                                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                                    iconAlignment: IconAlignment.end,
                                                                                                                    iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                                    iconColor: FlutterFlowTheme.of(context).energia,
                                                                                                                    color: FlutterFlowTheme.of(context).primary,
                                                                                                                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FontWeight.w600,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                        ),
                                                                                                                    elevation: 0.0,
                                                                                                                    borderSide: BorderSide(
                                                                                                                      color: FlutterFlowTheme.of(context).primary,
                                                                                                                      width: 1.0,
                                                                                                                    ),
                                                                                                                    borderRadius: BorderRadius.circular(20.0),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ),
                                                                                                            ),
                                                                                                          ].divide(SizedBox(width: 4.0)),
                                                                                                        ),
                                                                                                      ),
                                                                                                    ].divide(SizedBox(width: 8.0)),
                                                                                                  ),
                                                                                                ],
                                                                                              ],
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    );
                                                                                  },
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                          if (_pestana ==
                                                              _PestanaSolicitudesProveedor
                                                                  .aceptadas)
                                                            Expanded(
                                                              child:
                                                                  SingleChildScrollView(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .fromLTRB(
                                                                        0,
                                                                        17,
                                                                        0,
                                                                        24),
                                                                child:
                                                                    Container(
                                                                  width: double
                                                                      .infinity,
                                                                  color: Color(
                                                                      0x00000000),
                                                                  child:
                                                                      ExpandableNotifier(
                                                                    controller:
                                                                        _model
                                                                            .aceptadasExpandableController,
                                                                    child:
                                                                        ExpandablePanel(
                                                                      header: const SizedBox
                                                                          .shrink(),
                                                                      collapsed:
                                                                          Container(),
                                                                      expanded:
                                                                          Container(
                                                                        decoration:
                                                                            BoxDecoration(),
                                                                        child:
                                                                            Padding(
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              16.0,
                                                                              0.0,
                                                                              16.0,
                                                                              0.0),
                                                                          child:
                                                                              Builder(
                                                                            builder:
                                                                                (context) {
                                                                              final solicitudesAceptadasx = containerSolicitudesServicioRowList.where((e) => (!usaTransicionesSprint3 || e.profesionalId == currentUserUid) && _esAceptada(e) && _coincideFiltro(e)).toList()..sort(_compararSolicitudes);
                                                                              if (solicitudesAceptadasx.isEmpty) {
                                                                                return ListaVaciaWidget(
                                                                                  texto: _hayFiltrosActivos || _busquedaSolicitudes.text.isNotEmpty ? 'No hay solicitudes que coincidan con los filtros' : 'No hay solicitudes aceptadas',
                                                                                );
                                                                              }

                                                                              return ListView.separated(
                                                                                padding: EdgeInsets.zero,
                                                                                primary: false,
                                                                                shrinkWrap: true,
                                                                                scrollDirection: Axis.vertical,
                                                                                itemCount: solicitudesAceptadasx.length,
                                                                                separatorBuilder: (_, __) => SizedBox(height: 9.0),
                                                                                itemBuilder: (context, solicitudesAceptadasxIndex) {
                                                                                  final solicitudesAceptadasxItem = solicitudesAceptadasx[solicitudesAceptadasxIndex];
                                                                                  final tarjetaExpandida = _tarjetasExpandidas.contains('aceptadas:${solicitudesAceptadasxItem.id}');
                                                                                  final citaTarjeta = [
                                                                                    if (solicitudesAceptadasxItem.fecha != null) dateTimeFormat('d MMM', solicitudesAceptadasxItem.fecha, locale: FFLocalizations.of(context).languageCode),
                                                                                    if (solicitudesAceptadasxItem.hora != null) dateTimeFormat('jm', solicitudesAceptadasxItem.hora.time, locale: FFLocalizations.of(context).languageCode),
                                                                                  ].join(' · ');
                                                                                  final usaFlujoNuevo = usaTransicionesSprint3;
                                                                                  final siguiente = usaFlujoNuevo ? _siguiente(solicitudesAceptadasxItem) : null;
                                                                                  final esperaDiaServicio = usaFlujoNuevo && siguiente == null && (solicitudesAceptadasxItem.estado == 'iniciadas' || (solicitudesAceptadasxItem.estado == 'aceptadas' && solicitudesAceptadasxItem.fechaAceptacion != null));
                                                                                  return Container(
                                                                                    decoration: BoxDecoration(
                                                                                      color: HulpColors.surface,
                                                                                      borderRadius: BorderRadius.circular(13.0),
                                                                                      border: Border.all(
                                                                                        color: HulpColors.border,
                                                                                        width: 1.0,
                                                                                      ),
                                                                                      boxShadow: const [
                                                                                        BoxShadow(
                                                                                          color: Color(0x14000000),
                                                                                          blurRadius: 8,
                                                                                          offset: Offset(0, 2),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                    child: Padding(
                                                                                      padding: EdgeInsets.all(6.0),
                                                                                      child: Column(
                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                        children: [
                                                                                          Padding(
                                                                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                            child: InkWell(
                                                                                              onTap: () => _alternarTarjetaSolicitud('aceptadas:${solicitudesAceptadasxItem.id}'),
                                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                                              child: Container(
                                                                                                decoration: BoxDecoration(
                                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                  borderRadius: BorderRadius.circular(8.0),
                                                                                                ),
                                                                                                child: Padding(
                                                                                                  padding: EdgeInsets.all(8.0),
                                                                                                  child: Row(
                                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                    children: [
                                                                                                      _iconoTarjetaServicio(solicitudesAceptadasxItem.servicioNombre),
                                                                                                      SizedBox(width: 9.0),
                                                                                                      Container(width: 1.0, height: 48.0, color: HulpColors.border),
                                                                                                      SizedBox(width: 9.0),
                                                                                                      Expanded(
                                                                                                        child: Column(
                                                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                          mainAxisSize: MainAxisSize.min,
                                                                                                          children: [
                                                                                                            Text('#${solicitudesAceptadasxItem.ticket ?? '-'}', style: HulpTextStyles.compact.copyWith(color: HulpColors.textSecondary)),
                                                                                                            Text(valueOrDefault<String>(solicitudesAceptadasxItem.servicioNombre, '-'), style: HulpTextStyles.card.copyWith(color: HulpColors.brand)),
                                                                                                            NombreClienteWidget(
                                                                                                              usuarioId: solicitudesAceptadasxItem.usuarioId,
                                                                                                              compacto: true,
                                                                                                              onNombreCargado: () {
                                                                                                                if (mounted) safeSetState(() {});
                                                                                                              },
                                                                                                            ),
                                                                                                            if (citaTarjeta.isNotEmpty) Text(citaTarjeta, style: HulpTextStyles.help),
                                                                                                          ],
                                                                                                        ),
                                                                                                      ),
                                                                                                      Container(
                                                                                                        padding: EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                                                                                                        decoration: BoxDecoration(
                                                                                                          color: _estadoAzul(solicitudesAceptadasxItem.estado) ? Color(0xFFCFE3FC) : Color(0xFFFFE9CC),
                                                                                                          borderRadius: BorderRadius.circular(20.0),
                                                                                                        ),
                                                                                                        child: Text(
                                                                                                          valueOrDefault<String>(
                                                                                                            usaTransicionesSprint3 ? etiquetaEstadoSolicitud(solicitudesAceptadasxItem.estado) : (solicitudesAceptadasxItem.estado == 'aceptadas' ? 'Activo' : 'En curso'),
                                                                                                            'Activo',
                                                                                                          ),
                                                                                                          style: HulpTextStyles.compact.copyWith(color: _estadoAzul(solicitudesAceptadasxItem.estado) ? Color(0xFF0D70E7) : Color(0xFFED8600)),
                                                                                                        ),
                                                                                                      ),
                                                                                                      Icon(tarjetaExpandida ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: HulpColors.textPrimary, size: 22.0),
                                                                                                    ],
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                          if (tarjetaExpandida) ...[
                                                                                            _cabeceraDetalleSolicitud(),
                                                                                            Padding(
                                                                                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                              child: Container(
                                                                                                decoration: BoxDecoration(
                                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                  borderRadius: BorderRadius.circular(8.0),
                                                                                                ),
                                                                                                child: Column(
                                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                                  children: [
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.confirmation_number_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Ticket',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Text(
                                                                                                              valueOrDefault<String>(
                                                                                                                solicitudesAceptadasxItem.ticket?.toString(),
                                                                                                                '-',
                                                                                                              ),
                                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                    font: GoogleFonts.inter(
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                                                    fontSize: 14.0,
                                                                                                                    letterSpacing: 0.0,
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                  ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.description_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Descripción',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Align(
                                                                                                              alignment: AlignmentDirectional(1.0, 0.0),
                                                                                                              child: Text(
                                                                                                                valueOrDefault<String>(
                                                                                                                  solicitudesAceptadasxItem.descripcion,
                                                                                                                  '-',
                                                                                                                ),
                                                                                                                textAlign: TextAlign.end,
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).secondary,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.notes_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Info adicional',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Text(
                                                                                                              valueOrDefault<String>(
                                                                                                                solicitudesAceptadasxItem.descripcion,
                                                                                                                '-',
                                                                                                              ),
                                                                                                              textAlign: TextAlign.end,
                                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                    font: GoogleFonts.inter(
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                                                    fontSize: 14.0,
                                                                                                                    letterSpacing: 0.0,
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                  ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.location_on_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Ubicación',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Text(
                                                                                                              valueOrDefault<String>(
                                                                                                                solicitudesAceptadasxItem.ubicacion,
                                                                                                                '-',
                                                                                                              ),
                                                                                                              textAlign: TextAlign.end,
                                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                    font: GoogleFonts.inter(
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                                                    fontSize: 14.0,
                                                                                                                    letterSpacing: 0.0,
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                  ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    NombreClienteWidget(
                                                                                                      usuarioId: solicitudesAceptadasxItem.usuarioId,
                                                                                                    ),
                                                                                                    EnlaceMapaWidget(
                                                                                                      latitud: solicitudesAceptadasxItem.latitud,
                                                                                                      longitud: solicitudesAceptadasxItem.longitud,
                                                                                                      direccion: solicitudesAceptadasxItem.ubicacion,
                                                                                                      navegacion: true,
                                                                                                    ),
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.calendar_today_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Fecha',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Text(
                                                                                                              valueOrDefault<String>(
                                                                                                                dateTimeFormat(
                                                                                                                  "d \'de\' MMMM \'de\' yyyy",
                                                                                                                  solicitudesAceptadasxItem.fecha,
                                                                                                                  locale: FFLocalizations.of(context).languageCode,
                                                                                                                ),
                                                                                                                '-',
                                                                                                              ),
                                                                                                              textAlign: TextAlign.end,
                                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                    font: GoogleFonts.inter(
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                                                    fontSize: 14.0,
                                                                                                                    letterSpacing: 0.0,
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                  ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                                            children: [
                                                                                                              Icon(Icons.access_time_rounded, size: 16.0, color: HulpColors.textSecondary),
                                                                                                              SizedBox(width: 6.0),
                                                                                                              Text(
                                                                                                                'Hora',
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: FlutterFlowTheme.of(context).accent3,
                                                                                                                      fontSize: 14.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                          Flexible(
                                                                                                            child: Text(
                                                                                                              valueOrDefault<String>(
                                                                                                                dateTimeFormat(
                                                                                                                  "jm",
                                                                                                                  solicitudesAceptadasxItem.hora.time,
                                                                                                                  locale: FFLocalizations.of(context).languageCode,
                                                                                                                ),
                                                                                                                '-',
                                                                                                              ),
                                                                                                              textAlign: TextAlign.end,
                                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                    font: GoogleFonts.inter(
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                                    color: FlutterFlowTheme.of(context).secondary,
                                                                                                                    fontSize: 14.0,
                                                                                                                    letterSpacing: 0.0,
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                  ),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ].divide(SizedBox(width: 8.0)),
                                                                                                      ),
                                                                                                    ),
                                                                                                    if (solicitudesAceptadasxItem.finanzasVersion == 1)
                                                                                                      DesgloseServicioWidget(solicitudId: solicitudesAceptadasxItem.id, actualizacion: '${solicitudesAceptadasxItem.finanzasRevision}:${solicitudesAceptadasxItem.estadoPago}')
                                                                                                    else
                                                                                                      Padding(
                                                                                                        padding: EdgeInsets.all(8.0),
                                                                                                        child: Row(
                                                                                                          mainAxisSize: MainAxisSize.max,
                                                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                          children: [
                                                                                                            Row(
                                                                                                              mainAxisSize: MainAxisSize.min,
                                                                                                              children: [
                                                                                                                Icon(Icons.account_balance_wallet_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                SizedBox(width: 6.0),
                                                                                                                Text(
                                                                                                                  'Tu pago',
                                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                        font: GoogleFonts.inter(
                                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                        color: FlutterFlowTheme.of(context).accent3,
                                                                                                                        fontSize: 14.0,
                                                                                                                        letterSpacing: 0.0,
                                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                ),
                                                                                                              ],
                                                                                                            ),
                                                                                                            Flexible(
                                                                                                              child: Text(
                                                                                                                valueOrDefault<String>(
                                                                                                                  '${valueOrDefault<String>(
                                                                                                                    formatNumber(
                                                                                                                      solicitudesAceptadasxItem.importeProveedor(() => functions.calcularIngresoProveedor(solicitudesAceptadasxItem.precio + (solicitudesAceptadasxItem.precioAdicionales ?? 0.0))),
                                                                                                                      formatType: FormatType.custom,
                                                                                                                      currency: '\$',
                                                                                                                      format: '',
                                                                                                                      locale: '',
                                                                                                                    ),
                                                                                                                    '\$0',
                                                                                                                  )} COP',
                                                                                                                  '\$0 COP',
                                                                                                                ),
                                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                      font: GoogleFonts.inter(
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                      color: Color(0xFF3D91F4),
                                                                                                                      fontSize: 16.0,
                                                                                                                      letterSpacing: 0.0,
                                                                                                                      fontWeight: FontWeight.w600,
                                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                    ),
                                                                                                              ),
                                                                                                            ),
                                                                                                          ].divide(SizedBox(width: 8.0)),
                                                                                                        ),
                                                                                                      ),
                                                                                                  ],
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            Column(
                                                                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                                              children: [
                                                                                                Row(
                                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                  children: [
                                                                                                    FutureBuilder<List<ChatsSolicitudRow>>(
                                                                                                      future: ChatsSolicitudTable().querySingleRow(
                                                                                                        queryFn: (q) => q.eqOrNull(
                                                                                                          'solicitud_id',
                                                                                                          solicitudesAceptadasxItem.id,
                                                                                                        ),
                                                                                                      ),
                                                                                                      builder: (context, snapshot) {
                                                                                                        // Customize what your widget looks like when it's loading.
                                                                                                        if (!snapshot.hasData) {
                                                                                                          return Center(
                                                                                                            child: SizedBox(
                                                                                                              width: 50.0,
                                                                                                              height: 50.0,
                                                                                                              child: CircularProgressIndicator(
                                                                                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                                                                                  FlutterFlowTheme.of(context).primary,
                                                                                                                ),
                                                                                                              ),
                                                                                                            ),
                                                                                                          );
                                                                                                        }
                                                                                                        List<ChatsSolicitudRow> stackChatsSolicitudRowList = snapshot.data!;

                                                                                                        final stackChatsSolicitudRow = stackChatsSolicitudRowList.isNotEmpty ? stackChatsSolicitudRowList.first : null;

                                                                                                        return Container(
                                                                                                          width: 90.0,
                                                                                                          height: 32.0,
                                                                                                          child: Stack(
                                                                                                            children: [
                                                                                                              FFButtonWidget(
                                                                                                                onPressed: () async {
                                                                                                                  _model.vvsid = await VwSolicitudesServiciosCompletaTable().queryRows(
                                                                                                                    queryFn: (q) => q.eqOrNull(
                                                                                                                      'solicitud_id',
                                                                                                                      solicitudesAceptadasxItem.id,
                                                                                                                    ),
                                                                                                                  );

                                                                                                                  if (_model.vvsid?.firstOrNull == null) {
                                                                                                                    // La solicitud ya no existe (la borraron desde el admin): abrir
                                                                                                                    // el chat sin servicio mostraba la conversacion de otro cliente.
                                                                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                                                                      SnackBar(
                                                                                                                        content: Text(
                                                                                                                          'Esta solicitud ya no está disponible.',
                                                                                                                          style: TextStyle(color: FlutterFlowTheme.of(context).primaryBackground),
                                                                                                                        ),
                                                                                                                        duration: Duration(milliseconds: 4000),
                                                                                                                        backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                                                      ),
                                                                                                                    );
                                                                                                                    safeSetState(() {});
                                                                                                                    return;
                                                                                                                  }

                                                                                                                  context.pushNamed(
                                                                                                                    ChatWidget.routeName,
                                                                                                                    queryParameters: {
                                                                                                                      'servicio': serializeParam(
                                                                                                                        _model.vvsid?.firstOrNull,
                                                                                                                        ParamType.SupabaseRow,
                                                                                                                      ),
                                                                                                                    }.withoutNulls,
                                                                                                                  );

                                                                                                                  safeSetState(() {});
                                                                                                                },
                                                                                                                text: 'Chat',
                                                                                                                icon: Icon(
                                                                                                                  Icons.support_agent,
                                                                                                                  size: 16.0,
                                                                                                                ),
                                                                                                                options: FFButtonOptions(
                                                                                                                  height: 32.0,
                                                                                                                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                                  iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                                  iconColor: FlutterFlowTheme.of(context).accent3,
                                                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                                        font: GoogleFonts.inter(
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                        ),
                                                                                                                        color: FlutterFlowTheme.of(context).accent3,
                                                                                                                        fontSize: 12.0,
                                                                                                                        letterSpacing: 0.0,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                      ),
                                                                                                                  elevation: 0.0,
                                                                                                                  borderSide: BorderSide(
                                                                                                                    color: FlutterFlowTheme.of(context).alternate,
                                                                                                                    width: 1.0,
                                                                                                                  ),
                                                                                                                  borderRadius: BorderRadius.circular(8.0),
                                                                                                                ),
                                                                                                              ),
                                                                                                              Align(
                                                                                                                alignment: AlignmentDirectional(0.94, -3.54),
                                                                                                                child: FutureBuilder<List<MensajesChatRow>>(
                                                                                                                  future: MensajesChatTable().queryRows(
                                                                                                                    queryFn: (q) => q
                                                                                                                        .eqOrNull(
                                                                                                                          'chat_id',
                                                                                                                          // Sin chat el filtro se anulaba y contaba
                                                                                                                          // los no leidos de toda la base.
                                                                                                                          stackChatsSolicitudRow?.id ?? idInexistente,
                                                                                                                        )
                                                                                                                        .neqOrNull(
                                                                                                                          'remitente_id',
                                                                                                                          currentUserUid,
                                                                                                                        )
                                                                                                                        .eqOrNull(
                                                                                                                          'leido',
                                                                                                                          false,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                  builder: (context, snapshot) {
                                                                                                                    // Customize what your widget looks like when it's loading.
                                                                                                                    if (!snapshot.hasData) {
                                                                                                                      return Center(
                                                                                                                        child: SizedBox(
                                                                                                                          width: 50.0,
                                                                                                                          height: 50.0,
                                                                                                                          child: CircularProgressIndicator(
                                                                                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                                                                                              FlutterFlowTheme.of(context).primary,
                                                                                                                            ),
                                                                                                                          ),
                                                                                                                        ),
                                                                                                                      );
                                                                                                                    }
                                                                                                                    List<MensajesChatRow> containerMensajesChatRowList = snapshot.data!;

                                                                                                                    return Container(
                                                                                                                      decoration: BoxDecoration(
                                                                                                                        color: FlutterFlowTheme.of(context).creatividad,
                                                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                                                      ),
                                                                                                                      child: Padding(
                                                                                                                        padding: EdgeInsetsDirectional.fromSTEB(8.0, 3.0, 8.0, 3.0),
                                                                                                                        child: Text(
                                                                                                                          valueOrDefault<String>(
                                                                                                                            containerMensajesChatRowList.length.toString(),
                                                                                                                            '0',
                                                                                                                          ),
                                                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                                font: GoogleFonts.inter(
                                                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                                ),
                                                                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                                                letterSpacing: 0.0,
                                                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                              ),
                                                                                                                        ),
                                                                                                                      ),
                                                                                                                    );
                                                                                                                  },
                                                                                                                ),
                                                                                                              ),
                                                                                                            ],
                                                                                                          ),
                                                                                                        );
                                                                                                      },
                                                                                                    ),
                                                                                                    if (solicitudesAceptadasxItem.estado != 'aceptadas')
                                                                                                      FFButtonWidget(
                                                                                                        onPressed: () async {
                                                                                                          await showModalBottomSheet(
                                                                                                            isScrollControlled: true,
                                                                                                            backgroundColor: Colors.transparent,
                                                                                                            isDismissible: false,
                                                                                                            useSafeArea: true,
                                                                                                            context: context,
                                                                                                            builder: (context) {
                                                                                                              return GestureDetector(
                                                                                                                onTap: () {
                                                                                                                  FocusScope.of(context).unfocus();
                                                                                                                  FocusManager.instance.primaryFocus?.unfocus();
                                                                                                                },
                                                                                                                child: Padding(
                                                                                                                  padding: MediaQuery.viewInsetsOf(context),
                                                                                                                  child: SoporteSeleccionWidget(
                                                                                                                    idServicio: solicitudesAceptadasxItem.ticket!.toString(),
                                                                                                                    action: (respuesta) async {
                                                                                                                      Navigator.pop(context);
                                                                                                                      FFAppState().addToSoporte(SoporteMensajesStruct(
                                                                                                                        rol: 'soporte',
                                                                                                                        mensaje: respuesta,
                                                                                                                        fecha: getCurrentTimestamp.toString(),
                                                                                                                      ));
                                                                                                                      safeSetState(() {});

                                                                                                                      context.pushNamed(
                                                                                                                        SoporteWidget.routeName,
                                                                                                                        extra: <String, dynamic>{
                                                                                                                          '__transition_info__': TransitionInfo(
                                                                                                                            hasTransition: true,
                                                                                                                            transitionType: PageTransitionType.fade,
                                                                                                                            duration: Duration(milliseconds: 0),
                                                                                                                          ),
                                                                                                                        },
                                                                                                                      );
                                                                                                                    },
                                                                                                                  ),
                                                                                                                ),
                                                                                                              );
                                                                                                            },
                                                                                                          ).then((value) => safeSetState(() {}));
                                                                                                        },
                                                                                                        text: 'Soporte',
                                                                                                        icon: Icon(
                                                                                                          Icons.support_agent,
                                                                                                          size: 16.0,
                                                                                                        ),
                                                                                                        options: FFButtonOptions(
                                                                                                          height: 32.0,
                                                                                                          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                          iconColor: FlutterFlowTheme.of(context).accent3,
                                                                                                          color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                                font: GoogleFonts.inter(
                                                                                                                  fontWeight: FontWeight.w600,
                                                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                ),
                                                                                                                color: FlutterFlowTheme.of(context).accent3,
                                                                                                                fontSize: 12.0,
                                                                                                                letterSpacing: 0.0,
                                                                                                                fontWeight: FontWeight.w600,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                              ),
                                                                                                          elevation: 0.0,
                                                                                                          borderSide: BorderSide(
                                                                                                            color: FlutterFlowTheme.of(context).alternate,
                                                                                                            width: 1.0,
                                                                                                          ),
                                                                                                          borderRadius: BorderRadius.circular(8.0),
                                                                                                        ),
                                                                                                      ),
                                                                                                    if (solicitudesAceptadasxItem.estado == 'aceptadas')
                                                                                                      Builder(
                                                                                                        builder: (context) => FFButtonWidget(
                                                                                                          onPressed: () async {
                                                                                                            await showDialog(
                                                                                                              context: context,
                                                                                                              builder: (dialogContext) {
                                                                                                                return Dialog(
                                                                                                                  elevation: 0,
                                                                                                                  insetPadding: EdgeInsets.zero,
                                                                                                                  backgroundColor: Colors.transparent,
                                                                                                                  alignment: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                                                  child: GestureDetector(
                                                                                                                    onTap: () {
                                                                                                                      FocusScope.of(dialogContext).unfocus();
                                                                                                                      FocusManager.instance.primaryFocus?.unfocus();
                                                                                                                    },
                                                                                                                    child: CancelarServicioWidget(
                                                                                                                      solicitudServicioId: solicitudesAceptadasxItem.id,
                                                                                                                      publicacionId: solicitudesAceptadasxItem.getField<String>('publicacion_id'),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                );
                                                                                                              },
                                                                                                            );
                                                                                                            if (SupaFlow.sprint4Habilitado) _recargarSolicitudes();
                                                                                                          },
                                                                                                          text: 'Cancelar',
                                                                                                          icon: Icon(
                                                                                                            Icons.cancel_outlined,
                                                                                                            size: 16.0,
                                                                                                          ),
                                                                                                          options: FFButtonOptions(
                                                                                                            height: 32.0,
                                                                                                            padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                            iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                            iconColor: Color(0xFFBC1021),
                                                                                                            color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                                  font: GoogleFonts.inter(
                                                                                                                    fontWeight: FontWeight.w600,
                                                                                                                    fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                  ),
                                                                                                                  color: Color(0xFFBC1021),
                                                                                                                  fontSize: 12.0,
                                                                                                                  letterSpacing: 0.0,
                                                                                                                  fontWeight: FontWeight.w600,
                                                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                ),
                                                                                                            elevation: 0.0,
                                                                                                            borderSide: BorderSide(
                                                                                                              color: Color(0xFFBC1021),
                                                                                                              width: 1.0,
                                                                                                            ),
                                                                                                            borderRadius: BorderRadius.circular(8.0),
                                                                                                          ),
                                                                                                        ),
                                                                                                      ),
                                                                                                  ].divide(SizedBox(width: 8.0)),
                                                                                                ),
                                                                                                SizedBox(height: 8.0),
                                                                                                if (usaTransicionesSprint3 && solicitudesAceptadasxItem.estado == 'aceptadas' && solicitudesAceptadasxItem.fechaAceptacion == null) const Text('La aceptación anterior requiere revisión del equipo.'),
                                                                                                if (!usaFlujoNuevo || siguiente != null || esperaDiaServicio)
                                                                                                  SizedBox(
                                                                                                    width: double.infinity,
                                                                                                    child: Builder(
                                                                                                      builder: (context) => FFButtonWidget(
                                                                                                        onPressed: esperaDiaServicio || (usaFlujoNuevo && _transicionesPendientes.contains(solicitudesAceptadasxItem.id))
                                                                                                            ? null
                                                                                                            : () async {
                                                                                                                if (usaTransicionesSprint3) {
                                                                                                                  final accion = _siguiente(solicitudesAceptadasxItem);
                                                                                                                  if (accion == AccionSolicitud.termine) {
                                                                                                                    await _abrirCierre(context, solicitudesAceptadasxItem.id);
                                                                                                                  } else if (accion != null) {
                                                                                                                    await _registrarAccion(solicitudesAceptadasxItem, accion);
                                                                                                                  }
                                                                                                                  return;
                                                                                                                }
                                                                                                                if (solicitudesAceptadasxItem.estado == 'aceptadas') {
                                                                                                                  await SolicitudesServicioTable().update(
                                                                                                                    data: {
                                                                                                                      'estado': 'iniciadas',
                                                                                                                    },
                                                                                                                    matchingRows: (rows) => rows.eqOrNull(
                                                                                                                      'id',
                                                                                                                      solicitudesAceptadasxItem.id,
                                                                                                                    ),
                                                                                                                  );
                                                                                                                  _model.apiResultwgo = await SendNotificationUserCall.call(
                                                                                                                    userIdSupabase: solicitudesAceptadasxItem.usuarioId,
                                                                                                                    title: 'Solicitud iniciada',
                                                                                                                    message: 'Tu solicitud ha sido iniciada',
                                                                                                                  );
                                                                                                                } else if (solicitudesAceptadasxItem.estado == 'iniciadas') {
                                                                                                                  await SolicitudesServicioTable().update(
                                                                                                                    data: {
                                                                                                                      'estado': 'en camino',
                                                                                                                    },
                                                                                                                    matchingRows: (rows) => rows.eqOrNull(
                                                                                                                      'id',
                                                                                                                      solicitudesAceptadasxItem.id,
                                                                                                                    ),
                                                                                                                  );
                                                                                                                  _model.apiResult3 = await SendNotificationUserCall.call(
                                                                                                                    userIdSupabase: solicitudesAceptadasxItem.usuarioId,
                                                                                                                    title: 'Solicitud en camino',
                                                                                                                    message: 'Tu solicitud esta en camino',
                                                                                                                  );
                                                                                                                } else if (solicitudesAceptadasxItem.estado == 'en camino') {
                                                                                                                  await SolicitudesServicioTable().update(
                                                                                                                    data: {
                                                                                                                      'estado': 'en proceso',
                                                                                                                    },
                                                                                                                    matchingRows: (rows) => rows.eqOrNull(
                                                                                                                      'id',
                                                                                                                      solicitudesAceptadasxItem.id,
                                                                                                                    ),
                                                                                                                  );
                                                                                                                  _model.apiResult4 = await SendNotificationUserCall.call(
                                                                                                                    userIdSupabase: solicitudesAceptadasxItem.usuarioId,
                                                                                                                    title: 'Solicitud en proceso',
                                                                                                                    message: 'Tu solicitud esta en proceso',
                                                                                                                  );
                                                                                                                } else if (solicitudesAceptadasxItem.estado == 'en proceso') {
                                                                                                                  await _abrirCierre(context, solicitudesAceptadasxItem.id);
                                                                                                                }

                                                                                                                safeSetState(() {});
                                                                                                              },
                                                                                                        text: () {
                                                                                                          if (usaFlujoNuevo) return (siguiente ?? AccionSolicitud.enCamino).boton;
                                                                                                          if (solicitudesAceptadasxItem.estado == 'aceptadas') {
                                                                                                            return 'Iniciar servicio';
                                                                                                          } else if (solicitudesAceptadasxItem.estado == 'iniciadas') {
                                                                                                            return 'Me encuentro en camino';
                                                                                                          } else if (solicitudesAceptadasxItem.estado == 'en camino') {
                                                                                                            return 'El servicio ha comenzado';
                                                                                                          } else if (solicitudesAceptadasxItem.estado == 'en proceso') {
                                                                                                            return 'Finalizar servicio';
                                                                                                          } else {
                                                                                                            return 'Iniciar servicio';
                                                                                                          }
                                                                                                        }(),
                                                                                                        icon: Icon(
                                                                                                          esperaDiaServicio ? Icons.schedule : Icons.check,
                                                                                                          size: 16.0,
                                                                                                        ),
                                                                                                        options: FFButtonOptions(
                                                                                                          height: 48.0,
                                                                                                          padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
                                                                                                          textAlign: TextAlign.center,
                                                                                                          maxLines: 2,
                                                                                                          iconAlignment: IconAlignment.end,
                                                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                          iconColor: FlutterFlowTheme.of(context).success,
                                                                                                          color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                                font: GoogleFonts.inter(
                                                                                                                  fontWeight: FontWeight.w600,
                                                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                                ),
                                                                                                                color: FlutterFlowTheme.of(context).success,
                                                                                                                fontSize: 12.0,
                                                                                                                letterSpacing: 0.0,
                                                                                                                fontWeight: FontWeight.w600,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                              ),
                                                                                                          disabledColor: FlutterFlowTheme.of(context).alternate,
                                                                                                          disabledTextColor: FlutterFlowTheme.of(context).secondaryText,
                                                                                                          elevation: 0.0,
                                                                                                          borderSide: BorderSide(
                                                                                                            color: esperaDiaServicio ? FlutterFlowTheme.of(context).alternate : FlutterFlowTheme.of(context).success,
                                                                                                            width: 1.0,
                                                                                                          ),
                                                                                                          borderRadius: BorderRadius.circular(8.0),
                                                                                                        ),
                                                                                                      ),
                                                                                                    ),
                                                                                                  ),
                                                                                                if (esperaDiaServicio)
                                                                                                  Padding(
                                                                                                    padding: const EdgeInsets.only(top: 8.0),
                                                                                                    child: Text(
                                                                                                      'Disponible únicamente el día del servicio.',
                                                                                                      style: FlutterFlowTheme.of(context).bodySmall,
                                                                                                    ),
                                                                                                  ),
                                                                                              ],
                                                                                            ),
                                                                                          ],
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      theme:
                                                                          ExpandableThemeData(
                                                                        tapHeaderToExpand:
                                                                            false,
                                                                        tapBodyToExpand:
                                                                            false,
                                                                        tapBodyToCollapse:
                                                                            false,
                                                                        headerAlignment:
                                                                            ExpandablePanelHeaderAlignment.center,
                                                                        hasIcon:
                                                                            false,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          if (_pestana ==
                                                              _PestanaSolicitudesProveedor
                                                                  .historial)
                                                            Expanded(
                                                              child:
                                                                  SingleChildScrollView(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .fromLTRB(
                                                                        0,
                                                                        17,
                                                                        0,
                                                                        24),
                                                                child: Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          40.0),
                                                                  child:
                                                                      Container(
                                                                    decoration:
                                                                        BoxDecoration(),
                                                                    child:
                                                                        Container(
                                                                      width: double
                                                                          .infinity,
                                                                      color: Color(
                                                                          0x00000000),
                                                                      child:
                                                                          ExpandableNotifier(
                                                                        controller:
                                                                            _model.finalizadasExpandableController,
                                                                        child:
                                                                            ExpandablePanel(
                                                                          header:
                                                                              const SizedBox.shrink(),
                                                                          collapsed:
                                                                              Container(),
                                                                          expanded:
                                                                              Container(
                                                                            decoration:
                                                                                BoxDecoration(),
                                                                            child:
                                                                                Padding(
                                                                              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                              child: Builder(
                                                                                builder: (context) {
                                                                                  final serviciosFinalizados = containerSolicitudesServicioRowList.where((e) => (!usaTransicionesSprint3 || e.profesionalId == currentUserUid) && _esHistorial(e) && _coincideFiltro(e)).toList()..sort(_compararSolicitudes);
                                                                                  if (serviciosFinalizados.isEmpty) {
                                                                                    return ListaVaciaWidget(
                                                                                      texto: _hayFiltrosActivos || _busquedaSolicitudes.text.isNotEmpty ? 'No hay solicitudes que coincidan con los filtros' : 'Aún no hay solicitudes en el historial',
                                                                                    );
                                                                                  }

                                                                                  return ListView.separated(
                                                                                    padding: EdgeInsets.zero,
                                                                                    primary: false,
                                                                                    shrinkWrap: true,
                                                                                    scrollDirection: Axis.vertical,
                                                                                    itemCount: serviciosFinalizados.length,
                                                                                    separatorBuilder: (_, __) => SizedBox(height: 9.0),
                                                                                    itemBuilder: (context, serviciosFinalizadosIndex) {
                                                                                      final serviciosFinalizadosItem = serviciosFinalizados[serviciosFinalizadosIndex];
                                                                                      final tarjetaExpandida = _tarjetasExpandidas.contains('historial:${serviciosFinalizadosItem.id}');
                                                                                      final citaTarjeta = [
                                                                                        if (serviciosFinalizadosItem.fecha != null) dateTimeFormat('d MMM', serviciosFinalizadosItem.fecha, locale: FFLocalizations.of(context).languageCode),
                                                                                        if (serviciosFinalizadosItem.hora != null) dateTimeFormat('jm', serviciosFinalizadosItem.hora.time, locale: FFLocalizations.of(context).languageCode),
                                                                                      ].join(' · ');
                                                                                      final estadoHistorial = serviciosFinalizadosItem.estado.toLowerCase();
                                                                                      final estadoCancelado = estadoHistorial == 'cancelada' || estadoHistorial == 'canceladas';
                                                                                      final estadoReagendado = estadoHistorial == 'reagendada' || estadoHistorial == 'reagendadas';
                                                                                      final colorEstado = estadoCancelado
                                                                                          ? HulpColors.error
                                                                                          : estadoReagendado
                                                                                              ? Color(0xFF9A6700)
                                                                                              : HulpColors.brand;
                                                                                      final fondoEstado = estadoCancelado
                                                                                          ? Color(0xFFFCE8E8)
                                                                                          : estadoReagendado
                                                                                              ? Color(0xFFFFF4D6)
                                                                                              : HulpColors.brandSoft;
                                                                                      return Container(
                                                                                        decoration: BoxDecoration(
                                                                                          color: HulpColors.surface,
                                                                                          borderRadius: BorderRadius.circular(13.0),
                                                                                          border: Border.all(
                                                                                            color: HulpColors.border,
                                                                                            width: 1.0,
                                                                                          ),
                                                                                          boxShadow: const [
                                                                                            BoxShadow(
                                                                                              color: Color(0x14000000),
                                                                                              blurRadius: 8,
                                                                                              offset: Offset(0, 2),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                        child: Padding(
                                                                                          padding: EdgeInsets.all(6.0),
                                                                                          child: Column(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            children: [
                                                                                              Padding(
                                                                                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                                child: InkWell(
                                                                                                  onTap: () => _alternarTarjetaSolicitud('historial:${serviciosFinalizadosItem.id}'),
                                                                                                  borderRadius: BorderRadius.circular(8.0),
                                                                                                  child: Container(
                                                                                                    decoration: BoxDecoration(
                                                                                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                      borderRadius: BorderRadius.circular(8.0),
                                                                                                    ),
                                                                                                    child: Padding(
                                                                                                      padding: EdgeInsets.all(8.0),
                                                                                                      child: Row(
                                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                        children: [
                                                                                                          _iconoTarjetaServicio(serviciosFinalizadosItem.servicioNombre),
                                                                                                          SizedBox(width: 9.0),
                                                                                                          Container(width: 1.0, height: 48.0, color: HulpColors.border),
                                                                                                          SizedBox(width: 9.0),
                                                                                                          Expanded(
                                                                                                            child: Column(
                                                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                              mainAxisSize: MainAxisSize.min,
                                                                                                              children: [
                                                                                                                Text('#${serviciosFinalizadosItem.ticket ?? '-'}', style: HulpTextStyles.compact.copyWith(color: HulpColors.textSecondary)),
                                                                                                                Text(valueOrDefault<String>(serviciosFinalizadosItem.servicioNombre, '-'), style: HulpTextStyles.card.copyWith(color: HulpColors.brand)),
                                                                                                                NombreClienteWidget(
                                                                                                                  usuarioId: serviciosFinalizadosItem.usuarioId,
                                                                                                                  compacto: true,
                                                                                                                  onNombreCargado: () {
                                                                                                                    if (mounted) safeSetState(() {});
                                                                                                                  },
                                                                                                                ),
                                                                                                                if (citaTarjeta.isNotEmpty) Text(citaTarjeta, style: HulpTextStyles.help),
                                                                                                              ],
                                                                                                            ),
                                                                                                          ),
                                                                                                          Container(
                                                                                                            padding: EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                                                                                                            decoration: BoxDecoration(color: fondoEstado, borderRadius: BorderRadius.circular(20.0)),
                                                                                                            child: Text(_estadoVisible(serviciosFinalizadosItem.estado), style: HulpTextStyles.compact.copyWith(color: colorEstado)),
                                                                                                          ),
                                                                                                          Icon(tarjetaExpandida ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: HulpColors.textPrimary, size: 22.0),
                                                                                                        ],
                                                                                                      ),
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                              if (tarjetaExpandida) ...[
                                                                                                _cabeceraDetalleSolicitud(),
                                                                                                Padding(
                                                                                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                                                                                  child: Row(
                                                                                                    children: [
                                                                                                      Icon(Icons.account_balance_wallet_outlined, color: HulpColors.brand, size: 18.0),
                                                                                                      SizedBox(width: 8.0),
                                                                                                      Expanded(child: Text('Tu pago', style: HulpTextStyles.label)),
                                                                                                      Text(
                                                                                                        '\$${functions.formatPrices(serviciosFinalizadosItem.importeProveedor(() => functions.calcularIngresoProveedor(serviciosFinalizadosItem.precio + (serviciosFinalizadosItem.precioAdicionales ?? 0.0))))} COP',
                                                                                                        style: HulpTextStyles.card.copyWith(color: Color(0xFF3D91F4)),
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                ),
                                                                                                if (serviciosFinalizadosItem.finanzasVersion == 1) DesgloseServicioWidget(solicitudId: serviciosFinalizadosItem.id, actualizacion: '${serviciosFinalizadosItem.finanzasRevision}:${serviciosFinalizadosItem.estadoPago}'),
                                                                                                Padding(
                                                                                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                                                                                  child: Container(
                                                                                                    decoration: BoxDecoration(
                                                                                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                      borderRadius: BorderRadius.circular(8.0),
                                                                                                    ),
                                                                                                    child: Column(
                                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                                      children: [
                                                                                                        Padding(
                                                                                                          padding: EdgeInsets.all(8.0),
                                                                                                          child: Row(
                                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                            children: [
                                                                                                              Row(
                                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                                children: [
                                                                                                                  Icon(Icons.confirmation_number_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                  SizedBox(width: 6.0),
                                                                                                                  Text(
                                                                                                                    'Ticket',
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).accent3,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ],
                                                                                                              ),
                                                                                                              Flexible(
                                                                                                                child: Text(
                                                                                                                  valueOrDefault<String>(
                                                                                                                    serviciosFinalizadosItem.ticket?.toString(),
                                                                                                                    '-',
                                                                                                                  ),
                                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                        font: GoogleFonts.inter(
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                        color: FlutterFlowTheme.of(context).secondary,
                                                                                                                        fontSize: 14.0,
                                                                                                                        letterSpacing: 0.0,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                ),
                                                                                                              ),
                                                                                                            ].divide(SizedBox(width: 8.0)),
                                                                                                          ),
                                                                                                        ),
                                                                                                        NombreClienteWidget(
                                                                                                          usuarioId: serviciosFinalizadosItem.usuarioId,
                                                                                                        ),
                                                                                                        Padding(
                                                                                                          padding: EdgeInsets.all(8.0),
                                                                                                          child: Row(
                                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                            children: [
                                                                                                              Row(
                                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                                children: [
                                                                                                                  Icon(Icons.description_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                  SizedBox(width: 6.0),
                                                                                                                  Text(
                                                                                                                    'Descripcion',
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).accent3,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ],
                                                                                                              ),
                                                                                                              Flexible(
                                                                                                                child: Text(
                                                                                                                  valueOrDefault<String>(
                                                                                                                    serviciosFinalizadosItem.descripcion,
                                                                                                                    'Sin ubicación',
                                                                                                                  ),
                                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                        font: GoogleFonts.inter(
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                        color: FlutterFlowTheme.of(context).secondary,
                                                                                                                        fontSize: 14.0,
                                                                                                                        letterSpacing: 0.0,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                ),
                                                                                                              ),
                                                                                                            ].divide(SizedBox(width: 8.0)),
                                                                                                          ),
                                                                                                        ),
                                                                                                        Padding(
                                                                                                          padding: EdgeInsets.all(8.0),
                                                                                                          child: Row(
                                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                            children: [
                                                                                                              Row(
                                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                                children: [
                                                                                                                  Icon(Icons.check_circle_outline_rounded, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                  SizedBox(width: 6.0),
                                                                                                                  Text(
                                                                                                                    'Estado',
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).accent3,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ],
                                                                                                              ),
                                                                                                              Container(
                                                                                                                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                                                                                                decoration: BoxDecoration(
                                                                                                                  color: fondoEstado,
                                                                                                                  borderRadius: BorderRadius.circular(20.0),
                                                                                                                ),
                                                                                                                child: Text(
                                                                                                                  _estadoVisible(serviciosFinalizadosItem.estado),
                                                                                                                  style: HulpTextStyles.compact.copyWith(color: colorEstado),
                                                                                                                ),
                                                                                                              ),
                                                                                                            ].divide(SizedBox(width: 8.0)),
                                                                                                          ),
                                                                                                        ),
                                                                                                        Padding(
                                                                                                          padding: EdgeInsets.all(8.0),
                                                                                                          child: Row(
                                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                                                                            children: [
                                                                                                              Row(
                                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                                children: [
                                                                                                                  Icon(Icons.calendar_today_outlined, size: 16.0, color: HulpColors.textSecondary),
                                                                                                                  SizedBox(width: 6.0),
                                                                                                                  Text(
                                                                                                                    'Fecha',
                                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                          font: GoogleFonts.inter(
                                                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                          ),
                                                                                                                          color: FlutterFlowTheme.of(context).accent3,
                                                                                                                          fontSize: 14.0,
                                                                                                                          letterSpacing: 0.0,
                                                                                                                        ),
                                                                                                                  ),
                                                                                                                ],
                                                                                                              ),
                                                                                                              Flexible(
                                                                                                                child: Text(
                                                                                                                  dateTimeFormat(
                                                                                                                    "d \'de\' MMMM \'de\' yyyy",
                                                                                                                    serviciosFinalizadosItem.fecha,
                                                                                                                    locale: FFLocalizations.of(context).languageCode,
                                                                                                                  ),
                                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                        font: GoogleFonts.inter(
                                                                                                                          fontWeight: FontWeight.w600,
                                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                        ),
                                                                                                                        color: FlutterFlowTheme.of(context).secondary,
                                                                                                                        fontSize: 14.0,
                                                                                                                        letterSpacing: 0.0,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                      ),
                                                                                                                ),
                                                                                                              ),
                                                                                                            ].divide(SizedBox(width: 8.0)),
                                                                                                          ),
                                                                                                        ),
                                                                                                      ],
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                                Row(
                                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                  children: [
                                                                                                    FFButtonWidget(
                                                                                                      onPressed: () async {
                                                                                                        await showModalBottomSheet(
                                                                                                          isScrollControlled: true,
                                                                                                          backgroundColor: Colors.transparent,
                                                                                                          isDismissible: false,
                                                                                                          useSafeArea: true,
                                                                                                          context: context,
                                                                                                          builder: (context) {
                                                                                                            return GestureDetector(
                                                                                                              onTap: () {
                                                                                                                FocusScope.of(context).unfocus();
                                                                                                                FocusManager.instance.primaryFocus?.unfocus();
                                                                                                              },
                                                                                                              child: Padding(
                                                                                                                padding: MediaQuery.viewInsetsOf(context),
                                                                                                                child: SoporteSeleccionWidget(
                                                                                                                  idServicio: serviciosFinalizadosItem.ticket!.toString(),
                                                                                                                  action: (respuesta) async {
                                                                                                                    Navigator.pop(context);
                                                                                                                    FFAppState().addToSoporte(SoporteMensajesStruct(
                                                                                                                      rol: 'soporte',
                                                                                                                      mensaje: respuesta,
                                                                                                                      fecha: getCurrentTimestamp.toString(),
                                                                                                                    ));
                                                                                                                    safeSetState(() {});

                                                                                                                    context.pushNamed(
                                                                                                                      SoporteWidget.routeName,
                                                                                                                      extra: <String, dynamic>{
                                                                                                                        '__transition_info__': TransitionInfo(
                                                                                                                          hasTransition: true,
                                                                                                                          transitionType: PageTransitionType.fade,
                                                                                                                          duration: Duration(milliseconds: 0),
                                                                                                                        ),
                                                                                                                      },
                                                                                                                    );
                                                                                                                  },
                                                                                                                ),
                                                                                                              ),
                                                                                                            );
                                                                                                          },
                                                                                                        ).then((value) => safeSetState(() {}));
                                                                                                      },
                                                                                                      text: 'Soporte',
                                                                                                      icon: Icon(
                                                                                                        Icons.support_agent,
                                                                                                        size: 16.0,
                                                                                                      ),
                                                                                                      options: FFButtonOptions(
                                                                                                        height: 32.0,
                                                                                                        padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                        iconColor: FlutterFlowTheme.of(context).accent3,
                                                                                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                              font: GoogleFonts.inter(
                                                                                                                fontWeight: FontWeight.w600,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                              ),
                                                                                                              color: FlutterFlowTheme.of(context).accent3,
                                                                                                              fontSize: 14.0,
                                                                                                              letterSpacing: 0.0,
                                                                                                              fontWeight: FontWeight.w600,
                                                                                                              fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                            ),
                                                                                                        elevation: 0.0,
                                                                                                        borderSide: BorderSide(
                                                                                                          color: FlutterFlowTheme.of(context).alternate,
                                                                                                          width: 1.0,
                                                                                                        ),
                                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                                      ),
                                                                                                    ),
                                                                                                    FFButtonWidget(
                                                                                                      onPressed: () async {
                                                                                                        _model.vvsidd = await VwSolicitudesServiciosCompletaTable().queryRows(
                                                                                                          queryFn: (q) => q.eqOrNull(
                                                                                                            'solicitud_id',
                                                                                                            serviciosFinalizadosItem.id,
                                                                                                          ),
                                                                                                        );

                                                                                                        if (_model.vvsidd?.firstOrNull == null) {
                                                                                                          // La solicitud ya no existe (la borraron desde el admin): abrir
                                                                                                          // el chat sin servicio mostraba la conversacion de otro cliente.
                                                                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                                                                            SnackBar(
                                                                                                              content: Text(
                                                                                                                'Esta solicitud ya no está disponible.',
                                                                                                                style: TextStyle(color: FlutterFlowTheme.of(context).primaryBackground),
                                                                                                              ),
                                                                                                              duration: Duration(milliseconds: 4000),
                                                                                                              backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                                            ),
                                                                                                          );
                                                                                                          safeSetState(() {});
                                                                                                          return;
                                                                                                        }

                                                                                                        context.pushNamed(
                                                                                                          ChatWidget.routeName,
                                                                                                          queryParameters: {
                                                                                                            'servicio': serializeParam(
                                                                                                              _model.vvsidd?.firstOrNull,
                                                                                                              ParamType.SupabaseRow,
                                                                                                            ),
                                                                                                          }.withoutNulls,
                                                                                                        );

                                                                                                        safeSetState(() {});
                                                                                                      },
                                                                                                      text: 'Chat',
                                                                                                      icon: Icon(
                                                                                                        Icons.support_agent,
                                                                                                        size: 16.0,
                                                                                                      ),
                                                                                                      options: FFButtonOptions(
                                                                                                        height: 32.0,
                                                                                                        padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                                        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                                        iconColor: FlutterFlowTheme.of(context).accent3,
                                                                                                        color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                                              font: GoogleFonts.inter(
                                                                                                                fontWeight: FontWeight.w600,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                              ),
                                                                                                              color: FlutterFlowTheme.of(context).accent3,
                                                                                                              fontSize: 12.0,
                                                                                                              letterSpacing: 0.0,
                                                                                                              fontWeight: FontWeight.w600,
                                                                                                              fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                                            ),
                                                                                                        elevation: 0.0,
                                                                                                        borderSide: BorderSide(
                                                                                                          color: FlutterFlowTheme.of(context).alternate,
                                                                                                          width: 1.0,
                                                                                                        ),
                                                                                                        borderRadius: BorderRadius.circular(8.0),
                                                                                                      ),
                                                                                                    ),
                                                                                                  ].divide(SizedBox(width: 8.0)),
                                                                                                ),
                                                                                              ],
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                  );
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          theme:
                                                                              ExpandableThemeData(
                                                                            tapHeaderToExpand:
                                                                                false,
                                                                            tapBodyToExpand:
                                                                                false,
                                                                            tapBodyToCollapse:
                                                                                false,
                                                                            headerAlignment:
                                                                                ExpandablePanelHeaderAlignment.center,
                                                                            hasIcon:
                                                                                false,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  wrapWithModel(
                    model: _model.menModel,
                    updateCallback: () => safeSetState(() {}),
                    child: MenWidget(
                      index: 0,
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

class _PanelFiltrosSolicitudesProveedor extends StatefulWidget {
  const _PanelFiltrosSolicitudesProveedor({
    required this.filtro,
    required this.estados,
  });

  final _FiltrosSolicitudesProveedor filtro;
  final List<String> estados;

  @override
  State<_PanelFiltrosSolicitudesProveedor> createState() =>
      _PanelFiltrosSolicitudesProveedorState();
}

class _PanelFiltrosSolicitudesProveedorState
    extends State<_PanelFiltrosSolicitudesProveedor> {
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
        const filtroInicial = _FiltrosSolicitudesProveedor();
        _estado = filtroInicial.estado;
        _fechas = filtroInicial.fechas;
        _masRecientes = filtroInicial.masRecientes;
      });

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  Widget _opcion(String texto, bool seleccionada, VoidCallback accion) {
    final theme = FlutterFlowTheme.of(context);
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionada,
      showCheckmark: false,
      onSelected: (_) => accion(),
      backgroundColor: theme.secondaryBackground,
      selectedColor: theme.primary.withValues(alpha: 0.12),
      side: BorderSide(color: seleccionada ? theme.primary : theme.alternate),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: seleccionada ? theme.primary : theme.primaryText,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fechas = _fechas;
    final titulo = theme.bodyMedium.copyWith(fontWeight: FontWeight.w600);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrar solicitudes',
                    style: theme.titleMedium.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('Estado', style: titulo),
            Wrap(
              spacing: 6,
              children: [
                for (final estado in [null, ...widget.estados])
                  _opcion(
                    estado ?? 'Todos',
                    _estado == estado,
                    () => setState(() => _estado = estado),
                  ),
              ],
            ),
            const Divider(),
            Text('Fecha del servicio', style: titulo),
            Wrap(
              spacing: 6,
              children: [
                _opcion(
                  'Todas las fechas',
                  fechas == null,
                  () => setState(() => _fechas = null),
                ),
                _opcion('Elegir rango', fechas != null, _elegirFechas),
              ],
            ),
            if (fechas != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_fechaTexto(fechas.start)} – ${_fechaTexto(fechas.end)}',
                  style: theme.bodySmall,
                ),
              ),
            const Divider(),
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
                      foregroundColor: theme.primary,
                      side: BorderSide(color: theme.primary),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _FiltrosSolicitudesProveedor(
                        estado: _estado,
                        fechas: _fechas,
                        masRecientes: _masRecientes,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.secondaryBackground,
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
