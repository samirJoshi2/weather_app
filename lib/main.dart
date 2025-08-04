import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'firebase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCAaZbJKXIM8VLsjOEPoIAZlA0jAMmSiwM",
        authDomain: "fire-setup-fb30f.firebaseapp.com",
        projectId: "fire-setup-fb30f",
        storageBucket: "fire-setup-fb30f.firebasestorage.app",
        messagingSenderId: "701050103767",
        appId: "1:701050103767:web:99cfea810c14dcd3a34d92",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const WeatherHomePage();
          }
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/weather': (context) => const WeatherHomePage(),
      },
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final String apiKey = '073515b2e5447976446b51929a770450'; // Move to secure config in production
  final TextEditingController cityController = TextEditingController();
  String cityName = '';
  String temperature = '';
  String weatherCondition = '';
  String countryCode = '';
  String errorMessage = '';
  bool isLoading = false;
  DateTime currentDate = DateTime.now();
  double? lat;
  double? lon;
  List<Map<String, dynamic>> forecastData = [];
  final FirebaseAuthServices _authService = FirebaseAuthServices();

  @override
  void initState() {
    super.initState();
    _getCurrentLocationWeather();
  }

  Future<void> _getCurrentLocationWeather() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        errorMessage = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          errorMessage = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        errorMessage = 'Location permissions are permanently denied.';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        lat = position.latitude;
        lon = position.longitude;
      });
      await _fetchWeatherByCoordinates(lat!, lon!);
      await _fetchForecast();
    } catch (e) {
      setState(() {
        errorMessage = 'Error getting location: $e';
      });
      print('Location error: $e');
    }
  }

  Future<void> _fetchWeatherByCoordinates(double lat, double lon) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    const String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
    final String url = '$baseUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          cityName = data['name'];
          temperature = '${data['main']['temp']}°C';
          weatherCondition = data['weather'][0]['description'];
          countryCode = data['sys']['country'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to fetch weather data';
          isLoading = false;
        });
        print('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching weather: $e';
        isLoading = false;
      });
      print('Weather fetch error: $e');
    }
  }

  Future<void> _fetchWeatherByCity(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = 'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          cityName = data['name'];
          temperature = '${data['main']['temp']}°C';
          weatherCondition = data['weather'][0]['description'];
          countryCode = data['sys']['country'];
          lat = data['coord']['lat'];
          lon = data['coord']['lon'];
          isLoading = false;
        });
        await _fetchForecast();
      } else {
        setState(() {
          errorMessage = 'City not found or invalid input';
          isLoading = false;
        });
        print('Weather API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching weather: $e';
        isLoading = false;
      });
      print('Weather fetch error: $e');
    }
  }

  Future<void> _fetchForecast() async {
    if (lat == null || lon == null) return;

    final url = 'https://api.openweathermap.org/data/2.5/onecall?lat=$lat&lon=$lon&exclude=current,minutely,hourly,alerts&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          forecastData = (data['daily'] as List)
              .sublist(1, 5)
              .map(
                (day) => {
                  'day': DateTime.fromMillisecondsSinceEpoch(
                    day['dt'] * 1000,
                  ).toString().split(' ')[0],
                  'temp': '${day['temp']['day']}°C',
                  'condition': day['weather'][0]['description'],
                  'icon': _getWeatherIcon(day['weather'][0]['main']),
                },
              )
              .toList();
        });
      } else {
        setState(() {
          forecastData = [
            {
              'day': 'Tomorrow',
              'temp': '25°C',
              'condition': 'Sunny',
              'icon': Icons.wb_sunny,
            },
            {
              'day': 'Day 2',
              'temp': '22°C',
              'condition': 'Cloudy',
              'icon': Icons.cloud,
            },
            {
              'day': 'Day 3',
              'temp': '20°C',
              'condition': 'Rain',
              'icon': Icons.umbrella,
            },
            {
              'day': 'Day 4',
              'temp': '23°C',
              'condition': 'Sunny',
              'icon': Icons.wb_sunny,
            },
          ];
          errorMessage = 'Failed to fetch forecast data';
        });
        print('Forecast API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        forecastData = [
          {
            'day': 'Tomorrow',
            'temp': '25°C',
            'condition': 'Sunny',
            'icon': Icons.wb_sunny,
          },
          {
            'day': 'Day 2',
            'temp': '22°C',
            'condition': 'Cloudy',
            'icon': Icons.cloud,
          },
          {
            'day': 'Day 3',
            'temp': '20°C',
            'condition': 'Rain',
            'icon': Icons.umbrella,
          },
          {
            'day': 'Day 4',
            'temp': '23°C',
            'condition': 'Sunny',
            'icon': Icons.wb_sunny,
          },
        ];
        errorMessage = 'Error fetching forecast: $e';
      });
      print('Forecast fetch error: $e');
    }
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.umbrella;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.help;
    }
  }

  void _onSearchPressed() {
    final city = cityController.text.trim();
    if (city.isNotEmpty) {
      _fetchWeatherByCity(city);
    } else {
      setState(() {
        errorMessage = 'Please enter a city name';
      });
    }
  }

  void _navigateToForecast() {
    if (lat != null && lon != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForecastPage(lat: lat!, lon: lon!, apiKey: apiKey),
        ),
      );
    } else {
      setState(() {
        errorMessage = 'Location data not available';
      });
    }
  }

  void _logout() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      setState(() {
        errorMessage = 'Error signing out: $e';
      });
      print('Logout error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1501785888041-af3ef285b470?ixlib=rb-4.0.3&auto=format&fit=crop&w=1350&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.orangeAccent,
                  BlendMode.overlay,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: cityController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      hintText: 'Enter city name (e.g., London)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.black),
                    ),
                    onSubmitted: (_) => _onSearchPressed(),
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    )
                  else if (cityName.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            '$cityName, ${countryCode.isNotEmpty ? countryCode : 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Card(
                            color: Colors.orange.withOpacity(0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(
                                    _getWeatherIcon(weatherCondition),
                                    size: 50,
                                    color: Colors.black,
                                  ),
                                  Text(
                                    weatherCondition.isNotEmpty
                                        ? weatherCondition
                                        : 'No weather data',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    temperature.isNotEmpty
                                        ? temperature
                                        : 'No temperature data',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Today ${currentDate.day}/${currentDate.month}/${currentDate.year}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _navigateToForecast,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('DETAILS'),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Next 4 Days',
                            style: TextStyle(fontSize: 18, color: Colors.black),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: forecastData.isNotEmpty
                                ? forecastData.map((forecast) {
                                    return _buildForecastItem(
                                      forecast['day'],
                                      forecast['temp'],
                                      forecast['icon'],
                                    );
                                  }).toList()
                                : [
                                    _buildForecastItem(
                                      'Tomorrow',
                                      '25°C',
                                      Icons.wb_sunny,
                                    ),
                                    _buildForecastItem(
                                      'Day 2',
                                      '22°C',
                                      Icons.cloud,
                                    ),
                                    _buildForecastItem(
                                      'Day 3',
                                      '20°C',
                                      Icons.umbrella,
                                    ),
                                    _buildForecastItem(
                                      'Day 4',
                                      '23°C',
                                      Icons.wb_sunny,
                                    ),
                                  ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastItem(String day, String temp, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.black),
        const SizedBox(height: 5),
        Text(day, style: const TextStyle(color: Colors.black)),
        Text(
          temp,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ForecastPage extends StatefulWidget {
  final double lat;
  final double lon;
  final String apiKey;

  const ForecastPage({
    super.key,
    required this.lat,
    required this.lon,
    required this.apiKey,
  });

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  List<Map<String, dynamic>> forecastData = [];

  @override
  void initState() {
    super.initState();
    _fetchForecast();
  }

  Future<void> _fetchForecast() async {
    final url = 'https://api.openweathermap.org/data/2.5/onecall?lat=${widget.lat}&lon=${widget.lon}&exclude=current,minutely,hourly,alerts&appid=${widget.apiKey}&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          forecastData = (data['daily'] as List)
              .sublist(1, 5)
              .map(
                (day) => {
                  'day': DateTime.fromMillisecondsSinceEpoch(
                    day['dt'] * 1000,
                  ).toString().split(' ')[0],
                  'temp': '${day['temp']['day']}°C',
                  'condition': day['weather'][0]['description'],
                  'icon': _getWeatherIcon(day['weather'][0]['main']),
                },
              )
              .toList();
        });
      } else {
        setState(() {
          forecastData = [
            {
              'day': 'Tomorrow',
              'temp': '25°C',
              'condition': 'Sunny',
              'icon': Icons.wb_sunny,
            },
            {
              'day': 'Day 2',
              'temp': '22°C',
              'condition': 'Cloudy',
              'icon': Icons.cloud,
            },
            {
              'day': 'Day 3',
              'temp': '20°C',
              'condition': 'Rain',
              'icon': Icons.umbrella,
            },
            {
              'day': 'Day 4',
              'temp': '23°C',
              'condition': 'Sunny',
              'icon': Icons.wb_sunny,
            },
          ];
        });
        print('Forecast API error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        forecastData = [
          {
            'day': 'Tomorrow',
            'temp': '25°C',
            'condition': 'Sunny',
            'icon': Icons.wb_sunny,
          },
          {
            'day': 'Day 2',
            'temp': '22°C',
            'condition': 'Cloudy',
            'icon': Icons.cloud,
          },
          {
            'day': 'Day 3',
            'temp': '20°C',
            'condition': 'Rain',
            'icon': Icons.umbrella,
          },
          {
            'day': 'Day 4',
            'temp': '23°C',
            'condition': 'Sunny',
            'icon': Icons.wb_sunny,
          },
        ];
      });
      print('Error fetching forecast: $e');
    }
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.umbrella;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('4-Day Forecast'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: forecastData.length,
          itemBuilder: (context, index) {
            final forecast = forecastData[index];
            return Card(
              color: Colors.orange.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: Icon(forecast['icon'], size: 40, color: Colors.black),
                title: Text(
                  forecast['day'],
                  style: const TextStyle(color: Colors.black, fontSize: 20),
                ),
                subtitle: Text(
                  forecast['condition'],
                  style: const TextStyle(color: Colors.black),
                ),
                trailing: Text(
                  forecast['temp'],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}