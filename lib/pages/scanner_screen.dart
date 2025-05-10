import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nfc_manager/nfc_manager.dart' as nfc_manager;
import 'package:recollection_application/core/config.dart';
import 'package:recollection_application/models/contenedor.dart';
import 'package:recollection_application/models/recoleccion_req.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import 'package:recollection_application/models/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  String _nfcStatus = 'NFC no iniciado';
  String _lastScannedQR = '';
  String _lastScannedNFC = '';
  bool _isNfcAvailable = false;
  bool _isNfcSessionActive = false;
  bool _botonesDesactivados = false;
  bool _enviandoDatos = false;
  StreamSubscription<NFCTag>? _nfcSubscription;
  Usuario? usuario;
  Contenedor? contenedor;
  bool isLoading = true;
  String? errorMessage;
  final baseUrl = AppConfig.baseUrl;
  bool _contenedorExiste = false;
  String metodo = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _loadUser();
  }

Future<Contenedor> _buscarContenedor(String codigo) async {
  final String baseUrl = AppConfig.baseUrl;

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/contenedores/$codigo/contenedor'),
    );

    if (response.statusCode == 200) {
      // Registrar la respuesta para depuración
      developer.log('Respuesta recibida: ${response.body}', name: 'ContainerSearch');
      
      // Decodificar la respuesta JSON
      final dynamic responseData = jsonDecode(response.body);
      
      // Verificar si el resultado es un objeto o una lista
      Map<String, dynamic> contenedorJson;
      
      if (responseData is List) {
        // Si es una lista, tomar el primer elemento
        if (responseData.isEmpty) {
          throw Exception('No se encontraron contenedores');
        }
        contenedorJson = responseData.first;
      } else if (responseData is Map<String, dynamic>) {
        // Si es un objeto único, usarlo directamente
        contenedorJson = responseData;
      } else {
        throw Exception('Formato de respuesta inesperado');
      }
      
      // Registrar el objeto que se va a procesar
      developer.log('Objeto a procesar: $contenedorJson', name: 'ContainerSearch');
      
      // Transformar los nombres de campos para que coincidan con la clase Contenedor
      final transformedJson = {
          'id': contenedorJson['contenedor_ID'],
          'ubicacion': contenedorJson['ubicacion'],
          'codigoQR': contenedorJson['codigo_QR'],
          'codigoNFC': contenedorJson['codigo_NFC'],
          'estadoRecoleccion': contenedorJson['estadoRecoleccion'],
          'ultima_actualizacion': contenedorJson['ultima_actualizacion'],
          'puntoRecoleccion': contenedorJson['puntoRecoleccion'],
        };
      
      // Crear y devolver el objeto Contenedor
      return Contenedor.fromJson(transformedJson);
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    developer.log('Error al buscar contenedor: $e', name: 'ContainerSearch');
    rethrow;
  }
}

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

Future<bool> validarContenedorExistente() async {
  final String codigoValido = _lastScannedQR.isNotEmpty ? _lastScannedQR :
              (_lastScannedNFC.isNotEmpty ? _lastScannedNFC : '');
  
  if (codigoValido.isEmpty) {
    return false;
  }

  try {
    developer.log('Buscando contenedor con código: $codigoValido', name: 'ContainerSearch');
    contenedor = await _buscarContenedor(codigoValido);
    
    developer.log('Contenedor encontrado con ID: ${contenedor?.contenedorId}', name: 'ContainerSearch');
    
    // Si llegamos aquí, el contenedor existe
    if (mounted) {
      setState(() {
        _botonesDesactivados = true;
        _contenedorExiste = true;
      });
    }
    return true;
  } catch (e) {
    developer.log('Error al validar contenedor: $e', name: 'ContainerSearch');
    
    if (mounted) {
      setState(() {
        _contenedorExiste = false;
      });
      
      _showError('No se pudo validar el contenedor');
    }
    return false;
  }
}

