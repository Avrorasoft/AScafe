// Nombre del archivo: salteceria_icons.dart (o integrado en tus utilidades)

import 'package:flutter/material.dart';

class SalteceriaIcons {
  // Salteña / Empanada estilizada con repulgue superior
  static const IconData saltena = Icons.bakery_dining;
  
  // Pollo (Especialidad)
  static const IconData pollo = Icons.fastfood;
  
  // Carne / Picante (Con indicador de intensidad)
  static const IconData picante = Icons.local_fire_department;
  
  // Dulce / Horno
  static const IconData dulce = Icons.cake;
  
  // Refresco / Mocochinchi / Soya (Vaso alto con sorbete)
  static const IconData refresco = Icons.local_drink;
  
  // API (Taza de api tradicional)
  static const IconData api = Icons.coffee;
}

// Widget visual corporativo para renderizar el icono realista vectorial
class IconoProductoRealista extends StatelessWidget {
  final String nombre;
  const IconoProductoRealista({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final String n = nombre.toLowerCase();
    Color colorGradiente1 = const Color(0xFFFFAB00);
    Color colorGradiente2 = const Color(0xFFD84315);
    IconData icono = Icons.bakery_dining;
    String badge = 'SALTEÑA';

    if (n.contains('pollo')) {
      colorGradiente1 = const Color(0xFFFFC107);
      colorGradiente2 = const Color(0xFFFF8F00);
      icono = Icons.fastfood;
      badge = 'POLLO';
    } else if (n.contains('carne')) {
      colorGradiente1 = const Color(0xFFFFAB00);
      colorGradiente2 = const Color(0xFFBF360C);
      icono = Icons.bakery_dining;
      badge = 'CARNE';
    } else if (n.contains('picante')) {
      colorGradiente1 = const Color(0xFFFF3D00);
      colorGradiente2 = const Color(0xFFB71C1C);
      icono = Icons.local_fire_department;
      badge = 'PICANTE';
    } else if (n.contains('dulce')) {
      colorGradiente1 = const Color(0xFFFF4081);
      colorGradiente2 = const Color(0xFF880E4F);
      icono = Icons.cake;
      badge = 'DULCE';
    } else if (n.contains('mocochinchi') || n.contains('refresco') || n.contains('soya')) {
      colorGradiente1 = const Color(0xFF00E5FF);
      colorGradiente2 = const Color(0xFF0D47A1);
      icono = Icons.local_bar;
      badge = 'BEBIDA';
    } else if (n.contains('api')) {
      colorGradiente1 = const Color(0xFFFFB74D);
      colorGradiente2 = const Color(0xFF4E342E);
      icono = Icons.coffee;
      badge = 'API';
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorGradiente1, colorGradiente2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colorGradiente2.withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icono, color: Colors.white, size: 30),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorGradiente1.withOpacity(0.5), width: 0.5),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}