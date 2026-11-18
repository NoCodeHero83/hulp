import 'package:flutter/material.dart';
import '/flutter_flow/hulp_colors.dart';
import '/flutter_flow/hulp_text_styles.dart';

const direccionVerde = HulpColors.brand;
const direccionSeleccionada = HulpColors.brandSoft;
const direccionSuperficie = HulpColors.inputSurface;
const direccionBorde = HulpColors.border;
const direccionGris = HulpTextStyles.muted;

TextStyle textoDireccion(
        {double size = 14,
        FontWeight weight = FontWeight.w400,
        Color color = HulpColors.textPrimary}) =>
    HulpTextStyles.inter(size, weight: weight, color: color);

IconData iconoDireccion(String tipo) => switch (tipo) {
      'casa' => Icons.home_outlined,
      'oficina' => Icons.work_outline,
      _ => Icons.more_horiz,
    };

ButtonStyle botonDireccion({bool contorno = false}) => ElevatedButton.styleFrom(
      backgroundColor: contorno ? Colors.white : direccionVerde,
      foregroundColor: contorno ? direccionVerde : Colors.white,
      disabledBackgroundColor: direccionVerde.withValues(alpha: .45),
      disabledForegroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: contorno
          ? HulpTextStyles.secondaryAction
          : HulpTextStyles.primaryAction,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: contorno
            ? const BorderSide(color: direccionVerde)
            : BorderSide.none,
      ),
    );

InputDecoration inputDireccion(String hint,
        {IconData? icono, double radio = 12}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: textoDireccion(color: direccionGris),
      filled: true,
      fillColor: direccionSuperficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIcon:
          icono == null ? null : Icon(icono, size: 22),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: direccionBorde)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: direccionBorde)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: direccionVerde, width: 1.5)),
    );
