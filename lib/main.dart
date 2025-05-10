import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'pages/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:recollection_application/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      'Error a nivel de plataforma: $error',
      name: 'GlobalError',
      error: error,
      stackTrace: stack
    );
    // Devolver true indica que el error ha sido manejado
    return true;
  };

  // Configuración para preservar el estado de la app
  SystemChannels.lifecycle.setMessageHandler((msg) async {
    developer.log('Evento de ciclo de vida a nivel de sistema: $msg', name: 'AppLifecycle');
    return null;
  });
  
  // Manejar errores no capturados
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log(
      'Error no capturado: ${details.exception}',
      name: 'GlobalError',
      error: details.exception,
      stackTrace: details.stack
    );
    FlutterError.presentError(details);
  };
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Recollection App',
          theme: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const WelcomeScreen(),
          // Manejo global de errores en la navegación
          navigatorObservers: [
            _NavigatorObserver(),
          ],
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// Observer personalizado para registrar eventos de navegación
class _NavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    developer.log(
      'Navegación: Push a ${route.settings.name}',
      name: 'Navigation'
    );
    super.didPush(route, previousRoute);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    developer.log(
      'Navegación: Pop desde ${route.settings.name}',
      name: 'Navigation'
    );
    super.didPop(route, previousRoute);
  }
}