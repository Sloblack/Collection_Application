import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:recollection_application/core/config.dart';
import 'package:recollection_application/models/contenedor.dart';
import 'package:http/http.dart' as http;
import 'package:recollection_application/models/ruta.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {

  final Completer<GoogleMapController> _controller = Completer();
  int? rutaSeleccionadaId;
  List<Ruta> rutasDisponibles = [];
  List<Contenedor> contenedores = [];
  List<Ruta> _rutas = [];
  bool cargando = true;
  String? error;
  LatLng? _currentLocation;
  final LatLng _defaultLocation = LatLng(19.768711635621, -97.24471932875441);

  Set<Polyline> _polylines = {};
  bool _mostrandoRuta = false;
  bool _calculandoRuta = false;
  
  @override
  void initState(){
    super.initState();
    cargarContenedores();
    _getCurrentLocation();
    _updateCameraPosition();
  }


  Future<void> mostrarRutaOptima() async {
  setState(() {
    _calculandoRuta = true;
  });
  
  try {
    // Obtener los contenedores de la ruta seleccionada
    final contenedoresFiltrados = contenedores
        .where((c) => c.puntoRecoleccion?.ruta?.id == rutaSeleccionadaId)
        .toList();
    
    if (contenedoresFiltrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay contenedores en esta ruta'))
      );
      return;
    }
    
    // Punto de inicio (ubicación actual o primer contenedor)
    LatLng inicio = _currentLocation ?? contenedoresFiltrados[0].posicion;
    
    // Obtener la ruta óptima usando Directions API
    List<LatLng> puntosOrdenados = await _calcularRutaOptima(inicio, contenedoresFiltrados);
    
    // Crear una polilínea para la ruta
    _polylines.add(
      Polyline(
        polylineId: PolylineId('ruta_optima'),
        points: puntosOrdenados,
        color: Colors.blue,
        width: 5,
      )
    );
    
    setState(() {
      _mostrandoRuta = true;
      _calculandoRuta = false;
    });
    
    // Ajustar la cámara para mostrar toda la ruta
    _ajustarCamaraParaRuta(puntosOrdenados);
    
  } catch (e) {
    setState(() {
      _calculandoRuta = false;
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al calcular la ruta: $e'))
    );
  }
}

Future<List<LatLng>> _calcularRutaOptima(LatLng inicio, List<Contenedor> contenedores) async {
  try {
    // Necesitas una API key para Google Directions
    final apiKey = 'AIzaSyC0uhoLZk649N6IDans-HZnZgZ5mmpNa8k'; // Reemplaza con tu API key
    
    // Preparar los waypoints
    List<String> waypoints = contenedores
        .map((c) => '${c.posicion.latitude},${c.posicion.longitude}')
        .toList();
    
    final String origDestParam = '${inicio.latitude},${inicio.longitude}';
    final String waypointsParam = waypoints.join('|');
    
    final Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=$origDestParam'
      '&destination=$origDestParam'
      '&waypoints=optimize:true|$waypointsParam'
      '&key=$apiKey'
    );
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['status'] == 'OK') {
        List<LatLng> puntos = [];
        
        // Extraer los puntos de la ruta
        final routes = data['routes'][0];
        final legs = routes['legs'];
        
        for (var leg in legs) {
          final steps = leg['steps'];
          for (var step in steps) {
            final polyline = step['polyline']['points'];
            puntos.addAll(_decodePoly(polyline));
          }
        }
        
        return puntos;
      } else {
        throw Exception('Error en Directions API: ${data['status']}');
      }
    } else {
      throw Exception('Error de red: ${response.statusCode}');
    }
  } catch (e) {
    // Si falla la API, usar una implementación sencilla conectando puntos directamente
    List<LatLng> rutaDirecta = [inicio];
    rutaDirecta.addAll(contenedores.map((c) => c.posicion));
    return rutaDirecta;
  }
}

// Decodificar el formato polyline de Google
List<LatLng> _decodePoly(String encoded) {
  List<LatLng> poly = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    double latDouble = lat / 1E5;
    double lngDouble = lng / 1E5;
    
    poly.add(LatLng(latDouble, lngDouble));
  }

  return poly;
}

Future<void> _ajustarCamaraParaRuta(List<LatLng> puntos) async {
  if (puntos.isEmpty) return;
  
  double minLat = puntos[0].latitude;
  double maxLat = puntos[0].latitude;
  double minLng = puntos[0].longitude;
  double maxLng = puntos[0].longitude;
  
  for (var punto in puntos) {
    if (punto.latitude < minLat) minLat = punto.latitude;
    if (punto.latitude > maxLat) maxLat = punto.latitude;
    if (punto.longitude < minLng) minLng = punto.longitude;
    if (punto.longitude > maxLng) maxLng = punto.longitude;
  }
  
  final GoogleMapController controller = await _controller.future;
  controller.animateCamera(
    CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      50.0, // padding
    ),
  );
}

