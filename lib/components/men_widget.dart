import '/flutter_flow/hulp_text_styles.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'men_model.dart';
export 'men_model.dart';

class MenWidget extends StatefulWidget {
  const MenWidget({
    super.key,
    required this.index,
  });

  final int? index;

  @override
  State<MenWidget> createState() => _MenWidgetState();
}

class _MenWidgetState extends State<MenWidget> {
  late MenModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MenModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  void _abrir(String ruta) {
    context.pushNamed(
      ruta,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration.zero,
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HulpColors.brand,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            children: [
              _destino(
                texto: 'Solicitudes',
                icono: 'hand-withdraw',
                indice: 0,
                ruta: SolicitudesWidget.routeName,
              ),
              _destino(
                texto: widget.index == 1 ? 'Desempeño' : 'Datos',
                icono: 'chart-line-up',
                indice: 1,
                ruta: DesempenioPageWidget.routeName,
              ),
              _destino(
                texto: 'Soporte',
                icono: 'headset',
                indice: 2,
                ruta: SoporteWidget.routeName,
              ),
              _destino(
                texto: 'Cuenta',
                icono: 'user',
                indice: 3,
                ruta: MiperfilWidget.routeName,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _destino({
    required String texto,
    required String icono,
    required int indice,
    required String ruta,
  }) {
    final activo = widget.index == indice;
    return Expanded(
      child: Semantics(
        selected: activo,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _abrir(ruta),
          child: Ink(
            decoration: BoxDecoration(
              color: activo ? HulpColors.navigationSelectedOverlay : null,
              borderRadius: BorderRadius.circular(17),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/$icono.svg',
                  width: 27,
                  height: 27,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: HulpTextStyles.secondaryAction.copyWith(
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white,
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
