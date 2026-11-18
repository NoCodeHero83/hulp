import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '/flutter_flow/estado_solicitud_cliente.dart';
import '/flutter_flow/flutter_flow_model.dart';
import 'historial_widget.dart' show HistorialWidget;

enum PestanaSolicitudes { enProceso, historial }

const _estadosEnProceso = {
  'entrantes',
  'aceptadas',
  'iniciadas',
  'en camino',
  'en proceso',
};

PestanaSolicitudes pestanaDeSolicitud(String? estado) =>
    _estadosEnProceso.contains(estado)
        ? PestanaSolicitudes.enProceso
        : PestanaSolicitudes.historial;

String estadoVisibleDeSolicitud(String? estado, {required bool sprint3}) {
  if (sprint3) return etiquetaEstadoSprint3Cliente(estado);
  return switch (estado) {
    'aceptadas' => 'Activo',
    'iniciadas' || 'en camino' || 'en proceso' => 'En curso',
    _ => etiquetaEstadoSprint3Cliente(estado),
  };
}

class FiltrosSolicitudes {
  const FiltrosSolicitudes({
    this.estado,
    this.fechas,
    required this.masRecientes,
  });

  final String? estado;
  final DateTimeRange? fechas;
  final bool masRecientes;

  bool coincide(
    VwSolicitudesServiciosCompletaRow solicitud,
    String estadoVisible,
    String busqueda,
  ) {
    if (estado != null && estado != estadoVisible) return false;
    final rango = fechas;
    if (rango != null) {
      final fecha = solicitud.fecha;
      if (fecha == null) return false;
      final dia = DateUtils.dateOnly(fecha);
      if (dia.isBefore(rango.start) || dia.isAfter(rango.end)) return false;
    }
    return (solicitud.servicioNombre ?? '').toLowerCase().contains(busqueda);
  }

  int comparar(
    VwSolicitudesServiciosCompletaRow a,
    VwSolicitudesServiciosCompletaRow b,
  ) {
    final ticketA = a.ticket;
    final ticketB = b.ticket;
    if (ticketA == null) return ticketB == null ? 0 : 1;
    if (ticketB == null) return -1;
    return masRecientes
        ? ticketB.compareTo(ticketA)
        : ticketA.compareTo(ticketB);
  }
}

class HistorialModel extends FlutterFlowModel<HistorialWidget> {
  final busqueda = TextEditingController();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() => busqueda.dispose();
}
