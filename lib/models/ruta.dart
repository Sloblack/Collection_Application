class Ruta{
  int id;
  String nombre;
  String descripcion;
  DateTime fechaCreacion;

  Ruta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaCreacion,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    return Ruta(
      id: json['ruta_ID'],
      nombre: json['nombre_ruta'],
      descripcion: json['descripcion'],
      fechaCreacion: DateTime.parse(json['fecha_creacion']),
    );
  }
}