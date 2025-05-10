import 'package:recollection_application/models/contenedor.dart';
import 'package:recollection_application/models/usuario.dart';

class RecoleccionModel {
  final int id;
  final DateTime fechaRecoleccion;
  final String metodoRecoleccion;
  final Usuario usuario;
  final Contenedor contenedor;

  RecoleccionModel({
    required this.id,
    required this.fechaRecoleccion,
    required this.metodoRecoleccion,
    required this.usuario,
    required this.contenedor,
  });

  factory RecoleccionModel.fromJson(Map<String, dynamic> json) {
    return RecoleccionModel(
      id: json['recoleccion_ID'],
      fechaRecoleccion: DateTime.parse(json['fecha_recoleccion']),
      metodoRecoleccion: json['metodo_recoleccion'],
      usuario: Usuario.fromJson(json['usuario']),
      contenedor: Contenedor.fromJson(json['contenedor'])
    );
  }
}