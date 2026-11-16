import '/components/encabezado_principal_widget.dart';
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/hulp_colors.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nequi_registro_model.dart';
export 'nequi_registro_model.dart';

class NequiRegistroWidget extends StatefulWidget {
  const NequiRegistroWidget({super.key});

  static String routeName = 'NequiRegistro';
  static String routePath = '/nequiRegistro';

  @override
  State<NequiRegistroWidget> createState() => _NequiRegistroWidgetState();
}

class _NequiRegistroWidgetState extends State<NequiRegistroWidget> {
  late NequiRegistroModel _model;
  bool _consultandoVinculo = true;
  bool _errorVinculo = false;
  MetodosPagoRow? _nequiVinculado;
  bool _cargandoTokens = true;
  String? _errorTokens;
  String _acceptanceToken = '';
  String _personalDataAuthToken = '';

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NequiRegistroModel());

    SchedulerBinding.instance.addPostFrameCallback((_) => _cargarVinculo());

    _model.textController ??= TextEditingController();
    _model.textController!.addListener(_actualizarTelefono);
    _model.textFieldFocusNode ??= FocusNode();
  }

  void _actualizarTelefono() {
    if (mounted) setState(() {});
  }

  Future<void> _cargarVinculo() async {
    if (!mounted) return;
    setState(() {
      _consultandoVinculo = true;
      _errorVinculo = false;
    });
    try {
      final usuarioId = currentUserUid;
      if (usuarioId.isEmpty) throw StateError('Sesión no disponible');
      final metodos = await MetodosPagoTable()
          .queryRows(
            queryFn: (q) => q
                .eq('usuario_id', usuarioId)
                .eq('tipo', 'NEQUI')
                .order('creado_en', ascending: false, nullsFirst: false),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final activos = metodos.where((metodo) => const {'activo', 'active'}
          .contains(metodo.estado.trim().toLowerCase()));
      final vinculado = activos
              .where((metodo) => metodo.esPredeterminado == true)
              .firstOrNull ??
          activos.firstOrNull;
      setState(() {
        _nequiVinculado = vinculado;
        _consultandoVinculo = false;
      });
      if (vinculado == null) await _cargarTokens();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consultandoVinculo = false;
        _errorVinculo = true;
      });
    }
  }

  Widget _tarjetaVinculo(MetodosPagoRow metodo) {
    final tema = FlutterFlowTheme.of(context);
    final digitos = (metodo.numeroTelefono ?? metodo.ultimosCuatro ?? '')
        .replaceAll(RegExp(r'\D'), '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HulpColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: tema.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nequi vinculado',
                    style: tema.titleSmall.copyWith(color: tema.primary)),
                if (digitos.length >= 4)
                  Text('+57 ••• ••• ${digitos.substring(digitos.length - 4)}',
                      style: tema.bodyMedium),
                if (metodo.esPredeterminado == true)
                  Text('Predeterminado', style: tema.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarTokens() async {
    if (!mounted) return;
    setState(() {
      _cargandoTokens = true;
      _errorTokens = null;
      _acceptanceToken = '';
      _personalDataAuthToken = '';
    });
    try {
      final respuesta = await actions
          .getAcceptanceToken(
            FFDevEnvironmentValues().publicKey,
            FFDevEnvironmentValues().isProduction,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      String leerToken(String campo) {
        final valor = respuesta is Map ? respuesta[campo] : null;
        if (valor is! String || valor.trim() == 'null') return '';
        return valor.trim();
      }

      final aceptacion = leerToken('acceptanceToken');
      final autorizacion = leerToken('personalDataAuthToken');
      if (respuesta is! Map ||
          respuesta['success'] != true ||
          aceptacion.isEmpty ||
          autorizacion.isEmpty) {
        throw StateError('Tokens de aceptación no disponibles');
      }
      setState(() {
        _acceptanceToken = aceptacion;
        _personalDataAuthToken = autorizacion;
        _cargandoTokens = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoTokens = false;
        _errorTokens = 'No se pudo preparar la vinculación con Wompi. '
            'Reintenta para continuar.';
      });
    }
  }

  @override
  void dispose() {
    _model.textController?.removeListener(_actualizarTelefono);
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: EncabezadoPrincipalWidget.subpantalla(
          titulo: 'Nequi',
          alVolver: context.safePop,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsets.all(10.0),
            child: ListView(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      'https://www.enter.co/wp-content/uploads/2023/10/Logo-Nequi-2-1200x675.jpg',
                      width: 200.0,
                      height: 100.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (_consultandoVinculo)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text('Consultando tu método de pago…',
                        textAlign: TextAlign.center),
                  )
                else if (_errorVinculo) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text('No pudimos consultar tu método de pago.',
                        textAlign: TextAlign.center),
                  ),
                  TextButton(
                    onPressed: _cargarVinculo,
                    child: const Text('Reintentar'),
                  ),
                ] else if (_nequiVinculado case final metodo?)
                  _tarjetaVinculo(metodo)
                else ...[
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          '+57',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                        Expanded(
                          child: Container(
                            width: 200.0,
                            child: TextFormField(
                              controller: _model.textController,
                              focusNode: _model.textFieldFocusNode,
                              autofocus: false,
                              enabled: true,
                              obscureText: false,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                isDense: true,
                                labelStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                hintText: 'Numero de telefono',
                                hintStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0x00000000),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).primary,
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).error,
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).error,
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              cursorColor:
                                  FlutterFlowTheme.of(context).primaryText,
                              enableInteractiveSelection: true,
                              validator: _model.textControllerValidator
                                  .asValidator(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_cargandoTokens)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text('Preparando vinculación...'),
                    ),
                  if (_errorTokens != null) ...[
                    Text(_errorTokens!),
                    TextButton(
                      onPressed: _cargarTokens,
                      child: const Text('Reintentar'),
                    ),
                  ],
                  // 48 de alto, como el resto de botones de la app. Estaba en
                  // 80 y el botón salía desproporcionado.
                  Container(
                    width: MediaQuery.sizeOf(context).width * 1.0,
                    height: 48.0,
                    child: custom_widgets.NequiVerificationButton(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      height: 48.0,
                      phoneNumber: _model.textController.text.trim(),
                      enabled: !_cargandoTokens &&
                          _errorTokens == null &&
                          _acceptanceToken.isNotEmpty &&
                          _personalDataAuthToken.isNotEmpty,
                      publicKey: FFDevEnvironmentValues().publicKey,
                      privateKey: FFDevEnvironmentValues().privateKey,
                      customerEmail: currentUserEmail,
                      acceptanceToken: _acceptanceToken,
                      acceptPersonalAuth: _personalDataAuthToken,
                      buttonText: 'Vincula',
                      buttonColor: FlutterFlowTheme.of(context).primary,
                      textColor:
                          FlutterFlowTheme.of(context).secondaryBackground,
                      onSuccess: (paymentSourceId) async {
                        // Guardar el método de pago Nequi recién creado en Wompi.
                        await MetodosPagoTable().insert({
                          'usuario_id': currentUserUid,
                          'payment_source_id': paymentSourceId,
                          'tipo': 'NEQUI',
                          'estado': 'Activo',
                          'email_cliente': valueOrDefault<String>(
                            currentUserEmail,
                            'admin@hulp.com',
                          ),
                          'tipo_cuenta': 'NEQUI',
                          'numero_telefono': _model.textController.text.trim(),
                          'es_predeterminado': true,
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Nequi vinculado correctamente',
                              style: TextStyle(
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                            duration: Duration(milliseconds: 3000),
                            backgroundColor:
                                FlutterFlowTheme.of(context).primary,
                          ),
                        );
                        context.pop();
                      },
                      onError: (error) async {},
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
