import 'package:flutter/material.dart';
import 'package:applogin/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromARGB(255, 90, 64, 183);
    const textColor = Color(0xFF4A4A4A);
    const textHeaderColor = Color.fromARGB(255, 3, 3, 3);
    const backgroundColor = Color(0xFFF5F5F5);
    return MaterialApp(
      title: 'Productos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: textColor,
          displayColor: textHeaderColor,
          fontFamily: 'Inconsolata'
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(
              double.infinity,
              54,
            ), // Size
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)
            ), // RoundedRectangleBorder
            textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }

}

