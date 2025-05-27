import 'package:flutter/material.dart';
import 'package:applogin/app/app.dart';

void main() async {
  // Esto es necesario para usar plugins en la función main
  WidgetsFlutterBinding.ensureInitialized();
  
  // Solicitar permisos al inicio (para versiones anteriores a Android 10)
  
  runApp(const MyApp());
}