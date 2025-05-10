import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:recollection_application/core/config.dart';
import 'package:recollection_application/models/recoleccion_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<RecoleccionModel>> _recoleccionesFuture;
  
  @override
  void initState() {
    super.initState();
    _recoleccionesFuture = _fetchRecolecciones();
  }
  
  Future<List<RecoleccionModel>> _fetchRecolecciones() async {

    final prefs = await SharedPreferences.getInstance();
    final idUser = prefs.getString('userId');

    final String baseUrl = AppConfig.baseUrl;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/$idUser/recolecciones'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        List<RecoleccionModel> recolecciones = responseData
          .map((json) => RecoleccionModel.fromJson(json))
          .toList();
        recolecciones.sort((a, b) => b.id.compareTo(a.id));
        return recolecciones;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Recolecciones'),
      ),
      body: FutureBuilder<List<RecoleccionModel>>(
        future: _recoleccionesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay registros de recolección'));
          }
          
          final recolecciones = snapshot.data!;
          return ListView.builder(
            itemCount: recolecciones.length,
            itemBuilder: (context, index) {
              final recoleccion = recolecciones[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ExpansionTile(
                  leading: Icon(
                    recoleccion.metodoRecoleccion == "QR"
                        ? Icons.qr_code
                        : Icons.nfc,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                  title: Text(
                    'Recolección ${
                      recoleccion.fechaRecoleccion.day.toString().padLeft(2, '0')}/${
                        recoleccion.fechaRecoleccion.month.toString().padLeft(2, '0')}/${
                          recoleccion.fechaRecoleccion.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${
                    recoleccion.fechaRecoleccion.hour.toString().padLeft(2, '0')}:${
                      recoleccion.fechaRecoleccion.minute.toString().padLeft(2, '0')}:${
                        recoleccion.fechaRecoleccion.second.toString().padLeft(2, '0')
                        } - ${recoleccion.metodoRecoleccion}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoSection('Recolector', [
                            'Nombre: ${recoleccion.usuario.nombre}',
                            'Teléfono: ${recoleccion.usuario.telefono}',
                          ]),
                          const SizedBox(height: 12),
                          _buildInfoSection('Contenedor', [
                            'ID: ${recoleccion.contenedor.contenedorId}',
                            'Código: ${recoleccion.contenedor.codigoQR}',
                            'NFC: ${recoleccion.contenedor.codigoNFC}',
                          ]),
                          const SizedBox(height: 12),
                          _buildInfoSection('Ruta', [
                            'Nombre: ${recoleccion.contenedor.puntoRecoleccion?.ruta?.nombre}',
                            'Punto de Recolección: ${recoleccion.contenedor.puntoRecoleccion?.id}',
                          ]),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Aquí se podría implementar la navegación a un detalle completo
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ver detalles completos')),
                                );
                              },
                              child: const Text('Ver detalles'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Text(item),
        )),
      ],
    );
  }
}