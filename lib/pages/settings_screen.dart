import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recollection_application/pages/login_screen.dart';
import 'package:recollection_application/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // ignore: use_build_context_synchronously
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false);
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final baseUrl = AppConfig.baseUrl; // Asegúrate de obtener la URL base del backend
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId'); // Asegúrate de guardar el userId al iniciar sesión
    //final token = prefs.getString('token'); // Asegúrate de guardar el token al iniciar sesión

    if (userId == null){ //|| token == null) {
      throw Exception('No se encontró información de usuario');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/$userId/change-password'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        //'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, String>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Error al cambiar la contraseña: ${response.body}');
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña actual'),
                ),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Cambiar'),
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Las contraseñas no coinciden')),
                  );
                  return;
                }
                try {
                  final success = await changePassword(
                    oldPasswordController.text,
                    newPasswordController.text,
                  );
                  if (success) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contraseña cambiada exitosamente'),
                      backgroundColor: Colors.green,),
                    );
                  }
                } catch (e) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración',
          style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('PREFERENCIAS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Recibir notificaciones de la aplicación'),
                  value: notificationsEnabled,
                  onChanged: (value) => setState(() => notificationsEnabled = value),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Modo oscuro'),
                  subtitle: const Text('Activar el tema oscuro de la aplicación'),
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('CUENTA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.lock_outline,
                    color: Theme.of(context).colorScheme.primary),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showChangePasswordDialog();
                  },
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(Icons.help_outline,
                    color: Theme.of(context).colorScheme.primary),
                  title: const Text('Ayuda y soporte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _logout,
            ),
          ),
          // const SizedBox(height: 16),
          // Center(
          //   child: Text('v1.0.0',
          //     style: TextStyle(
          //       color: Colors.grey[400],
          //       fontSize: 12,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