Widget _construirBotonRuta() {
  return FloatingActionButton.extended(
    onPressed: _mostrandoRuta
      ? () {
          setState(() {
            _polylines.clear();
            _mostrandoRuta = false;
          });
        }
      : mostrarRutaOptima,
    backgroundColor: _mostrandoRuta ? Colors.red : Theme.of(context).scaffoldBackgroundColor,
    label: Text(_mostrandoRuta ? 'Ocultar ruta' : 'Mostrar ruta'),
    icon: Icon(_mostrandoRuta ? Icons.close : Icons.directions),
  );
}


  Future<List<Ruta>> cargarRutas() async {

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('userId');

      if (id == null || id.isEmpty) {
        throw Exception('ID de usuario no disponible');
      }
    
      final String baseUrl = AppConfig.baseUrl;
      final response = await http.get(Uri.parse('$baseUrl/usuarios/$id/rutas'));
      if(response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        return responseData
          .map((json) => Ruta.fromJson(json)).toList();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        error = 'Los servicios de ubicación están desactivados.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          error = 'Los permisos de ubicación fueron denegados';
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        error = 'Los permisos de ubicación están permanentemente denegados, no podemos solicitar permisos.';
      });
      return;
    }

    try {
      // ignore: deprecated_member_use
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _updateCameraPosition();
    } catch (e) {
      "Error obteniendo la ubicación: $e";
    }
  }

  Future<void> _updateCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    final LatLng target = _currentLocation ?? (_rutas.isNotEmpty ? contenedores[0].posicion : _defaultLocation);
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }


  Future<void> cargarContenedores() async {
    try {
    final response = await http.get(Uri.parse('${AppConfig.baseUrl}/contenedores'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final contenedoresCargados = data.map((json) => Contenedor.fromJson(json)).toList();

      _rutas = await cargarRutas();

      setState(() {
        contenedores = contenedoresCargados;
        rutasDisponibles = _rutas;
        rutaSeleccionadaId = _rutas.isNotEmpty ? _rutas[0].id : null;
        cargando = false;
      });

      if (contenedores.isNotEmpty) {
        _moverCamaraALocalizacion();
      }
    } else {
      setState(() {
        error = 'Error al cargar datos: ${response.statusCode}';
        cargando = false;
      });
    }
  } catch (e) {
    setState(() {
      error = 'Error de conexión: $e';
      cargando = false;
    });
  }
  }

  Future<void> _moverCamaraALocalizacion() async{
    if (contenedores.isEmpty || rutaSeleccionadaId == null) return;

  final contenedoresFiltrados = contenedores
      .where((c) => c.puntoRecoleccion?.ruta?.id == rutaSeleccionadaId)
      .toList();

  if (contenedoresFiltrados.isEmpty) return;

  final GoogleMapController controller = await _controller.future;
  controller.animateCamera(CameraUpdate.newLatLngZoom(
    contenedoresFiltrados[0].posicion, 14.0)
  );
  }

  Set<Marker> _createMarcadores() {
    Set<Marker> markers = {};
    
    // Añadir marcadores de contenedores
    final filtrados = contenedores
        .where((c) => c.puntoRecoleccion?.ruta?.id == rutaSeleccionadaId)
        .toList();

    markers.addAll(filtrados.map((contenedor) {
      return Marker(
        markerId: MarkerId('contenedor_${contenedor.contenedorId}'),
        position: contenedor.posicion,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          contenedor.estadoRecoleccion ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
        ),
        infoWindow: InfoWindow(
          title: 'Contenedor ${contenedor.contenedorId}',
          snippet: 'QR: ${contenedor.codigoQR}, Ruta: ${contenedor.puntoRecoleccion?.ruta?.nombre} ''Estado: ${contenedor.estadoRecoleccion ? "Recolectado" : "No recolectado"}',
        ),
      );
    }));

    // Añadir marcador de posición actual si está disponible
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: MarkerId('current_location'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Tu ubicación actual'),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final CameraPosition posicionInicial = CameraPosition(
      target: _currentLocation ?? (_rutas.isNotEmpty ? contenedores[0].posicion : _defaultLocation),
      zoom: 14.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Puntos de recolección'),
        actions: [
          if (_rutas.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<int>(
                value: rutaSeleccionadaId,
                onChanged: (int? newValue) {
                  setState(() {
                    rutaSeleccionadaId = newValue;
                    _polylines.clear(); // Limpiar rutas al cambiar
                    _mostrandoRuta = false;
                    _moverCamaraALocalizacion();
                  });
                },
                items: _rutas.map<DropdownMenuItem<int>>((Ruta ruta) {
                  return DropdownMenuItem<int>(
                    value: ruta.id,
                    child: Text(ruta.nombre, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
                dropdownColor: Theme.of(context).primaryColor,
                underline: Container(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: posicionInicial,
            markers: _createMarcadores(),
            polylines: _polylines, // Añadir las polilíneas
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_rutas.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No tienes rutas asignadas. Contacta a tu supervisor.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 80,
            left: 16,
            child: FloatingActionButton(
              onPressed: () {
                _getCurrentLocation();
                _updateCameraPosition();
              },
              mini: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: Icon(Icons.my_location),
            ),
          ),
          // Botón para mostrar/ocultar la ruta
          Positioned(
            bottom: 16,
            left: 16,
            child: _calculandoRuta
              ? CircularProgressIndicator()
              : _construirBotonRuta(),
          ),
        ],
      ),
    );
  }
}