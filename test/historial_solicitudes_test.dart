import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulp/backend/supabase/supabase.dart';
import 'package:hulp/registro/pages/historial/historial_model.dart';

VwSolicitudesServiciosCompletaRow _solicitud({
  String? fecha,
  String? hora,
  int? ticket,
}) =>
    VwSolicitudesServiciosCompletaRow({
      'ticket': ticket,
      'servicio_nombre': 'Limpieza de tuberías',
      'fecha': fecha,
      'hora': hora,
    });

void main() {
  test('mantiene las solicitudes abiertas en En proceso', () {
    for (final estado in [
      'entrantes',
      'aceptadas',
      'iniciadas',
      'en camino',
      'en proceso',
    ]) {
      expect(pestanaDeSolicitud(estado), PestanaSolicitudes.enProceso);
    }
    for (final estado in [
      'finalizadas',
      'cancelada',
      'canceladas',
      'reagendada',
      'reagendadas',
      null,
    ]) {
      expect(pestanaDeSolicitud(estado), PestanaSolicitudes.historial);
    }
  });

  test('conserva el estado que corresponde a cada ambiente', () {
    expect(estadoVisibleDeSolicitud('aceptadas', sprint3: true), 'Aceptado');
    expect(estadoVisibleDeSolicitud('aceptadas', sprint3: false), 'Activo');
    expect(estadoVisibleDeSolicitud('en camino', sprint3: true), 'Activo');
    expect(estadoVisibleDeSolicitud('en camino', sprint3: false), 'En curso');
  });

  test('combina búsqueda, estado y ambos extremos del rango de fechas', () {
    final filtros = FiltrosSolicitudes(
      estado: 'Aceptado',
      fechas: DateTimeRange(
          start: DateTime(2026, 11, 15), end: DateTime(2026, 11, 18)),
      masRecientes: false,
    );
    final inicio = _solicitud(fecha: '2026-11-15', ticket: 1);
    final fin = _solicitud(fecha: '2026-11-18', ticket: 2);
    final fuera = _solicitud(fecha: '2026-11-19', ticket: 3);
    expect(filtros.coincide(inicio, 'Aceptado', 'tuberías'), isTrue);
    expect(filtros.coincide(fin, 'Aceptado', 'limpieza'), isTrue);
    expect(filtros.coincide(fin, 'Pendiente', 'limpieza'), isFalse);
    expect(filtros.coincide(fin, 'Aceptado', 'jardinería'), isFalse);
    expect(filtros.coincide(fuera, 'Aceptado', ''), isFalse);
  });

  test('ordena por ticket aunque las fechas difieran y deja los nulos al final',
      () {
    final filas = [
      _solicitud(fecha: '2026-11-18', hora: '11:30:00', ticket: 1109),
      _solicitud(fecha: '2026-11-18', hora: '09:00:00', ticket: 1120),
      _solicitud(fecha: '2026-11-17', hora: '09:00:00', ticket: 1119),
      _solicitud(fecha: '2026-11-19'),
    ];
    var filtros = const FiltrosSolicitudes(masRecientes: false);
    expect((filas..sort(filtros.comparar)).map((fila) => fila.ticket),
        [1109, 1119, 1120, null]);
    filtros = const FiltrosSolicitudes(masRecientes: true);
    expect((filas..sort(filtros.comparar)).map((fila) => fila.ticket),
        [1120, 1119, 1109, null]);
  });
}
