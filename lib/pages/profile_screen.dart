import 'package:flutter/material.dart';
import 'package:recollection_application/models/usuario.dart';
import 'package:recollection_application/pages/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  Usuario? usuario;
  bool isLoading = true;
  String? errorMessage;


  @override
  void initState() {
    super.initState();
    _loadUser();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: Icon(Icons.person, size: 60,
                      color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(usuario != null ? usuario!.nombre : 'No hay',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 32),
            _ProfileInfoCard(
              icon: Icons.phone,
              title: 'Teléfono',
              value: usuario != null ? usuario!.telefono : 'No hay',
              context: context,
            ),
            const SizedBox(height: 16),
            _ProfileInfoCard(
              icon: Icons.recycling_outlined,
              title: 'Rol de usuario',
              value: usuario != null ? usuario!.rol.toUpperCase() : 'No hay',
              context: context,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Configuración',
                  style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final BuildContext context;

  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 28,
              color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}