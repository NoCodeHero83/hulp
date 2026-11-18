import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talento_hulp/backend/solicitudes_stream.dart';

void main() {
  test('Entrantes actualiza por servidor y recupera la lista tras un error',
      () async {
    var consultas = 0;
    final cliente = SupabaseClient(
      'https://solicitudes.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/solicitudes_servicio');
        expect(request.url.queryParameters['estado'], 'eq.entrantes');
        final (cuerpo, estado) = switch (++consultas) {
          2 => ('{"message":"Sin conexión"}', 503),
          >= 4 => ('[]', 200),
          _ => ('[{"id":"oferta"}]', 200),
        };
        return http.Response(cuerpo, estado,
            request: request,
            headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(cliente.dispose);
    final stream = SolicitudesStream(
      cliente,
      refreshInterval: const Duration(milliseconds: 10),
    ).eq('estado', 'entrantes');
    const abierta = [
      {'id': 'oferta'},
    ];

    await expectLater(
      stream,
      emitsInOrder([
        abierta,
        emitsError(isA<PostgrestException>()),
        abierta,
        isEmpty,
      ]),
    );
  });
}
