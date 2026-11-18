import 'dart:async';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime o un intervalo indican cuándo volver a leer la lista por rol.
/// No se reconstruyen importes usando un evento parcial ni notas privadas.
class SolicitudesStream extends Stream<List<Map<String, dynamic>>> {
  SolicitudesStream(
    this.client, {
    Map<String, Object>? filters,
    this.refreshInterval,
  }) : filters = filters ?? {};
  final SupabaseClient client;
  final Map<String, Object> filters;
  final Duration? refreshInterval;

  SolicitudesStream eq(String column, Object value) => SolicitudesStream(
        client,
        filters: {...filters, column: value},
        refreshInterval: refreshInterval,
      );
  SolicitudesStream eqOrNull(String column, Object? value) =>
      value == null ? this : eq(column, value);

  @override
  StreamSubscription<List<Map<String, dynamic>>> listen(
    void Function(List<Map<String, dynamic>>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    late StreamController<List<Map<String, dynamic>>> controller;
    RealtimeChannel? channel;
    Timer? timer;
    var loading = false, queued = false, cancelled = false;
    List<Map<String, dynamic>>? previous;
    Future<void> refresh() async {
      if (cancelled || controller.isClosed) return;
      if (loading) {
        queued = true;
        return;
      }
      loading = true;
      do {
        queued = false;
        try {
          var query = client.from('solicitudes_servicio').select();
          for (final f in filters.entries) {
            query = query.eq(f.key, f.value);
          }
          final rows = await query;
          if (!cancelled &&
              !controller.isClosed &&
              !const DeepCollectionEquality().equals(previous, rows)) {
            previous = rows;
            controller.add(rows);
          }
        } catch (e, trace) {
          if (!cancelled && !controller.isClosed) {
            previous = null;
            controller.addError(e, trace);
          }
        }
      } while (queued && !cancelled && !controller.isClosed);
      loading = false;
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        final interval = refreshInterval;
        if (interval != null) {
          timer = Timer.periodic(interval, (_) => refresh());
        } else {
          channel = client
              .channel(
                  'solicitudes-${DateTime.now().microsecondsSinceEpoch}-$hashCode')
              .onPostgresChanges(
                  event: PostgresChangeEvent.all,
                  schema: 'public',
                  table: 'solicitudes_servicio',
                  callback: (_) => refresh())
              .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) refresh();
          });
        }
        refresh();
      },
      onCancel: () async {
        cancelled = true;
        timer?.cancel();
        if (channel != null) await client.removeChannel(channel!);
      },
    );
    return controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