Future<bool> _guardarRecoleccion({
  required String metodoRecoleccion,
  required int usuarioId,
  required int contenedorId,
}) async {
  setState(() {
    _enviandoDatos = true;
  });

  try {
    // Primero, registra la recolección
    final recoleccionRequest = RecoleccionReq(
      metodoRecoleccion: metodoRecoleccion,
      usuarioId: usuarioId,
      contenedorId: contenedorId,
    );

    final recoleccionResponse = await http.post(
      Uri.parse('$baseUrl/recolecciones'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(recoleccionRequest.toJson()),
    );

    if (recoleccionResponse.statusCode == 200 || recoleccionResponse.statusCode == 201) {
      // Si la recolección se registró con éxito, actualiza el estado del contenedor
      final actualizacionResponse = await http.patch(
        Uri.parse('$baseUrl/contenedores/$contenedorId/estado-recoleccion?estadoRecoleccion=true'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (actualizacionResponse.statusCode == 200) {
        _showSuccess('Recolección registrada y contenedor actualizado exitosamente');
        
        // Actualiza el estado del contenedor localmente
        if (mounted) {
          setState(() {
            contenedor = null;
            _botonesDesactivados = false;
            _enviandoDatos = false;
            _lastScannedQR = '';
            _lastScannedNFC = '';
            _contenedorExiste = false;
          });
        }
        return true;
      } else {
        _showError('Error al actualizar el estado del contenedor: Código ${actualizacionResponse.statusCode}');
        return false;
      }
    } else {
      _showError('Error al registrar la recolección: Código ${recoleccionResponse.statusCode}');
      return false;
    }

  } catch (e) {
    _showError('Error al procesar la recolección: ${e.toString()}');
    return false;
  } finally {
    if (mounted) {
      setState(() {
        _enviandoDatos = false;
      });
    }
  }
}

  @override
  void dispose() {
    developer.log('ScannerScreen dispose llamado', name: 'AppLifecycle');
    _stopNFCSession();
    WidgetsBinding.instance.removeObserver(this);
    _nfcSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('Estado del ciclo de vida: $state', name: 'AppLifecycle');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopNFCSession();
        break;
      case AppLifecycleState.resumed:
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _checkNfcAvailability();
          }
        });
        break;
      default:
        break;
    }
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _checkNfcAvailability();
  }

  Future<void> _requestPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El permiso de cámara es necesario para escanear QR'),
            ),
          );
        }
      }

    } catch (e) {
      _showError('Error al solicitar permisos: $e');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      // Usamos nfc_manager solo para verificar disponibilidad
      bool isAvailable = await nfc_manager.NfcManager.instance.isAvailable();
      
      if (mounted) {
        setState(() {
          _isNfcAvailable = isAvailable;
          _nfcStatus = isAvailable ? 'NFC disponible' : 'NFC no disponible';
        });
      }
    } catch (e) {
      _showError('Error al verificar NFC: $e');
    }
  }

  String decodeNDEFText (List<int> payload) {
    int langCodeLength = payload[0];
    List<int> textBytes = payload.sublist(1 + langCodeLength);
    return String.fromCharCodes(textBytes);
  }

  void _scanNFC() async {
    if (_isNfcSessionActive || !_isNfcAvailable || !mounted || _botonesDesactivados) return;

    try {
      setState(() {
        _nfcStatus = 'Escaneando NFC...';
        _isNfcSessionActive = true;
      });

      NFCTag tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 10));
      developer.log('NFC tag detectado: ${tag.id}', name: 'NFCScan');

      String data = 'ID de tarjeta: ${tag.id}';

      if (tag.ndefAvailable ?? false) {
        final records = await FlutterNfcKit.readNDEFRecords();
        if (records.isNotEmpty && records.first.payload != null) {
          final payload = records.first.payload!;
          data = decodeNDEFText(payload.toList());
        }
      }

      if (mounted) {
        setState(() {
          _lastScannedNFC = data;
          _nfcStatus = 'NFC disponible';
          metodo = 'NFC';
        });
        
        // Verificar si el contenedor existe después de escanear NFC
        _contenedorExiste = await validarContenedorExistente();
      }
    } catch (e) {
      developer.log('Error al escanear NFC: $e', name: 'NFCScan');
      if (mounted) {
        setState(() {
          _nfcStatus = 'Error: $e';
        });
      }
    } finally {
      _stopNFCSession();
    }
  }

  void _stopNFCSession() {
    if (!_isNfcSessionActive) return;

    developer.log('Deteniendo sesión NFC', name: 'NFCScan');
    
    try {
      _nfcSubscription?.cancel();
      FlutterNfcKit.finish().then((_) {
        developer.log('Sesión NFC finalizada con éxito', name: 'NFCScan');
      }).catchError((e) {
        developer.log('Error al finalizar sesión NFC: $e', name: 'NFCScan');
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _isNfcSessionActive = false;
            _nfcStatus = 'NFC disponible';
          });
        }
      });
    } catch (e) {
      developer.log('Excepción al detener NFC: $e', name: 'NFCScan');
      _isNfcSessionActive = false;
    }
  }

  void _navigateToQRScanner() async {
    if (!mounted || _botonesDesactivados) return;

    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const QRScannerPage()),
      );

      if (result != null && mounted) {
        setState(() {
          _lastScannedQR = result;
          metodo = 'QR';
        });
        
        // Verificar si el contenedor existe después de escanear QR
        _contenedorExiste = await validarContenedorExistente();
      }
    } catch (e) {
      _showError('Error en navegación: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUser() async {
    try {
      usuario = await _obtainUser();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al cargar el usuario: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<Usuario> _obtainUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    final id = prefs.getString('userId');
    final nombre = prefs.getString('nombre');
    final telefono = prefs.getString('telefono');
    final rol = prefs.getString('rol');

    if (id == null || nombre == null || telefono == null || rol == null) {
      throw Exception('Datos del usuario incompletos');
    }

    return Usuario(
      id: int.parse(id),
      nombre: nombre,
      telefono: telefono,
      rol: rol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR & NFC Scanner'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registro de recolecciones',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            if (_contenedorExiste && contenedor != null)
              _buildContenedorCard(theme, colors),
            const SizedBox(height: 24),
            _buildScannerCard(theme, colors),
            const SizedBox(height: 20),
            _buildNfcCard(theme, colors),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: (_contenedorExiste && usuario != null && contenedor != null && !_enviandoDatos)
                  ? () async {
                      await _guardarRecoleccion(
                        metodoRecoleccion: metodo,
                        usuarioId: usuario!.id,
                        contenedorId: contenedor!.contenedorId,
                      );
                    }
                  : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(120),
                  ),
                ),
                child: _enviandoDatos
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Enviando...')
                      ],
                    )
                  : const Text('Enviar datos'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContenedorCard(ThemeData theme, ColorScheme colors) {
    return Card(
      elevation: 2,
      // ignore: deprecated_member_use
      color: colors.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.primary, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: colors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Contenedor Encontrado',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('ID:', '${contenedor!.contenedorId}', theme),
        const SizedBox(height: 8),
        _buildInfoRow('QR:', contenedor!.codigoQR, theme),
        const SizedBox(height: 8),
        _buildInfoRow('NFC:', contenedor!.codigoNFC, theme),
        const SizedBox(height: 8),
        _buildInfoRow('Estado de Recolección:', contenedor!.estadoRecoleccion ? 'Recolectado' : 'No Recolectado', theme),
        const SizedBox(height: 8),
        _buildInfoRow('Última Actualización:', contenedor!.ultimaActualizacion.toString(), theme),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCard(ThemeData theme, ColorScheme colors) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code, color: colors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Escaneo de QR',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Estado:', _botonesDesactivados ? 'Contenedor detectado' : 'Listo para escanear', theme),
            const SizedBox(height: 8),
            //_buildInfoRow('Último QR:', _lastScannedQR, theme),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _botonesDesactivados ? null : _navigateToQRScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcCard(ThemeData theme, ColorScheme colors) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nfc, color: colors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Escaneo de NFC',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Estado:', _botonesDesactivados ? 'Contenedor detectado' : _nfcStatus, theme),
            const SizedBox(height: 8),
            //_buildInfoRow('Último NFC:', _lastScannedNFC, theme),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isNfcAvailable && !_botonesDesactivados) ? _scanNFC : null,
                icon: const Icon(Icons.credit_card),
                label: Text(_isNfcSessionActive ? 'Escaneando...' : 'Escanear NFC'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  late MobileScannerController controller;
  bool _isFlashOn = false;
  bool _isScannerActive = true;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
    WidgetsBinding.instance.addObserver(this);
    developer.log('QRScannerPage inicializada', name: 'AppLifecycle');
  }

  @override
  void dispose() {
    developer.log('QRScannerPage dispose llamado', name: 'AppLifecycle');
    _stopScanner();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('QRScanner - Estado del ciclo de vida: $state', name: 'AppLifecycle');
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isScannerActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _restartScanner();
            }
          });
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if (_isScannerActive) {
          _stopScanner();
        }
        break;
      default:
        break;
    }
  }

  void _stopScanner() {
    try {
      controller.stop();
      _isScannerActive = false;
      developer.log('Scanner detenido', name: 'QRScan');
    } catch (e) {
      developer.log('Error al detener scanner: $e', name: 'QRScan', error: e);
    }
  }

  void _restartScanner() {
    try {
      controller.start();
      _isScannerActive = true;
      developer.log('Scanner reiniciado', name: 'QRScan');
    } catch (e) {
      developer.log('Error al reiniciar scanner: $e', name: 'QRScan', error: e);
    }
  }

  void _toggleFlash() {
    try {
      controller.toggleTorch();
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar el flash: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _stopScanner();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escanear código QR'),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Alternar flash',
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                  final String code = barcodes[0].rawValue!;
                  developer.log('QR detectado: $code', name: 'QRScan');
                  _stopScanner();
                  Navigator.of(context).pop(code);
                }
              },
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Posiciona un código QR dentro del área',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              left: 20,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                )],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
