import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:data_table_2/data_table_2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm Weather Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey,
      ),
      home: const MyHomePage(title: 'Rain Prediction'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class RainPredictor {
  final String apiKey = "API_KEY"; // replace with your Weatherbit key
  final double cutOffRainAmount = 15.0;
  final List<double> dailyConfidenceScores = [
    0.95,
    0.9,
    0.85,
    0.8,
    0.7,
    0.6,
    0.5,
    0.4,
    0.3,
    0.25,
    0.2,
    0.15,
    0.1,
    0.1,
    0.05,
    0.05,
  ];

  Future<double> historicalAverage(double lat, double lon) async {
    final today = DateTime.now();
    final futureDate = today.add(const Duration(days: 31));
    final currentYear = today.year;
    int daysRained = 0;
    const noOfYears = 5;

    for (int i = 1; i <= noOfYears; i++) {
      final pastYear = currentYear - i;
      final startDate = DateTime(
        pastYear,
        today.month,
        today.day,
      ).toIso8601String().split("T")[0];
      final endDate = DateTime(
        pastYear,
        futureDate.month,
        futureDate.day + 1,
      ).toIso8601String().split("T")[0];

      final url =
          "https://api.weatherbit.io/v2.0/history/daily?&lat=$lat&lon=$lon&start_date=$startDate&end_date=$endDate&key=$apiKey";

      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)["data"] as List;
          final filtered = data
              .where((d) => (d["precip"] ?? 0) >= cutOffRainAmount)
              .toList();
          daysRained += filtered.length;
        }
      } catch (_) {}
    }

    return daysRained / (31 * noOfYears);
  }

  Future<List<Map<String, String>>> predictRain(double lat, double lon) async {
    final avgChance = await historicalAverage(lat, lon);

    final url =
        "https://api.weatherbit.io/v2.0/forecast/daily?&lat=$lat&lon=$lon&key=$apiKey";
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception("Failed to fetch forecast");

    final weatherData = jsonDecode(res.body)["data"] as List;

    // format data
    final formattedData = weatherData
        .map(
          (day) => {
            "date": day["datetime"],
            "rawChance": (day["pop"] ?? 0).toString() + "%",
            "rainAmount": day["precip"].toString(),
          },
        )
        .toList();

    // confidence-adjusted
    final adjusted = <Map<String, String>>[];
    for (int i = 0; i < formattedData.length; i++) {
      final day = formattedData[i];
      final forecastChance =
          (double.parse(day["rainAmount"] ?? "0") > cutOffRainAmount
          ? (double.parse(day["rawChance"].replaceAll("%", "")) / 100.0)
          : 0.0);
      final confidence = (i < dailyConfidenceScores.length)
          ? dailyConfidenceScores[i]
          : 0.05;
      final climateWeight = 1 - confidence;
      final adjustedChance =
          (forecastChance * confidence + avgChance * climateWeight).clamp(
            0.05,
            0.95,
          );
      adjusted.add({
        "date": day["date"],
        "rawChance": day["rawChance"],
        "adjustedChance": (adjustedChance * 100).toStringAsFixed(1) + "%",
      });
    }

    // rolling 5-day windows
    final rolling = <Map<String, String>>[];
    for (int i = 0; i <= adjusted.length - 5; i++) {
      final window = adjusted.sublist(i, i + 5);
      final firstDay = window.first;

      final probNoRain = window
          .map(
            (d) =>
                1 -
                double.parse(d["adjustedChance"]!.replaceAll("%", "")) / 100,
          )
          .reduce((a, b) => a * b);

      final probRain = 1 - probNoRain;

      // Calculate combined raw chance as a double, then format as String
      double combinedRawChance =
          window
              .map(
                (d) =>
                    double.parse((d["rawChance"] ?? "0").replaceAll("%", "")),
              )
              .reduce((a, b) => 1 - (1 - a / 100) * (1 - b / 100)) *
          100;
      rolling.add({
        "index": i.toString(),
        "date": firstDay["date"]!,
        "rawChance": "${combinedRawChance.toStringAsFixed(1)}%",
        "adjustedChance": (probRain * 100).toStringAsFixed(1) + "%",
      });
    }

    return rolling;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final RainPredictor predictor = RainPredictor();
  bool loading = false;
  double avgChance = 0.0;
  List<Map<String, String>> tableData = [];

  void _fetchForecast() async {
    setState(() => loading = true);
    try {
      final result = await predictor.predictRain(10.0749, 76.2089);
      final avg = await predictor.historicalAverage(10.0749, 76.2089);
      setState(() {
        tableData = result;
        avgChance = avg;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildGradientText(String text) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Colors.blue, Colors.purple, Colors.pink],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getDateRange() {
    final today = DateTime.now();
    final endDate = today.add(const Duration(days: 31));
    return "${today.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : tableData.isEmpty
          ? const Center(
              child: Text(
                "Press the button to fetch forecast",
                style: TextStyle(color: Colors.white),
              ),
            )
          : Column(
              children: [
                // Header text with gradient
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Based on the last 5 years, the average chance of significant rain from ${_getDateRange()} is",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      _buildGradientText(
                        "${(avgChance * 100).toStringAsFixed(1)}%",
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),
                // Responsive table
                Expanded(
                  child: Container(
                    width: double.infinity,
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 400,
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey[900],
                      ),
                      headingTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((
                        Set<MaterialState> states,
                      ) {
                        if (states.contains(MaterialState.selected))
                          return Colors.grey[700];
                        return null;
                      }),
                      columns: const [
                        DataColumn2(label: Text("Index"), size: ColumnSize.S),
                        DataColumn2(
                          label: Text("Window Starts"),
                          size: ColumnSize.M,
                        ),
                        DataColumn2(
                          label: Text("Raw Chance"),
                          size: ColumnSize.M,
                        ),
                        DataColumn2(
                          label: Text("Adjusted Chance"),
                          size: ColumnSize.M,
                        ),
                      ],
                      rows: tableData.asMap().entries.map((entry) {
                        int idx = entry.key;
                        final row = entry.value;
                        return DataRow(
                          color: MaterialStateProperty.all(
                            idx % 2 == 0 ? Colors.grey[850] : Colors.grey[800],
                          ),
                          cells: [
                            DataCell(Text(row["index"] ?? "")),
                            DataCell(Text(row["date"] ?? "")),
                            DataCell(Text(row["rawChance"] ?? "")),
                            DataCell(Text(row["adjustedChance"] ?? "")),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: _fetchForecast,
        tooltip: 'Get Forecast',
        child: const Icon(Icons.cloud),
      ),
    );
  }
}
