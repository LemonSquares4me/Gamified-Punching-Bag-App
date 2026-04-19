import 'package:flutter/material.dart';
import 'dart:math'; // Required for the gauge math
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data'; //Required for parsing bytes
import 'package:fl_chart/fl_chart.dart'; // NEW IMPORT

final ValueNotifier<double> liveForceNotifier = ValueNotifier<double>(0.0); //BLE broadcast channel
//final ValueNotifier<int> liveReactionTimeNotifier = ValueNotifier(0);
//final ValueNotifier<int> liveScoreNotifier = ValueNotifier(0);
final ValueNotifier<List<PunchRecord>> sessionHistoryNotifier = ValueNotifier<List<PunchRecord>>([]); // Global pipe for the session history list

// --- UPDATED: Theme Definitions ---

final ThemeData modernDarkTheme = ThemeData(
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.redAccent,
  scaffoldBackgroundColor: const Color(0xFF121212), 
  cardTheme: CardThemeData( // <--- Changed to CardThemeData
    color: const Color(0xFF1E1E1E),
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
  ),
  useMaterial3: true,
);

final ThemeData cleanLightTheme = ThemeData(
  brightness: Brightness.light,
  colorSchemeSeed: Colors.blueAccent,
  scaffoldBackgroundColor: const Color(0xFFF5F7FA), 
  cardTheme: CardThemeData( // <--- Changed to CardThemeData
    color: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  useMaterial3: true,
);

final ThemeData neonCyberpunkTheme = ThemeData(
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.cyanAccent,
  scaffoldBackgroundColor: Colors.black,
  cardTheme: CardThemeData( // <--- Changed to CardThemeData
    color: const Color(0xFF0D1117),
    elevation: 12,
    shadowColor: Colors.cyanAccent.withOpacity(0.5), 
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  useMaterial3: true,
);

// Global pipe for the active theme (Defaults to Modern Dark)
final ValueNotifier<ThemeData> themeNotifier = ValueNotifier<ThemeData>(modernDarkTheme);

class PunchRecord {
  final double force;
  final DateTime time;
  PunchRecord({required this.force, required this.time});
}

class SessionGraph extends StatelessWidget {
  const SessionGraph({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PunchRecord>>(
      valueListenable: sessionHistoryNotifier,
      builder: (context, historyList, child) {
        if (historyList.length < 2) {
          return const Center(
            child: Text("Need at least 2 punches to draw a graph.", 
              style: TextStyle(color: Colors.grey)),
          );
        }

        // 1. Prepare the Data (Reverse it for chronological left-to-right plotting)
        final chronologicalList = historyList.reversed.toList();
        
        // 2. Map the data into FlSpot coordinates (X: Punch Index, Y: Force)
        List<FlSpot> spots = [];
        for (int i = 0; i < chronologicalList.length; i++) {
          spots.add(FlSpot(i.toDouble(), chronologicalList[i].force));
        }

        // 3. Draw the Chart
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              // Chart formatting
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                // X-Axis (Punch Number)
                bottomTitles: AxisTitles(
                  axisNameWidget: Text("Punch Sequence", style: TextStyle(fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 5),
                ),
                // Y-Axis (Force)
                leftTitles: AxisTitles(
                  axisNameWidget: Text("Force (lbs)", style: TextStyle(fontWeight: FontWeight.bold)),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              minX: 0,
              minY: 0,
              maxY: 1000, // Match your gauge max
              
              // The Line itself
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true, // Makes it look like a smooth force wave
                  color: Colors.redAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true), // Shows a dot for each punch
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.redAccent.withOpacity(0.2), // The shaded area under the curve
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void main() {
  runApp(const PunchingBagApp());
}

class PunchingBagApp extends StatelessWidget {
  const PunchingBagApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the theme pipe
    return ValueListenableBuilder<ThemeData>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return MaterialApp(
          title: 'Punch Force Tracker',
          theme: currentTheme, // Apply the dynamic theme here
          home: const MainNavigation(),
          debugShowCheckedModeBanner: false, // Removes the red "DEBUG" banner for a cleaner look
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    BluetoothScreen(),
    SessionLogScreen(),
    SettingsScreen(),      // Index 3 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ippo Punch!'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Use IndexedStack to preserve the state of all tabs
      body: IndexedStack(
        alignment: Alignment.center, 
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.speed), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'Connect'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'), // NEW
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Required when you have 4 or more items
        selectedItemColor: Theme.of(context).colorScheme.primary, // Dynamically matches the theme!
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Screens ---

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  double _targetForce = 0.0;
  double _maxRecordedForce = 0.0; // NEW: Track the highest hit
  final double _maxForce = 1000.0; 
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 800), 
    );
    
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // NEW: Tell the dashboard to listen to the global BLE data pipe
    liveForceNotifier.addListener(_onLiveForceReceived);
  }

  @override
  void dispose() {
    // NEW: Clean up the listener when the screen is closed
    liveForceNotifier.removeListener(_onLiveForceReceived);
    _controller.dispose();
    super.dispose();
  }

  void _onLiveForceReceived() {
    double incomingForce = liveForceNotifier.value;
    
    // Ignore 0 values or tiny noise if needed
    if (incomingForce < 5.0) return; 

    setState(() {
      _targetForce = incomingForce;
      
      if (incomingForce > _maxRecordedForce) {
        _maxRecordedForce = incomingForce;
      }
      
      _animation = Tween<double>(
        begin: _animation.value, 
        end: _targetForce, 
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut), 
      );
    });

    _controller.forward(from: 0.0);
  }

  void _simulatePunch() {
    double newForce = 50.0 + _random.nextInt(850);
    
    // 1. Send to the gauge
    liveForceNotifier.value = newForce;

    // 2. Add to the history list
    // Make a copy of the current list, add the new punch to the top (index 0), and update the notifier
    final currentHistory = List<PunchRecord>.from(sessionHistoryNotifier.value);
    currentHistory.insert(0, PunchRecord(force: newForce, time: DateTime.now()));
    sessionHistoryNotifier.value = currentHistory;
  }
  // NEW: Reset the session
  void _resetSession() {
    sessionHistoryNotifier.value = [];
    setState(() {
      _maxRecordedForce = 0.0;
      _targetForce = 0.0;
      _animation = Tween<double>(begin: _animation.value, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    });
    _controller.forward(from: 0.0);
  }

@override
  Widget build(BuildContext context) {
    // NEW: Grab the current theme properties
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary; // Red, Blue, or Cyan depending on settings

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title text colored with the theme's primary color
        Text("PEAK IMPACT FORCE", style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, color: primaryColor)),
        const SizedBox(height: 20),
        
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(300, 150), 
              painter: GaugePainter(
                currentValue: _animation.value, 
                maxValue: _maxForce,
                maxRecordedValue: _maxRecordedForce,
                // NEW: Pass the dynamic colors to the gauge
                arcBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                needleColor: isDark ? Colors.white : Colors.black87,
                maxMarkerColor: primaryColor,
              ),
              child: SizedBox(
                width: 300,
                height: 160,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80), 
                    child: Text(
                      "${_animation.value.toInt()} lbs",
                      // Text color adapts to light/dark mode automatically
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Session Record text uses the theme's primary color
        Text(
          "SESSION RECORD: ${_maxRecordedForce.toInt()} lbs", 
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),

        const SizedBox(height: 40),
        
        ElevatedButton.icon(
          onPressed: _simulatePunch,
          icon: const Icon(Icons.flash_on),
          label: const Text("SIMULATE PUNCH"),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, // Button matches the theme
            foregroundColor: isDark && primaryColor == Colors.cyanAccent ? Colors.black : Colors.white, 
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
        ),
        
        TextButton.icon(
          onPressed: _resetSession, 
          icon: const Icon(Icons.refresh, size: 18), 
          label: const Text("Reset Session"),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        )
      ],
    );
  }
}


class GaugePainter extends CustomPainter {
  final double currentValue;
  final double maxValue;
  final double maxRecordedValue;
  
  // NEW: Dynamic theme colors
  final Color arcBackgroundColor;
  final Color needleColor;
  final Color maxMarkerColor;

  GaugePainter({
    required this.currentValue, 
    required this.maxValue,
    required this.maxRecordedValue,
    required this.arcBackgroundColor,
    required this.needleColor,
    required this.maxMarkerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    
    // Background Arc (Now uses the dynamic arcBackgroundColor)
    final bgPaint = Paint()
      ..color = arcBackgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    // NEW: Clamp the values so the gauge never draws past 100% (pi)
    double safeCurrentValue = min(currentValue, maxValue);
    double sweepAngle = (safeCurrentValue / maxValue) * 3.14159;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.14159, 3.14159, false, bgPaint);

    // Active Arc (We keep the Green->Yellow->Red gradient as it is standard for physical force)
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.green, Colors.yellow, Colors.red],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.14159, sweepAngle, false, activePaint);

    // Draw the Max Hold Marker (Now uses the theme's primary accent color)
    if (maxRecordedValue > 0) {
      // NEW: Clamp the max marker as well
      double safeMaxValue = min(maxRecordedValue, maxValue);
      double maxSweepAngle = (maxRecordedValue / maxValue) * 3.14159;
      double maxAngle = 3.14159 + maxSweepAngle;

      double innerRadius = radius + 12; 
      double outerRadius = radius + 25;

      double startX = center.dx + innerRadius * (maxAngle == 0 ? 1 : maxAngle == 3.14159 ? -1 : 0); // Simplified trig for dart math
      double startY = center.dy; // simplified
      

      startX = center.dx + innerRadius * cos(maxAngle);
      startY = center.dy + innerRadius * sin(maxAngle);
      double endX = center.dx + outerRadius * cos(maxAngle);
      double endY = center.dy + outerRadius * sin(maxAngle);

      final maxMarkerPaint = Paint()
        ..color = maxMarkerColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), maxMarkerPaint);
    }

    // Draw the Needle (Now uses the dynamic needleColor)
    double needleAngle = 3.14159 + sweepAngle;
    double needleLength = radius - 10;
    double needleX = center.dx + needleLength * cos(needleAngle);
    double needleY = center.dy + needleLength * sin(needleAngle);

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, Offset(needleX, needleY), needlePaint);
    canvas.drawCircle(center, 8, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; 
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Ask for permissions on load

    // Listen to the scan results stream
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    // Listen to the scanning state stream (true/false)
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        _isScanning = state;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  // 1. Request Android Permissions
  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // 2. Start / Stop Scanning
  void _toggleScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
    } else {
      // Clear old results and scan for 5 seconds
      setState(() => _scanResults.clear());
      await FlutterBluePlus.startScan(
        withServices: [Guid("4ae6f2be-e303-4a3a-9343-14f9338f1dc8")], //Adriano chosen UUID
        timeout: const Duration(seconds: 5)
      );
    }
  }

  // 3. Connect to Device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    // 1. Stop scanning once a device is selected to save battery
    await FlutterBluePlus.stopScan();

    // --- UI FEEDBACK (Connecting) ---
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to ${device.platformName.isNotEmpty ? device.platformName : "Device"}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // 2. Establish the connection
      await device.connect(autoConnect: false);
      print("Successfully connected to ${device.platformName}");

      // --- UI FEEDBACK (Success) ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully Connected!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 3. Discover what Services the MCU is broadcasting
      List<BluetoothService> services = await device.discoverServices();

      // 4. Search through the services to find your data characteristic
      for (BluetoothService service in services) {
        
        // (Note: filter by specific custom Service UUID)
        
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          
          // (Note: filter by specific Characteristic UUID)

          // 5. Check if this characteristic supports "Notify" (sending live updates)
          if (characteristic.properties.notify) {
            
            // Subscribe to the characteristic
            await characteristic.setNotifyValue(true);
            print("Subscribed to data stream!");
            
            // 6. Listen for incoming data packets from the MCU
            characteristic.onValueReceived.listen((List<int> value) {
              print("Incoming MCU Bytes: $value");
              
              // --- REVERTED: Ensure we received at least 2 bytes (Force) ---
              if (value.length >= 2) {
                // Convert the raw byte list into a ByteData object
                ByteData byteData = ByteData.view(Uint8List.fromList(value).buffer);
                
                // Parse the 16-bit integer using Little Endian
                int parsedForce = byteData.getUint16(0, Endian.little);
                
                print("Parsed Force: $parsedForce lbs");
                
                // Broadcast the new force to the rest of the app!
                liveForceNotifier.value = parsedForce.toDouble();
              }
            });
          }
        }
      }
    } catch (e) {
      print("Connection failed or was disconnected: $e");
      
      // --- UI FEEDBACK (Failed) ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          "AVAILABLE DEVICES", 
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 10),
        
        // --- SCAN BUTTON ---
        ElevatedButton.icon(
          onPressed: _toggleScan,
          icon: _isScanning 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Icon(Icons.search),
          label: Text(_isScanning ? "SCANNING..." : "SCAN FOR MCU"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isScanning ? Colors.grey : Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        ),
        
        const Divider(height: 30, thickness: 2),

        // --- LIST OF BLUETOOTH DEVICES ---
        Expanded(
          child: _scanResults.isEmpty
              ? const Center(child: Text("No devices found. Tap Scan.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    final device = result.device;
                    // Some devices don't broadcast a name, so we use "Unknown" as a fallback
                    final deviceName = device.platformName.isNotEmpty ? device.platformName : "Unknown Device";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth_audio, color: Colors.blueAccent),
                        title: Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(device.remoteId.str), // This is the MAC address
                        trailing: ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text("CONNECT"),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// --- SessionLogScreen ---

class SessionLogScreen extends StatelessWidget {
  const SessionLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("WORKOUT HISTORY", style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        
        // --- THE NEW GRAPH ---
        const SizedBox(
          height: 250, // Give the graph a fixed height
          width: double.infinity,
          child: SessionGraph(), 
        ),
        const Divider(height: 30, thickness: 2),
        
        // ValueListenableBuilder listens to our global list and rebuilds automatically
        Expanded(
          child: ValueListenableBuilder<List<PunchRecord>>(
            valueListenable: sessionHistoryNotifier,
            builder: (context, historyList, child) {
              
              // If the list is empty, show a friendly message
              if (historyList.isEmpty) {
                return const Center(
                  child: Text("No punches recorded yet. Start hitting!", 
                    style: TextStyle(color: Colors.grey, fontSize: 16)
                  )
                );
              }

              // Otherwise, build a scrolling list of the punches
              return ListView.builder(
                itemCount: historyList.length,
                itemBuilder: (context, index) {
                  final record = historyList[index];
                  
                  // Format the time to look like HH:MM:SS
                  String formattedTime = 
                      "${record.time.hour.toString().padLeft(2, '0')}:"
                      "${record.time.minute.toString().padLeft(2, '0')}:"
                      "${record.time.second.toString().padLeft(2, '0')}";

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    elevation: 2,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.sports_mma, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        "${record.force.toInt()} lbs", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      trailing: Text(
                        formattedTime, 
                        style: const TextStyle(color: Colors.grey)
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- NEW: Settings Screen ---

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("UI SETTINGS", style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          
          Card(
            child: ValueListenableBuilder<ThemeData>(
              valueListenable: themeNotifier,
              builder: (context, activeTheme, child) {
                return Column(
                  children: [
                    RadioListTile<ThemeData>(
                      title: const Text("Modern Dark (Default)"),
                      subtitle: const Text("High contrast, battery saving"),
                      activeColor: Colors.redAccent,
                      value: modernDarkTheme,
                      groupValue: activeTheme,
                      onChanged: (ThemeData? newTheme) {
                        if (newTheme != null) themeNotifier.value = newTheme;
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeData>(
                      title: const Text("Clean Light"),
                      subtitle: const Text("Crisp and clinical"),
                      activeColor: Colors.blueAccent,
                      value: cleanLightTheme,
                      groupValue: activeTheme,
                      onChanged: (ThemeData? newTheme) {
                        if (newTheme != null) themeNotifier.value = newTheme;
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeData>(
                      title: const Text("Neon Cyberpunk"),
                      subtitle: const Text("Glowing gaming aesthetic"),
                      activeColor: Colors.cyanAccent,
                      value: neonCyberpunkTheme,
                      groupValue: activeTheme,
                      onChanged: (ThemeData? newTheme) {
                        if (newTheme != null) themeNotifier.value = newTheme;
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}