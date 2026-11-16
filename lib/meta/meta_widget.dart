import '/components/encabezado_principal_widget.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'meta_model.dart';
export 'meta_model.dart';

class MetaWidget extends StatefulWidget {
  const MetaWidget({super.key});

  static String routeName = 'meta';
  static String routePath = '/meta';

  @override
  State<MetaWidget> createState() => _MetaWidgetState();
}

class _MetaWidgetState extends State<MetaWidget> {
  late MetaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MetaModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.appVersions = await AppVersionTable().queryRows(
        queryFn: (q) => q,
      );
      await AppVersionTable().update(
        data: {
          'Meta': (_model.appVersions!.firstOrNull!.meta!) + 1,
        },
        matchingRows: (rows) => rows,
      );
      if (isiOS == true) {
        await launchURL(_model.appVersions!.firstOrNull!.urlUsuariosIOS!);
      } else {
        await launchURL(_model.appVersions!.firstOrNull!.urlUsuariosPlayStore!);
      }
    });

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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: EncabezadoPrincipalWidget.subpantalla(
          titulo: 'Meta',
          alVolver: context.safePop,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [],
          ),
        ),
      ),
    );
  }
}
