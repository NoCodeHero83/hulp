import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/hulp_text_styles.dart';

import '/auth/base_auth_user_provider.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart'
    show HistorialWidget, HomePageWidget, LoginWidget, MiperfilWidget;

export 'menu_bar_model.dart';

const _textoMenu = Colors.white;

class MenuBarWidget extends StatelessWidget {
  const MenuBarWidget({
    super.key,
    required this.index,
    this.resaltarCuenta = false,
  });

  final int? index;
  final bool resaltarCuenta;

  void _abrir(BuildContext context, String ruta,
      {bool requiereSesion = false}) {
    final destino = requiereSesion && !loggedIn ? LoginWidget.routeName : ruta;
    if (ModalRoute.of(context)?.settings.name == destino) return;

    context.pushNamed(
      destino,
      extra: {
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(
            milliseconds: destino == LoginWidget.routeName ? 500 : 0,
          ),
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = resaltarCuenta ? 3 : index;
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
                texto: 'Inicio',
                icono: _iconoSvg('house'),
                activo: seleccionado == 0,
                onTap: () => _abrir(context, HomePageWidget.routeName),
              ),
              _destino(
                texto: 'Solicitudes',
                icono: Icon(
                  Icons.history_rounded,
                  size: 29,
                  color: _textoMenu,
                ),
                activo: seleccionado == 2,
                onTap: () => _abrir(context, HistorialWidget.routeName,
                    requiereSesion: true),
              ),
              _destino(
                texto: 'Cuenta',
                icono: _iconoSvg('user'),
                activo: seleccionado == 3,
                onTap: () => _abrir(context, MiperfilWidget.routeName,
                    requiereSesion: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconoSvg(String nombre) => SvgPicture.asset(
        'assets/images/$nombre.svg',
        width: 27,
        height: 27,
        colorFilter: const ColorFilter.mode(_textoMenu, BlendMode.srcIn),
      );

  Widget _destino({
    required String texto,
    required Widget icono,
    required bool activo,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Semantics(
          selected: activo,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                color: activo ? HulpColors.navigationSelectedOverlay : null,
                borderRadius: BorderRadius.circular(17),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icono,
                  const SizedBox(height: 2),
                  Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: HulpTextStyles.secondaryAction.copyWith(
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                      color: _textoMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
