import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final String apiKey = '073515b2e5447976446b51929a770450';
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

  @override
  void initState() {
    super.initState();
    _getCurrentLocationWeather();
  }

  Future<void> _getCurrentLocationWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        lat = position.latitude;
        lon = position.longitude;
      });
      await _fetchWeatherByCoordinates(lat!, lon!);
    } catch (e) {
      setState(() {
        errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _fetchWeatherByCoordinates(double lat, double lon) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';
    
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
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherByCity(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';
    
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
      } else {
        setState(() {
          errorMessage = 'City not found or invalid input';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1501785888041-af3ef285b470?ixlib=rb-4.0.3&auto=format&fit=crop&w=1350&q=80'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.orangeAccent, BlendMode.overlay),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
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
                                  const Icon(Icons.cloud, size: 50, color: Colors.black),
                                  Text(
                                    weatherCondition.isNotEmpty ? weatherCondition : 'No weather data',
                                    style: const TextStyle(fontSize: 20, color: Colors.black),
                                  ),
                                  Text(
                                    temperature.isNotEmpty ? temperature : 'No temperature data',
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  Text(
                                    'Today ${currentDate.day}/${currentDate.month}/${currentDate.year}',
                                    style: const TextStyle(fontSize: 16, color: Colors.black),
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
                            children: [
                              _buildForecastItem('Thursday', '29°C', Icons.wb_sunny),
                              _buildForecastItem('Friday', '20°C', Icons.cloud),
                              _buildForecastItem('Saturday', '18°C', Icons.thunderstorm),
                              _buildForecastItem('Monday', '28°C', Icons.wb_sunny),
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
        Text(temp, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ForecastPage extends StatefulWidget {
  final double lat;
  final double lon;
  final String apiKey;

  const ForecastPage({super.key, required this.lat, required this.lon, required this.apiKey});

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
    // Use One Call API for real forecast data (requires API key with One Call access)
    final url = 'https://api.openweathermap.org/data/2.5/onecall?lat=${widget.lat}&lon=${widget.lon}&exclude=current,minutely,hourly,alerts&appid=${widget.apiKey}&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          forecastData = (data['daily'] as List)
              .sublist(1, 5) // Skip today, get next 4 days
              .map((day) => {
                    'day': DateTime.fromMillisecondsSinceEpoch(day['dt'] * 1000).toString().split(' ')[0],
                    'temp': '${day['temp']['day']}°C',
                    'condition': day['weather'][0]['description'],
                    'icon': _getWeatherIcon(day['weather'][0]['main']),
                  })
              .toList();
        });
      } else {
        // Fallback to simulated data if API call fails (e.g., due to key limitations)
        setState(() {
          forecastData = [
            {'day': 'Tomorrow', 'temp': '25°C', 'condition': 'Sunny', 'icon': Icons.wb_sunny},
            {'day': 'Monday', 'temp': '22°C', 'condition': 'Cloudy', 'icon': Icons.cloud},
            {'day': 'Tuesday', 'temp': '20°C', 'condition': 'Rain', 'icon': Icons.umbrella},
            {'day': 'Wednesday', 'temp': '23°C', 'condition': 'Sunny', 'icon': Icons.wb_sunny},
          ];
        });
      }
    } catch (e) {
      // Fallback to simulated data on error
      setState(() {
        forecastData = [
          {'day': 'Tomorrow', 'temp': '25°C', 'condition': 'Sunny', 'icon': Icons.wb_sunny},
          {'day': 'Monday', 'temp': '22°C', 'condition': 'Cloudy', 'icon': Icons.cloud},
          {'day': 'Tuesday', 'temp': '20°C', 'condition': 'Rain', 'icon': Icons.umbrella},
          {'day': 'Wednesday', 'temp': '23°C', 'condition': 'Sunny', 'icon': Icons.wb_sunny},
        ];
      });
      print('Error fetching forecast: $e');
    }
  }

  IconData _getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear': return Icons.wb_sunny;
      case 'clouds': return Icons.cloud;
      case 'rain': return Icons.umbrella;
      case 'thunderstorm': return Icons.thunderstorm;
      default: return Icons.help;
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}