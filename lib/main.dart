import 'package:flutter/material.dart';
import 'services/network_service.dart'; // Importujemy NetworkService
import 'screens/forest_hud.dart';         

void main() {
  // Wstrzykujemy NetworkService
  runApp(MyApp(networkService: NetworkService()));
}

class MyApp extends StatelessWidget {
  // Używamy nazwy networkService dla porządku
  final INetworkService networkService;
  
  const MyApp({super.key, required this.networkService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leśny Strażnik',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.redAccent,
        ),
      ),
      // Przekazujemy serwis do ekranu głównego
      home: ForestHUD(service: networkService),
    );
  }
}