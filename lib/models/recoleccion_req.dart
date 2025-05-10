class RecoleccionReq {
  final String metodoRecoleccion;
  final int usuarioId;
  final int contenedorId;

  RecoleccionReq({
    required this.metodoRecoleccion,
    required this.usuarioId,
    required this.contenedorId,
  });

  Map<String, dynamic> toJson() => {
    'metodo_recoleccion': metodoRecoleccion,
    'usuario_ID': usuarioId,
    'contenedor_ID': contenedorId,
  };
}