class Usuario {
  final int id;
  final String nombre;
  final String telefono;
  final String rol;

  Usuario({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.rol,
  });

  factory Usuario.fromJson(Map<String, dynamic>json) {
    return Usuario(
      id: json['usuario_ID'],
      nombre: json['nombre'],
      telefono: json['telefono'],
      rol: json['rol'],
    );
  }

  Map<String, dynamic> toJson() => {
    'usuario_ID': id,
    'nombre': nombre,
    'telefono': telefono,
  };
}