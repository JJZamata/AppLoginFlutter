import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';


class ApiService {
  static const String baseUrl = 'https://backendfiscamoto.onrender.com';
  static const secureStorage = FlutterSecureStorage();
  static const MethodChannel _channel = MethodChannel('com.example/device_info');

  static Future<Map<String, dynamic>> login(
    String username, 
    String password,
  ) async {
    final deviceInfo = await getDeviceInfo();
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'deviceInfo': {
          'deviceId': deviceInfo['deviceId'],
          'platform': deviceInfo['platform']
        },
      }),
    );
    
    final data = jsonDecode(response.body);
  
    if (response.statusCode == 200 && data['success'] == true) {
      if (data['data']['accessToken'] != null) {
        await secureStorage.write(key: 'auth_token', value: data['data']['accessToken']);
        await secureStorage.write(key: 'user_id', value: data['data']['id'].toString());
        await secureStorage.write(key: 'username', value: data['data']['username']);
        
        final roles = data['data']['roles'];
        if (roles != null) {
          await secureStorage.write(
            key: 'user_roles', 
            value: roles is List ? roles.join(',') : roles.toString()
          );
        }
      }
    }
    
    return data;
  }

 static Future<Map<String, dynamic>> getDeviceInfo() async {
  String platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web';
  String? deviceId;

  try {
    if (Platform.isAndroid) {
      // Intentar obtener Android ID nativo primero
      deviceId = await _getAndroidId();
      
      // Si falla, usar alternativas
      if (deviceId == null || deviceId.isEmpty) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        
        // Usar diferentes identificadores disponibles
        deviceId = androidInfo.id ?? // ID del dispositivo (desde Android 10)
                  androidInfo.fingerprint ?? // Huella digital de construcción
                  'android_${DateTime.now().millisecondsSinceEpoch}';
      }
    } 
    else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
    }
    else {
      deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    print('📱 Device Info - Platform: $platform, ID: $deviceId');
    return {
      'deviceId': deviceId,
      'platform': platform
    };
  } catch (e) {
    print('❌ Error getting device info: $e');
    return {
      'deviceId': 'error_${DateTime.now().millisecondsSinceEpoch}',
      'platform': platform
    };
  }
}

  static Future<String?> _getAndroidId() async {
    try {
      final String? androidId = await _channel.invokeMethod('getAndroidId');
      print('Obtained Android ID: $androidId');
      return androidId;
    } on PlatformException catch (e) {
      print('Failed to get Android ID: ${e.message}');
      return null;
    }
  }

  static Future<void> logout() async {
    final token = await secureStorage.read(key: 'auth_token');
    
    if (token != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/auth/signout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'clientType': 'mobile',
          }),
        );
        
        // Regardless of the response, we'll clear the stored credentials
        await secureStorage.deleteAll();
        
      } catch (e) {
        // If the request fails, still clear the credentials
        await secureStorage.deleteAll();
        rethrow;
      }
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _checkForStoredCredentials();
    _requestRequiredPermissions();
  }

  Future<void> _requestRequiredPermissions() async {
  if (Platform.isAndroid) {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    
    // Solo solicitar permiso en versiones anteriores a Android 10
    if (androidInfo.version.sdkInt < 29) {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        print('✅ Permiso READ_PHONE_STATE concedido');
      } else {
        print('⚠️ Permiso READ_PHONE_STATE denegado');
      }
    }
  }
}

  Future<void> _checkForStoredCredentials() async {
    final username = await ApiService.secureStorage.read(key: 'username');
    final token = await ApiService.secureStorage.read(key: 'auth_token');
    
    if (username != null && token != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen(username: username)),
      );
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await ApiService.login(
          _usernameController.text,
          _passwordController.text,
        );

        if (mounted) {
          setState(() => _isLoading = false);

          if (result['success'] == true) {
            final username = result['data']['username'];
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen(username: username)),
            );
          } else {
            setState(() {
              _errorMessage = result['message'] ?? 'Error de autenticación';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error de conexión: ${e.toString()}';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Fiscamoto'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              
              Icon(
                Icons.account_circle,
                size: 80,
                color: Colors.blue.shade700,
              ),
              
              const SizedBox(height: 30),
              
              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su nombre de usuario';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su contraseña';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              if (_errorMessage != null) const SizedBox(height: 16),
              
              // Login button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'INICIAR SESIÓN',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class HomeScreen extends StatelessWidget {
  final String username;
  
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Fiscamoto'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              '¡Bienvenido, $username!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Has iniciado sesión exitosamente',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ApiService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al cerrar sesión: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('CERRAR SESIÓN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}