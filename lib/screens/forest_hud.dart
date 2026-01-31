import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import '../services/network_service.dart';

class ForestHUD extends StatefulWidget {
  final INetworkService service;
  const ForestHUD({super.key, required this.service});

  @override
  State<ForestHUD> createState() => _ForestHUDState();
}

class _ForestHUDState extends State<ForestHUD> with SingleTickerProviderStateMixin {
  bool _isSystemActive = false;
  bool _isDanger = false;
  int _soundMode = 2; 

  String _statusText = "SYSTEM OFF";
  String _lastUpdate = "--:--:--";
  
  final List<Map<String, dynamic>> _eventHistory = [];

  late AnimationController _animController;
  late Animation<double> _opacityAnim;
  final FlutterTts _tts = FlutterTts();
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _setupTts();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.3).animate(_animController);

    // Nasłuchiwanie prawdziwych danych z sieci
    widget.service.alertStream.listen((signal) {
      if (_isSystemActive) {
        _updateStatus(signal);
      }
    });
  }

  void _setupTts() async {
    await _tts.setLanguage("pl-PL");
  }

  // Główna funkcja zmieniająca stan ekranu (Zielony/Czerwony)
  void _updateStatus(String signal) async {
    if (!mounted) return;
    setState(() {
      final now = DateTime.now();
      String timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _lastUpdate = timeString;

      if (signal == "ALERT") {
        if (!_isDanger) {
           _isDanger = true;
           _statusText = "ZAGROŻENIE!";
           _animController.repeat(reverse: true);
           
           _addToHistory(
             "$timeString - Wykryto zagrożenie", 
             Icons.warning_amber_rounded, 
             Colors.redAccent
           );
           
           _startAlarmLoop(); 
        }
      } else {
        if (_isDanger) {
          _isDanger = false;
          _statusText = "DROGA WOLNA";
          _animController.reset();
          _stopAlarmLoop();
        }
      }
    });
  }

  // --- NOWA FUNKCJA: RĘCZNY WYZWALACZ ALARMU (PRO TIP NA PREZENTACJĘ) ---
  void _manualTrigger() {
    print("DEBUG: Uruchomiono tryb demonstracyjny (manualny alarm)!");
    
    // 1. Jeśli system jest wyłączony, włączamy go po cichu, żeby alarm zadziałał
    if (!_isSystemActive) {
      setState(() {
        _isSystemActive = true;
      });
    }

    // 2. Wymuszamy status ALERT
    _updateStatus("ALERT");

    // 3. Ustawiamy timer, żeby alarm sam zgasł po 7 sekundach
    Timer(const Duration(seconds: 7), () {
      if (mounted) {
        print("DEBUG: Koniec trybu demonstracyjnego.");
        _updateStatus("CLEAR");
      }
    });
  }
  // -----------------------------------------------------------------------

  void _addToHistory(String message, IconData icon, Color color) {
    _eventHistory.add({
      'message': message,
      'icon': icon,
      'color': color,
    }); 
    
    if (_eventHistory.length > 20) {
      _eventHistory.removeAt(0);
    }
  }

  void _showHistoryPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Dziennik Zdarzeń",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: _eventHistory.isEmpty
                    ? Center(child: Text("Brak zdarzeń", style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        itemCount: _eventHistory.length,
                        itemBuilder: (context, index) {
                          final event = _eventHistory[index];
                          return ListTile(
                            leading: Icon(event['icon'], color: event['color']),
                            title: Text(
                              event['message'],
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startAlarmLoop() async {
    if (_soundMode == 2) await _tts.speak("Uwaga! Zagrożenie!");
    _vibrationTimer?.cancel();
    if (_soundMode > 0) {
      _pulseVibration();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isDanger || !_isSystemActive) { timer.cancel(); return; }
        _pulseVibration();
      });
    }
  }

  void _pulseVibration() async {
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 500);
  }

  void _stopAlarmLoop() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    Vibration.cancel();
  }

  void _toggleSystem() {
    setState(() {
      final now = DateTime.now();
      String time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      _isSystemActive = !_isSystemActive;
      if (_isSystemActive) {
        widget.service.connect();
        _statusText = "SKANOWANIE...";
        _addToHistory("$time - System WŁĄCZONY", Icons.power_settings_new, Colors.tealAccent);
        if (_soundMode == 2) _tts.speak("System włączony");
      } else {
        widget.service.disconnect();
        _statusText = "SYSTEM OFF";
        _isDanger = false;
        _animController.reset();
        _stopAlarmLoop();
        _addToHistory("$time - System WYŁĄCZONY", Icons.power_off_outlined, Colors.grey);
        if (_soundMode == 2) _tts.speak("System wyłączony");
      }
    });
  }

  void _cycleSoundMode() {
    setState(() {
      if (_soundMode == 2) { _soundMode = 1; Vibration.vibrate(duration: 200); } 
      else if (_soundMode == 1) { _soundMode = 0; _stopAlarmLoop(); } 
      else { _soundMode = 2; _tts.speak("Głos włączony"); }
    });
  }

  IconData _getSoundIcon() {
    switch (_soundMode) { case 2: return Icons.volume_up; case 1: return Icons.vibration; default: return Icons.volume_off; }
  }
  Color _getSoundIconColor() {
     switch (_soundMode) { case 2: return Colors.tealAccent; case 1: return Colors.orangeAccent; default: return Colors.redAccent; }
  }

  @override
  void dispose() {
    _animController.dispose(); _tts.stop(); _vibrationTimer?.cancel(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color activeColor = _isDanger ? Colors.redAccent : Colors.tealAccent;
    Color displayColor = _isSystemActive ? activeColor : Colors.grey.shade800;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.grey.shade900, Colors.black],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- GÓRNY PASEK Z UKRYTYM PRZYCISKIEM ---
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // To jest Twój tajny przycisk:
                      GestureDetector(
                        onTap: _manualTrigger, // Kliknięcie wywołuje "Fałszywy Alarm"
                        child: const Icon(Icons.directions_car, color: Colors.grey),
                      ),
                      const Text("LEŚNY STRAŻNIK v2.7", style: TextStyle(color: Colors.grey, letterSpacing: 2)),
                      IconButton(
                        onPressed: _cycleSoundMode,
                        icon: Icon(_getSoundIcon(), color: _getSoundIconColor()),
                      ),
                    ],
                  ),
                ),
                // -----------------------------------------

                // ŚRODEK (HUD)
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _isDanger ? _opacityAnim : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: displayColor, width: 8),
                          boxShadow: _isSystemActive ? [BoxShadow(color: displayColor.withOpacity(0.5), blurRadius: 40, spreadRadius: 5)] : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isDanger ? Icons.warning_amber_rounded : Icons.security, size: 100, color: displayColor),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_statusText, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: displayColor, letterSpacing: 1.5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // DOLNY PANEL
                Container(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Text("Ostatnia aktualizacja: $_lastUpdate", style: TextStyle(color: Colors.grey.shade600, fontFamily: "Courier")),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _toggleSystem,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: _isSystemActive ? Colors.red.shade900 : Colors.teal.shade900,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Center(
                            child: Text(_isSystemActive ? "ZATRZYMAJ SYSTEM" : "AKTYWUJ OCHRONĘ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _showHistoryPanel,
                        icon: const Icon(Icons.history, color: Colors.grey),
                        label: const Text("DZIENNIK ZDARZEŃ", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}