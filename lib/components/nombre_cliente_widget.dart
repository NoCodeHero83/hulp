import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nombre del cliente en la tarjeta de servicio.
///
/// La tarjeta mostraba ticket, dirección, fecha, hora y precio, pero nunca el
/// nombre de quien pidió el servicio: el proveedor llegaba a la puerta sin
/// saber por quién preguntar.
///
/// `solicitudes_servicio` solo guarda `usuario_id`, así que hay que ir a
/// buscarlo. La consulta se hace una vez por tarjeta y se cachea en el propio
/// estado; son pocas tarjetas por pantalla.
class NombreClienteWidget extends StatefulWidget {
  const NombreClienteWidget({
    super.key,
    required this.usuarioId,
    this.compacto = false,
    this.onNombreCargado,
  });

  final String? usuarioId;
  final bool compacto;
  final VoidCallback? onNombreCargado;

  static String? nombreEnCache(String? usuarioId) =>
      _NombreClienteWidgetState.nombreEnCache(usuarioId);

  static Future<void> precargarNombres(Iterable<String?> usuarioIds) =>
      _NombreClienteWidgetState.precargarNombres(usuarioIds);

  @override
  State<NombreClienteWidget> createState() => _NombreClienteWidgetState();
}

class _NombreClienteWidgetState extends State<NombreClienteWidget> {
  static final Map<String, Future<List<UsuariosRow>>> _consultasPorUsuario = {};
  static final Map<String, String> _nombresPorUsuario = {};
  Future<List<UsuariosRow>>? _consulta;

  static String? nombreEnCache(String? usuarioId) =>
      usuarioId == null ? null : _nombresPorUsuario[usuarioId];

  static Future<void> precargarNombres(Iterable<String?> usuarioIds) async {
    final ids = usuarioIds
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_nombresPorUsuario.containsKey(id))
        .toSet();
    if (ids.isEmpty) return;

    try {
      final usuarios = await UsuariosTable().queryRows(
        queryFn: (q) => q.inFilter('id', ids.toList()),
      );
      final porId = {for (final usuario in usuarios) usuario.id: usuario};
      for (final id in ids) {
        final usuario = porId[id];
        _nombresPorUsuario[id] = [
          usuario?.nombres ?? '',
          usuario?.apellidos ?? '',
        ].join(' ').trim();
        _consultasPorUsuario.putIfAbsent(
          id,
          () => Future.value(usuario == null ? <UsuariosRow>[] : [usuario]),
        );
      }
    } catch (_) {
      // La búsqueda por servicio y ticket sigue funcionando si falla esta carga.
      for (final id in ids) {
        _nombresPorUsuario.putIfAbsent(id, () => '');
      }
    }
  }

  static Future<List<UsuariosRow>> _consultaPara(String usuarioId) =>
      _consultasPorUsuario.putIfAbsent(
        usuarioId,
        () => UsuariosTable().querySingleRow(
          queryFn: (q) => q.eqOrNull('id', usuarioId),
        ),
      );

  @override
  void initState() {
    super.initState();
    _consulta = _buscarCliente();
  }

  @override
  void didUpdateWidget(NombreClienteWidget anterior) {
    super.didUpdateWidget(anterior);
    // Las tarjetas se reciclan al llegar datos nuevos por el stream: si cambia
    // la solicitud hay que volver a preguntar, o se queda el nombre anterior.
    if (anterior.usuarioId != widget.usuarioId) {
      _consulta = _buscarCliente();
    }
  }

  Future<List<UsuariosRow>> _buscarCliente() async {
    final id = widget.usuarioId;
    if (id == null || id.isEmpty) return const [];
    return _consultaPara(id);
  }

  @override
  Widget build(BuildContext context) {
    final tema = FlutterFlowTheme.of(context);

    return FutureBuilder<List<UsuariosRow>>(
      future: _consulta,
      builder: (context, snapshot) {
        // Mientras carga no se pinta nada: un esqueleto o un "cargando" en una
        // línea de texto tan corta da más ruido que información.
        if (!snapshot.hasData) return const SizedBox.shrink();

        final cliente = snapshot.data!.firstOrNull;
        final nombre = [
          cliente?.nombres ?? '',
          cliente?.apellidos ?? '',
        ].join(' ').trim();
        if (nombre.isEmpty) return const SizedBox.shrink();
        final usuarioId = widget.usuarioId;
        if (usuarioId != null && _nombresPorUsuario[usuarioId] != nombre) {
          _nombresPorUsuario[usuarioId] = nombre;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onNombreCargado?.call();
          });
        }

        if (widget.compacto) {
          return Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(Icons.person_outline, size: 14, color: tema.accent3),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.bodySmall.copyWith(
                    color: tema.accent3,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 16, color: tema.accent3),
                  const SizedBox(width: 6),
                  Text(
                    'Cliente',
                    style: tema.bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: tema.bodyMedium.fontWeight,
                        fontStyle: tema.bodyMedium.fontStyle,
                      ),
                      color: tema.accent3,
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  nombre,
                  textAlign: TextAlign.end,
                  style: tema.bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle: tema.bodyMedium.fontStyle,
                    ),
                    fontSize: 14.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
