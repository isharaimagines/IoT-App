import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});

  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<FlSpot> _moodData = [];
  double _maxY = 10;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _fetchMoodData();
  }

  Future<void> _fetchMoodData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('moods')
        .doc(user.uid)
        .collection('entries')
        .orderBy('time', descending: true)
        .get();

    final data = snapshot.docs.map((doc) {
      final time = doc['time'] as Timestamp;
      final point = (doc['point'] as num).toDouble();

      return FlSpot(
        time.toDate().millisecondsSinceEpoch.toDouble(),
        point,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _moodData = data;
        _maxY = 20;
      });
    }
  }

  Widget _buildTimeTitles(double value, TitleMeta meta) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return Text(
      '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 10),
    );
  }

  BarChartGroupData _makeBar(int index, FlSpot spot) {
    final double value = spot.y;
    final Color barColor;
    final Color backBarColor;

    if (value <= 5) {
      barColor = Colors.purple.shade200;
    } else if (value <= 9) {
      barColor = Colors.orange.shade200;
    } else if (value == 10) {
      barColor = Colors.grey.shade300;
    } else if (value <= 15) {
      barColor = Colors.yellow.shade200;
    } else {
      barColor = Colors.green.shade200;
    }

    if (value <= 5) {
      backBarColor = Colors.purple.shade50;
    } else if (value <= 9) {
      backBarColor = Colors.orange.shade50;
    } else if (value == 10) {
      backBarColor = Colors.grey.shade50;
    } else if (value <= 15) {
      backBarColor = Colors.yellow.shade50;
    } else {
      backBarColor = Colors.green.shade50;
    }

    return BarChartGroupData(
      x: spot.x.toInt(),
      barRods: [
        BarChartRodData(
          toY: value * _animation.value,
          color: barColor,
          borderRadius: BorderRadius.circular(20),
          width: 20,
          backDrawRodData: BackgroundBarChartRodData(
              show: true, toY: _maxY, color: backBarColor),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _moodData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),
                  Text(
                    'WellSync Score',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_moodData.isNotEmpty)
                    Text(
                      'Latest Mood: ${_moodData.first.y.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  // Title and Subtitle
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20),
                        Text.rich(
                          TextSpan(
                            text: 'Today Insights',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Chart
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (group) => Colors.black87,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final date =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          group.x.toInt());
                                  return BarTooltipItem(
                                    '${date.hour}:${date.minute.toString().padLeft(2, '0')}\nMood: ${rod.toY.toStringAsFixed(1)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  );
                                },
                                maxContentWidth: 120,
                                fitInsideHorizontally: true,
                                tooltipPadding: const EdgeInsets.all(8),
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: _buildTimeTitles,
                                  reservedSize: 36,
                                  interval: 3600000, // 1 hour in milliseconds
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                  interval: 2,
                                ),
                              ),
                              rightTitles: const AxisTitles(),
                              topTitles: const AxisTitles(),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            barGroups: _moodData
                                .asMap()
                                .entries
                                .map((e) => _makeBar(e.key, e.value))
                                .toList(),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 2,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                              ),
                            ),
                            maxY: 20,
                            minY: 0,
                            alignment: BarChartAlignment.spaceAround,
                            groupsSpace: 0,
                            backgroundColor: Colors.transparent,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Insight Key',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                      height: 12), // spacing between chart and legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem(Colors.purple.shade200, 'ANGRY'),
                      _buildLegendItem(Colors.orange.shade200, 'SAD'),
                      _buildLegendItem(Colors.grey.shade300, 'NEUTRAL'),
                      _buildLegendItem(Colors.yellow.shade200, 'HAPPY'),
                      _buildLegendItem(Colors.green.shade200, 'ENJOY'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
