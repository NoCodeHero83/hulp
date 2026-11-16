import '/components/encabezado_principal_widget.dart';
import '/components/menu_bar_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'politicadeprivacidad_model.dart';
export 'politicadeprivacidad_model.dart';

class PoliticadeprivacidadWidget extends StatefulWidget {
  const PoliticadeprivacidadWidget({super.key});

  static String routeName = 'politicadeprivacidad';
  static String routePath = '/politicadeprivacidad';

  @override
  State<PoliticadeprivacidadWidget> createState() =>
      _PoliticadeprivacidadWidgetState();
}

class _PoliticadeprivacidadWidgetState
    extends State<PoliticadeprivacidadWidget> {
  late PoliticadeprivacidadModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PoliticadeprivacidadModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
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
        // El teclado se superpone en vez de encoger la pantalla: si no,
        // el menu inferior sube y queda pegado sobre las teclas.
        resizeToAvoidBottomInset: false,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        appBar: EncabezadoPrincipalWidget.subpantalla(
          titulo: 'Política de privacidad',
          alVolver: context.safePop,
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 20.0),
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                ),
              ),
            ),
            wrapWithModel(
              model: _model.menuBarModel,
              updateCallback: () => safeSetState(() {}),
              child: MenuBarWidget(
                index: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
