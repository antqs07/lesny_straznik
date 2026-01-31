import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Zmieniona nazwa interfejsu na pasującą do pliku
abstract class INetworkService {
  Stream<String> get alertStream;
  void connect();
  void disconnect();
}

class NetworkService implements INetworkService {
  // IP Bartka
  final String _baseUrl = "http://10.255.136.131/dzikcount";
  
  final _controller = StreamController<String>.broadcast();
  Timer? _pollingTimer;
  Timer? _alarmOffTimer;
  int _lastKnownCount = -1; 

  @override
  Stream<String> get alertStream => _controller.stream;

  @override
  void connect() {
    print("SIEC: Startuję system (NetworkService)...");
    
    // Pytamy serwer co 2 sekundy (bezpiecznie dla serwera Bartka)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        // Trick na cache (timestamp)
        String urlWithNoCache = "$_baseUrl?t=${DateTime.now().millisecondsSinceEpoch}";
        
        final response = await http.get(
          Uri.parse(urlWithNoCache),
          headers: {
            "Connection": "close", // Ważne: zamykamy połączenie po odebraniu danych
            "User-Agent": "FlutterApp"
          }
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          String rawBody = response.body.trim(); 
          int currentCount = 0;
          
          // --- PARSOWANIE HTML (Szukamy div class='count') ---
          RegExp htmlFinder = RegExp(r"<div class='count'>(\d+)</div>");
          Match? match = htmlFinder.firstMatch(rawBody);

          if (match != null) {
            String numberStr = match.group(1)!;
            currentCount = int.parse(numberStr);
          } else {
            // Fallback: próba parsowania jako zwykła liczba lub JSON
            if (int.tryParse(rawBody) != null) {
              currentCount = int.parse(rawBody);
            } else {
               try {
                  final json = jsonDecode(rawBody);
                  currentCount = json['count'] ?? 0;
               } catch (_) {}
            }
          }
          // ---------------------------------------------------

          // Logika Alarmu: Jeśli liczba wzrosła
          if (currentCount > _lastKnownCount && _lastKnownCount != -1) {
             print("ALARM! Wykryto zmianę na $currentCount.");
             _controller.add("ALERT");
             
             // Resetujemy timer wyłączający i ustawiamy nowy na 7 sekund
             _alarmOffTimer?.cancel();
             _alarmOffTimer = Timer(const Duration(seconds: 7), () {
               print("AUTO-OFF: Koniec alarmu po 7s.");
               _controller.add("CLEAR");
             });
             
          } else if (currentCount == 0) {
             _controller.add("CLEAR");
             _alarmOffTimer?.cancel();
          }
          
          _lastKnownCount = currentCount;
          
        }
      } catch (e) {
        // Cicha obsługa błędów, żeby nie spamować konsoli
        print("SIEC: Czekam na serwer..."); 
      }
    });
  }

  @override
  void disconnect() {
    _pollingTimer?.cancel();
    _alarmOffTimer?.cancel();
  }
}

// Mock (symulator) - zostawiamy na wszelki wypadek
class MockNetworkService implements INetworkService {
  final _controller = StreamController<String>.broadcast();
  @override
  Stream<String> get alertStream => _controller.stream;
  @override
  void connect() {}
  @override
  void disconnect() {}
}