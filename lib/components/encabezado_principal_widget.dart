import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/hulp_text_styles.dart';

class EncabezadoPrincipalWidget extends StatelessWidget
    implements PreferredSizeWidget {
  const EncabezadoPrincipalWidget({
    super.key,
    required this.titulo,
    this.accion,
  })  : mostrarVolver = false,
        volverHabilitado = false,
        alVolver = null,
        claveVolver = null;

  const EncabezadoPrincipalWidget.subpantalla({
    super.key,
    required this.titulo,
    this.accion,
    this.alVolver,
    this.claveVolver,
    this.volverHabilitado = true,
  }) : mostrarVolver = true;

  final String titulo;
  final Widget? accion;
  final bool mostrarVolver;
  final bool volverHabilitado;
  final VoidCallback? alVolver;
  final Key? claveVolver;

  static const colorTexto = Color(0xFF303332);
  static const _alto = 72.0;

  @override
  Size get preferredSize => const Size.fromHeight(_alto);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: mostrarVolver
          ? IconButton(
              key: claveVolver,
              icon: const BackButtonIcon(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: volverHabilitado
                  ? alVolver ?? () => Navigator.maybePop(context)
                  : null,
            )
          : null,
      centerTitle: true,
      toolbarHeight: _alto,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFFAF8F7),
      foregroundColor: colorTexto,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFDEDCDB)),
      ),
      title: Text(
        titulo,
        maxLines: MediaQuery.textScalerOf(context).scale(20) > 20 ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: HulpTextStyles.header.copyWith(
          color: titulo == 'Hulp' ? HulpColors.brand : colorTexto,
        ),
      ),
      actions: [
        if (accion != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: accion!,
          ),
      ],
    );
  }
}
