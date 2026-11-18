import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hulp/auth/supabase_auth/supabase_user_provider.dart';
import 'package:hulp/custom_code/widgets/nequi_verification_button.dart';
import 'package:hulp/flutter_flow/flutter_flow_widgets.dart';
import 'package:hulp/nequi_registro/nequi_registro_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var metodos = <Map<String, dynamic>>[];
  var fallarConsulta = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://nequi.test',
      anonKey: 'test-key',
      debug: false,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/metodos_pago');
        expect(request.url.queryParameters['usuario_id'], 'eq.cliente-prueba');
        expect(request.url.queryParameters['tipo'], 'eq.NEQUI');
        return http.Response(
          fallarConsulta
              ? '{"message":"Consulta no disponible"}'
              : jsonEncode(metodos),
          fallarConsulta ? 500 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    metodos = [];
    fallarConsulta = false;
    currentUser = HulpSupabaseUser(const User(
      id: 'cliente-prueba',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-11-01T00:00:00Z',
    ));
  });
  tearDown(() => currentUser = null);

  Future<void> montar(WidgetTester tester) async {
    // Evita descargar el logo durante la prueba del formulario.
    final imagen = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.white, BlendMode.src);
      return recorder.endRecording().toImage(1, 1);
    });
    const logo = NetworkImage(
        'https://www.enter.co/wp-content/uploads/2023/10/Logo-Nequi-2-1200x675.jpg');
    PaintingBinding.instance.imageCache.putIfAbsent(
        logo,
        () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: imagen!))));
    await tester.pumpWidget(const MaterialApp(home: NequiRegistroWidget()));
    await tester.pump();
  }

  FFButtonWidget boton(WidgetTester tester) =>
      tester.widget<FFButtonWidget>(find.descendant(
          of: find.byType(NequiVerificationButton),
          matching: find.byType(FFButtonWidget)));

  testWidgets('muestra el vínculo guardado sin preparar una nueva vinculación',
      (tester) async {
    metodos = [
      {'estado': 'Inactivo', 'es_predeterminado': true},
      {'estado': 'Activo', 'numero_telefono': '399 111 1111'},
      {
        'estado': 'Active',
        'numero_telefono': '+57 399 111 1234',
        'es_predeterminado': true,
      },
    ];
    await http.runWithClient(() async {
      await montar(tester);
      await tester.pumpAndSettle();
      expect(find.text('Nequi vinculado'), findsOneWidget);
      expect(find.text('+57 ••• ••• 1234'), findsOneWidget);
      expect(find.text('+57 399 111 1234'), findsNothing);
      expect(find.text('Predeterminado'), findsOneWidget);
      expect(find.byType(NequiVerificationButton), findsNothing);
    }, () => MockClient((_) => throw StateError('No debe consultar Wompi')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reintenta la consulta del vínculo si falla', (tester) async {
    fallarConsulta = true;
    await montar(tester);
    await tester.pumpAndSettle();
    expect(
        find.text('No pudimos consultar tu método de pago.'), findsOneWidget);
    expect(find.byType(NequiVerificationButton), findsNothing);

    fallarConsulta = false;
    metodos = [
      {'estado': 'Activo'}
    ];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Nequi vinculado'), findsOneWidget);
    expect(find.text('Predeterminado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('espera ambos tokens y envía el teléfono escrito sin espacios',
      (tester) async {
    final tokens = Completer<http.Response>();
    final tokenizacion = Completer<http.Response>();
    Map<String, dynamic>? enviado;
    await http.runWithClient(() async {
      await montar(tester);
      expect(boton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), ' 3991111111 ');
      await tester.pump();
      expect(boton(tester).onPressed, isNull);
      tokens.complete(http.Response(
          jsonEncode({
            'data': {
              'presigned_acceptance': {'acceptance_token': 'aceptacion-real'},
              'presigned_personal_data_auth': {
                'acceptance_token': 'autorizacion-real'
              },
            },
          }),
          200));
      await tester.pumpAndSettle();
      final widget = tester.widget<NequiVerificationButton>(
          find.byType(NequiVerificationButton));
      expect(widget.acceptanceToken, 'aceptacion-real');
      expect(widget.acceptPersonalAuth, 'autorizacion-real');
      expect(boton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Vincula'));
      await tester.pump();
      expect(enviado?['phone_number'], '3991111111');
      expect(
          find.text('Por favor ingresa un número de teléfono'), findsNothing);
      tokenizacion
          .complete(http.Response('{"data":{"id":"nequi-prueba"}}', 201));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/merchants/info')) {
                return tokens.future;
              }
              expect(request.url.host, 'sandbox.wompi.co');
              expect(request.url.path, '/v1/tokens/nequi');
              enviado = jsonDecode(request.body) as Map<String, dynamic>;
              return tokenizacion.future;
            }));
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite reintentar sin vincular con tokens incompletos',
      (tester) async {
    var consultas = 0;
    await http.runWithClient(() async {
      await montar(tester);
      await tester.pumpAndSettle();
      expect(boton(tester).onPressed, isNull);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(boton(tester).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              consultas++;
              return http.Response(
                  jsonEncode({
                    'data': {
                      'presigned_acceptance': {
                        'acceptance_token': 'aceptacion'
                      },
                      'presigned_personal_data_auth': {
                        'acceptance_token':
                            consultas == 1 ? null : 'autorizacion',
                      },
                    },
                  }),
                  200);
            }));
    expect(tester.takeException(), isNull);
  });
}
