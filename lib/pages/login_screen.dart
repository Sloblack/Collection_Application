import 'package:flutter/material.dart';
import 'package:recollection_application/auth/auth_service.dart';
import 'package:recollection_application/pages/main_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Clave para el formulario
  final _formKey = GlobalKey<FormState>();
  
  // Variables para mostrar/ocultar contraseña
  bool _obscureText = true;
  
  // Variable para mostrar el indicador de carga
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Función para manejar el inicio de sesión
  void _handleLogin() async{
    // Validar el formulario
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = AuthService();
        final result = await authService.login(
          _phoneController.text,
          _passwordController.text
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', result['accessToken']);
        await prefs.setString('userId', result['user']['id'].toString());
        await prefs.setString('nombre', result['user']['nombre']);
        await prefs.setString('telefono', result['user']['telefono']);
        await prefs.setString('rol', result['user']['rol']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Bienvenido ${result['user']['nombre']}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if(mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainWrapper())
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo o imagen (opcional)
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 48.0),
                
                // Campo de correo electrónico
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de teléfono',
                    hintText: 'Ingresa tu teléfono',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu numero de teléfono';
                    }
                    // Validación básica de formato de email
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                      return 'Ingresa un numero de telefono válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                
                // Campo de contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Ingresa tu contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),
                
                // Enlace "Olvidé mi contraseña"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Navegar a la página de recuperación de contraseña
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navegar a recuperación de contraseña'),
                        ),
                      );
                    },
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 24.0),
                
                // Botón de inicio de sesión
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,//() => Navigator.push(
                    //context, MaterialPageRoute(builder:(_) => MainWrapper())),//_isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'INICIAR SESIÓN',
                          style: TextStyle(fontSize: 16.0),
                        ),
                ),
                const SizedBox(height: 16.0),
                // Separador
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    //Expanded(child: Divider()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}