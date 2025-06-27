import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/search_service.dart';
import '../services/search_result.dart';
import 'dart:math';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<HourlyWeather> _hourlyWeather = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  String _lastUpdated = '';

  // Standard-Koordinaten (Schwarzenbach an der Saale)
  double _latitude = 50.16667;
  double _longitude = 11.9;
  String _currentLocation = 'Schwarzenbach an der Saale';

  // Für Ortssuche
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  List<SearchResult> _searchResults = [];
  // ignore: unused_field
  bool _isSearching = false;
  Timer? _searchTimer;

  int? _fireDangerLevel;
  String? _fireDangerText;
  Color? _fireDangerColor;

  String? _solarWarning;
  Color? _solarWarningColor;

  List<String> _weatherWarnings = []; // NEU
  Color _warningColor = Colors.red; // NEU

  String? _currentPostcode; // NEU

  @override
  void initState() {
    super.initState();
    _loadLastLocation();
    _fetchWeatherData();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _fetchWeatherData();
    });
  }

  Future<void> _searchLocation(String query) async {
    print('Suche: $query'); // Debug
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _doSearch(query);
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() {
      _isSearching = true;
    });
    final results = await _searchService.searchLocation(query);
    print('Suchergebnisse: $results');
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectLocation(SearchResult location) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _currentLocation = location.displayName;
      _currentPostcode = location.postcode; // NEU
      _searchResults = [];
      _searchController.clear();
    });
    _saveLastLocation();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$_latitude&longitude=$_longitude&hourly=temperature_2m,relative_humidity_2m,precipitation,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,shortwave_radiation&timezone=auto&forecast_days=2',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hourlyData = data['hourly'];

        final List<HourlyWeather> weatherList = [];
        final now = DateTime.now();

        // Zeige alle Stunden ab der aktuellen Stunde für die nächsten 24 Stunden
        int hoursAdded = 0;
        for (int i = 0; i < hourlyData['time'].length && hoursAdded < 24; i++) {
          final hour = DateTime.parse(hourlyData['time'][i]);

          // Zeige alle Stunden ab der aktuellen Stunde
          if (hour.isAfter(now.subtract(const Duration(minutes: 30)))) {
            weatherList.add(
              HourlyWeather(
                time: hour,
                temperature: hourlyData['temperature_2m'][i]?.toDouble() ?? 0.0,
                humidity: hourlyData['relative_humidity_2m'][i]?.toInt() ?? 0,
                precipitation:
                    hourlyData['precipitation'][i]?.toDouble() ?? 0.0,
                weatherCode: hourlyData['weather_code'][i]?.toInt() ?? 0,
                pressure: hourlyData['surface_pressure'][i]?.toDouble() ?? 0.0,
                windSpeed: hourlyData['wind_speed_10m'][i]?.toDouble() ?? 0.0,
                windDirection:
                    hourlyData['wind_direction_10m'][i]?.toInt() ?? 0,
                windGusts: hourlyData['wind_gusts_10m'][i]?.toDouble() ?? 0.0,
                solarRadiation:
                    hourlyData['shortwave_radiation']?[i]?.toDouble() ??
                    0.0, // NEU
              ),
            );
            hoursAdded++;
          }
        }

        setState(() {
          _hourlyWeather = weatherList;
          _isLoading = false;
        });

        // HIER DIE NEUEN METHODEN AUFRUFEN:
        await _fetchFireDangerDWD(); // oder _fetchFireDangerByCoordinates();
        await _fetchWeatherWarningsDWD();
        _checkSolarRadiation();
      } else {
        throw Exception('Fehler beim Laden der Wetterdaten');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Wetterdaten können aktuell nicht abgerufen werden.\nFehler: ${e.toString()}';
      });
    }
  }

  Future<void> _saveLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weather_latitude', _latitude);
    await prefs.setDouble('weather_longitude', _longitude);
    await prefs.setString('weather_location', _currentLocation);
    if (_currentPostcode != null) {
      await prefs.setString('weather_postcode', _currentPostcode!); // NEU
    }
  }

  Future<void> _loadLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('weather_latitude');
    final lon = prefs.getDouble('weather_longitude');
    final loc = prefs.getString('weather_location');
    final postcode = prefs.getString('weather_postcode'); // NEU
    if (lat != null && lon != null && loc != null) {
      setState(() {
        _latitude = lat;
        _longitude = lon;
        _currentLocation = loc;
        _currentPostcode = postcode; // NEU
      });
    }
  }

  Future<void> _fetchWeatherWarningsDWD() async {
    try {
      if (_currentPostcode == null) {
        setState(() {
          _weatherWarnings = [];
        });
        return;
      }

      // DWD Open Data - Warnungen
      final response = await http.get(
        Uri.parse(
          'https://opendata.dwd.de/weather/alerts/cap/COMMUNEUNION_DWD_STAT/Z_CAP_C_EDZW_LATEST_PVW_STATUS_PREMIUMDWD_COMMUNEUNION_DE.json',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List? ?? [];

        List<String> relevantWarnings = [];
        for (var feature in features) {
          final properties = feature['properties'];
          final headline = properties['headline']?.toString() ?? '';
          final areas = properties['area']?.toString() ?? '';

          // Prüfe ob Postleitzahl in den betroffenen Gebieten steht
          if (areas.contains(_currentPostcode!) && headline.isNotEmpty) {
            relevantWarnings.add(headline);
          }
        }

        setState(() {
          _weatherWarnings = relevantWarnings;
          _warningColor =
              relevantWarnings.isNotEmpty ? Colors.red : Colors.grey;
        });
      }
    } catch (e) {
      print('DWD Warnungen Fehler: $e');
      setState(() {
        _weatherWarnings = [];
      });
    }
  }

  Future<void> _fetchFireDangerDWD() async {
    try {
      if (_currentPostcode == null) {
        setState(() {
          _fireDangerLevel = 1;
          _fireDangerText = 'Waldbrandstufe: 1 (keine PLZ verfügbar)';
          _fireDangerColor = Colors.green;
        });
        return;
      }

      // Verwende die korrekte DWD-Waldbrandgefahren-API
      final response = await http.get(
        Uri.parse(
          'https://opendata.dwd.de/climate_environment/health/alerts/s31fg.json',
        ),
        headers: {'User-Agent': 'FireApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // Finde nächstgelegenen Rasterpunkt basierend auf Koordinaten
        double minDistance = double.infinity;
        int dangerLevel = 1;
        String locationInfo = '';

        if (data['features'] != null) {
          for (var feature in data['features']) {
            final geometry = feature['geometry'];
            final properties = feature['properties'];

            if (geometry != null && geometry['coordinates'] != null) {
              final coords = geometry['coordinates'];

              // Berechne Distanz zu aktueller Position
              double lat = 0, lon = 0;
              if (coords is List && coords.length >= 2) {
                lon = coords[0].toDouble();
                lat = coords[1].toDouble();
              }

              final distance = _calculateDistance(
                _latitude,
                _longitude,
                lat,
                lon,
              );

              if (distance < minDistance) {
                minDistance = distance;
                // Verschiedene mögliche Feldnamen für Waldbrandindex
                final wbi =
                    properties['WBI'] ??
                    properties['wbi'] ??
                    properties['Stufe'] ??
                    properties['stufe'] ??
                    properties['level'] ??
                    properties['index'];

                dangerLevel = int.tryParse(wbi?.toString() ?? '1') ?? 1;
                locationInfo = properties['name'] ?? properties['region'] ?? '';
              }
            }
          }
        }

        setState(() {
          _fireDangerLevel = dangerLevel;
          _fireDangerText =
              'Waldbrandstufe: $dangerLevel (${minDistance.toStringAsFixed(1)}km entfernt)';
          _fireDangerColor =
              [
                Colors.green, // Stufe 1
                Colors.yellow, // Stufe 2
                Colors.orange, // Stufe 3
                Colors.red, // Stufe 4
                Colors.deepOrange, // Stufe 5
              ][(dangerLevel - 1).clamp(0, 4)];
        });
      } else {
        throw Exception('DWD API Status: ${response.statusCode}');
      }
    } catch (e) {
      print('DWD Waldbrand Fehler: $e');

      // Fallback: Schätze anhand der Sonneneinstrahlung
      _estimateFireDangerFromWeather();
    }
  }

  Future<void> _fetchFireDangerByCoordinates() async {
    try {
      // Verwende Koordinaten für Waldbrandgefahrenschätzung
      // Basierend auf aktuellen Wetterdaten aus Open-Meteo
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$_latitude&longitude=$_longitude&daily=temperature_2m_max,temperature_2m_min,relative_humidity_2m,precipitation_sum,wind_speed_10m_max&timezone=auto&forecast_days=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daily = data['daily'];

        if (daily != null && daily['temperature_2m_max'] != null) {
          final maxTemp = daily['temperature_2m_max'][0]?.toDouble() ?? 15.0;
          final minHumidity =
              daily['relative_humidity_2m'][0]?.toDouble() ?? 70.0;
          final precipitation =
              daily['precipitation_sum'][0]?.toDouble() ?? 0.0;
          final maxWind = daily['wind_speed_10m_max'][0]?.toDouble() ?? 5.0;

          // Berechne Waldbrandgefahrenstufe nach vereinfachten Kriterien
          int level = 1;

          // Temperatur-Faktor
          if (maxTemp > 30)
            level += 2;
          else if (maxTemp > 25)
            level += 1;

          // Luftfeuchtigkeits-Faktor
          if (minHumidity < 30)
            level += 2;
          else if (minHumidity < 50)
            level += 1;

          // Niederschlags-Faktor (reduziert Gefahr)
          if (precipitation < 1.0)
            level += 1;
          else if (precipitation > 5.0)
            level -= 1;

          // Wind-Faktor
          if (maxWind > 25)
            level += 1;
          else if (maxWind > 15)
            level += 0; // kein Bonus

          level = level.clamp(1, 5);

          setState(() {
            _fireDangerLevel = level;
            _fireDangerText =
                'Waldbrandstufe: $level (berechnet: ${maxTemp.toStringAsFixed(0)}°C, ${minHumidity.toStringAsFixed(0)}% Feuchte)';
            _fireDangerColor =
                [
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                  Colors.deepOrange,
                ][(level - 1).clamp(0, 4)];
          });
        } else {
          throw Exception('Unvollständige Wetterdaten');
        }
      } else {
        throw Exception('Open-Meteo API Fehler');
      }
    } catch (e) {
      print('Koordinaten-basierte Schätzung Fehler: $e');
      _estimateFireDangerFromWeather();
    }
  }

  // Hilfsfunktion für Distanzberechnung
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Fallback: Schätze Waldbrandgefahr anhand der Wetterdaten
  void _estimateFireDangerFromWeather() {
    if (_hourlyWeather.isEmpty) {
      setState(() {
        _fireDangerLevel = 1;
        _fireDangerText = 'Waldbrandstufe: 1 (geschätzt)';
        _fireDangerColor = Colors.green;
      });
      return;
    }

    // Analysiere die nächsten 24h
    double avgTemp = 0;
    double avgHumidity = 0;
    double maxWind = 0;
    double totalRain = 0;
    int count = 0;

    for (var weather in _hourlyWeather.take(24)) {
      avgTemp += weather.temperature;
      avgHumidity += weather.humidity;
      if (weather.windSpeed > maxWind) maxWind = weather.windSpeed;
      totalRain += weather.precipitation;
      count++;
    }

    if (count > 0) {
      avgTemp /= count;
      avgHumidity /= count;
    }

    // Einfache Schätzung basierend auf Wetterdaten
    int estimatedLevel = 1;

    if (avgTemp > 25 && avgHumidity < 30 && totalRain < 1.0) {
      estimatedLevel = 4; // Hoch
    } else if (avgTemp > 20 && avgHumidity < 50 && totalRain < 2.0) {
      estimatedLevel = 3; // Mittel-hoch
    } else if (avgTemp > 15 && avgHumidity < 70) {
      estimatedLevel = 2; // Mittel
    }

    // Wind verstärkt die Gefahr
    if (maxWind > 20) estimatedLevel = (estimatedLevel + 1).clamp(1, 5);

    setState(() {
      _fireDangerLevel = estimatedLevel;
      _fireDangerText =
          'Waldbrandstufe: $estimatedLevel (aus Wetter geschätzt)';
      _fireDangerColor =
          [
            Colors.green,
            Colors.yellow,
            Colors.orange,
            Colors.red,
            Colors.deepOrange,
          ][(estimatedLevel - 1).clamp(0, 4)];
    });
  }

  void _checkSolarRadiation() {
    if (_hourlyWeather.isEmpty) return;

    final maxRadiation = _hourlyWeather
        .map((w) => w.solarRadiation)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxRadiation > 800) {
      setState(() {
        _solarWarning = 'Achtung: Sehr hohe Sonneneinstrahlung!';
        _solarWarningColor = Colors.orange;
      });
    } else {
      setState(() {
        _solarWarning = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Wetter-UI im Hintergrund
          Column(
            children: [
              // Header mit Ortssuche
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentLocation,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (_lastUpdated.isNotEmpty)
                                Text(
                                  'Letzte Aktualisierung: $_lastUpdated',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _fetchWeatherData,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Aktualisieren',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Ort suchen...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  },
                                )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _searchLocation,
                    ),
                  ],
                ),
              ),
              // Warnhinweise
              if (_fireDangerText != null || _fireDangerLevel != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: (_fireDangerColor ?? Colors.grey).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _fireDangerText ??
                        'Waldbrandstufe: Daten werden geladen...',
                    style: TextStyle(
                      color: _fireDangerColor ?? Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_weatherWarnings.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _weatherWarnings
                            .map(
                              (msg) => Text(
                                msg,
                                style: TextStyle(
                                  color: _warningColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              if (_solarWarning != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _solarWarningColor?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _solarWarning!,
                    style: TextStyle(
                      color: _solarWarningColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Wetter Content
              Expanded(child: _buildWeatherContent()),
            ],
          ),
          // Vorschlagsliste als Overlay
          if (_searchResults.isNotEmpty)
            Positioned(
              // Passe top ggf. an, je nach Höhe deines Headers
              top: 110, // Höhe des Headers + Padding
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(result.displayName),
                        onTap: () => _selectLocation(result),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    if (_isLoading && _hourlyWeather.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Wetterdaten werden geladen...'),
          ],
        ),
      );
    }

    if (_hasError && _hourlyWeather.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Keine Daten verfügbar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchWeatherData,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchWeatherData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Horizontale Stundenleiste
            SizedBox(
              height: 140, // Erhöht für Datum-Labels
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _hourlyWeather.length,
                itemBuilder: (context, index) {
                  final weather = _hourlyWeather[index];
                  final now = DateTime.now();
                  final isCurrentHour =
                      weather.time.hour == now.hour &&
                      weather.time.day == now.day &&
                      weather.time.month == now.month;
                  final isToday =
                      weather.time.day == now.day &&
                      weather.time.month == now.month;

                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color:
                          isCurrentHour
                              ? Theme.of(context).primaryColor.withOpacity(0.2)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          isCurrentHour
                              ? Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              )
                              : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Datum anzeigen wenn neuer Tag
                        if (index == 0 ||
                            _hourlyWeather[index].time.day !=
                                _hourlyWeather[index - 1].time.day)
                          Text(
                            isToday
                                ? 'Heute'
                                : DateFormat('dd.MM').format(weather.time),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isToday ? null : Colors.orange,
                            ),
                          ),
                        Text(
                          isCurrentHour
                              ? 'Jetzt'
                              : DateFormat('HH:mm').format(weather.time),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isCurrentHour
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          _getWeatherIcon(weather.weatherCode),
                          size: 24,
                          color: _getWeatherColor(weather.weatherCode),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${weather.temperature.toStringAsFixed(0)}°',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop,
                              size: 12,
                              color: Colors.blue,
                            ),
                            Text(
                              '${weather.precipitation.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Detaillierte Informationen für die nächsten Stunden (maximal 8 anzeigen)
            ...(_hourlyWeather
                .take(8)
                .map((weather) => WeatherDetailCard(weather: weather))),
          ],
        ),
      ),
    );
  }
}

IconData _getWeatherIcon(int code) {
  switch (code) {
    case 0:
      return Icons.wb_sunny;
    case 1:
    case 2:
    case 3:
      return Icons.wb_cloudy;
    case 45:
    case 48:
      return Icons.foggy;
    case 51:
    case 53:
    case 55:
      return Icons.grain;
    case 61:
    case 63:
    case 65:
      return Icons.water_drop;
    case 71:
    case 73:
    case 75:
      return Icons.ac_unit;
    case 95:
    case 96:
    case 99:
      return Icons.thunderstorm;
    default:
      return Icons.help_outline;
  }
}

Color _getWeatherColor(int code) {
  switch (code) {
    case 0:
      return Colors.orange;
    case 1:
    case 2:
    case 3:
      return Colors.grey;
    case 45:
    case 48:
      return Colors.blueGrey;
    case 51:
    case 53:
    case 55:
      return Colors.lightBlue;
    case 61:
    case 63:
    case 65:
      return Colors.blue;
    case 71:
    case 73:
    case 75:
      return Colors.lightBlue;
    case 95:
    case 96:
    case 99:
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

class WeatherDetailCard extends StatelessWidget {
  final HourlyWeather weather;

  const WeatherDetailCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentHour =
        weather.time.hour == now.hour &&
        weather.time.day == now.day &&
        weather.time.month == now.month;
    final isToday =
        weather.time.day == now.day && weather.time.month == now.month;
    final isTomorrow = weather.time.day == now.add(const Duration(days: 1)).day;

    String timeLabel = '';
    if (isCurrentHour) {
      timeLabel = 'Jetzt (${DateFormat('HH:mm').format(weather.time)})';
    } else if (isToday) {
      timeLabel = DateFormat('HH:mm').format(weather.time);
    } else if (isTomorrow) {
      timeLabel = 'Morgen ${DateFormat('HH:mm').format(weather.time)}';
    } else {
      timeLabel = DateFormat('dd.MM HH:mm').format(weather.time);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentHour ? 4 : 1,
      color:
          isCurrentHour
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          isCurrentHour
                              ? Theme.of(context).primaryColor
                              : (!isToday ? Colors.orange : null),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      _getWeatherIcon(weather.weatherCode),
                      size: 20,
                      color: _getWeatherColor(weather.weatherCode),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${weather.temperature.toStringAsFixed(1)}°C',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.water_drop,
                    'Regen',
                    '${weather.precipitation.toStringAsFixed(1)} mm',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.opacity,
                    'Luftfeuchte',
                    '${weather.humidity}%',
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.air,
                    'Wind',
                    '${weather.windSpeed.toStringAsFixed(0)} km/h\n${_getWindDirection(weather.windDirection)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.wb_sunny,
                    'Sonne',
                    '${weather.solarRadiation.toStringAsFixed(0)} W/m²',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  IconData _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
        return Icons.grain;
      case 61:
      case 63:
      case 65:
        return Icons.water_drop;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm;
      default:
        return Icons.help_outline;
    }
  }

  Color _getWeatherColor(int code) {
    switch (code) {
      case 0:
        return Colors.orange;
      case 1:
      case 2:
      case 3:
        return Colors.grey;
      case 45:
      case 48:
        return Colors.blueGrey;
      case 51:
      case 53:
      case 55:
        return Colors.lightBlue;
      case 61:
      case 63:
      case 65:
        return Colors.blue;
      case 71:
      case 73:
      case 75:
        return Colors.lightBlue;
      case 95:
      case 96:
      case 99:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getWindDirection(int degrees) {
    const directions = [
      'N',
      'NNO',
      'NO',
      'ONO',
      'O',
      'OSO',
      'SO',
      'SSO',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    int index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int humidity;
  final double precipitation;
  final int weatherCode;
  final double pressure;
  final double windSpeed;
  final int windDirection;
  final double windGusts;
  final double solarRadiation;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.weatherCode,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.solarRadiation,
  });
}
