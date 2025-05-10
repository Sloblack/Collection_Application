import '../models/ruta.dart';

class PuntoRecoleccion {
  final int id;
  final Ruta? ruta;
  final int orden;

  PuntoRecoleccion({
    required this.id,
    required this.ruta,
    required this.orden,
  });

  factory PuntoRecoleccion.fromJson(Map<String, dynamic> json) {
    return PuntoRecoleccion(
      id: json['punto_ID'],
      orden: json['orden'],
      ruta: json['ruta'] != null ? Ruta.fromJson(json['ruta']) : null,

    );
  }
}