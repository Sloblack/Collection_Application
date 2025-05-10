import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/punto_recoleccion.dart';

class Contenedor {
  final int contenedorId;
  final LatLng posicion;
  final String codigoQR;
  final String codigoNFC;
  final bool estadoRecoleccion;
  final DateTime ultimaActualizacion;
  final PuntoRecoleccion? puntoRecoleccion;
  
  Contenedor({
    required this.contenedorId,
    required this.posicion,
    required this.codigoQR,
    required this.codigoNFC,
    required this.estadoRecoleccion,
    required this.ultimaActualizacion,
    this.puntoRecoleccion,
  });

  factory Contenedor.fromJson(Map<String, dynamic> json) {
    final int id = json['id'] ?? json['contenedor_ID'];
    final String codigoQR = json['codigoQR'] ?? json['codigo_QR'];
    final String codigoNFC = json['codigoNFC'] ?? json['codigo_NFC'];
    
    final ubicationParts = json['ubicacion'].toString().split(' ');
    final double lat = double.parse(ubicationParts[0]);
    final double lng = double.parse(ubicationParts[1]);
    
    return Contenedor(
      contenedorId: id,
      posicion: LatLng(lat, lng),
      codigoQR: codigoQR,
      codigoNFC: codigoNFC,
      estadoRecoleccion: json['estadoRecoleccion'],
      ultimaActualizacion: DateTime.parse(json['ultima_actualizacion']),
      puntoRecoleccion: json['puntoRecoleccion'] != null ? PuntoRecoleccion.fromJson(json['puntoRecoleccion']): null,
    );
  }
}
