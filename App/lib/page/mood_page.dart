import 'dart:math';

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
  double _maxY = 1.2;

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
        .collection('recent')
        .doc(user.uid)
        .collection('activities')
        .orderBy('addtime', descending: true)
        .get();

    final data = snapshot.docs.reversed.map((doc) {
      final time = doc['addtime'] as Timestamp;
      final point = (doc['emotionScore'] as num).toDouble();

      return FlSpot(
        time.toDate().millisecondsSinceEpoch.toDouble(),
        point,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _moodData = data;
        // Inside _fetchMoodData after getting data
        _maxY = (data.isEmpty)
            ? 1.05
            : (data.map((spot) => spot.y).reduce(max) * 1.05);
      });
      _controller.reset();
      _controller.forward();
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

    if (value >= 0.8) {
      barColor = Colors.yellow;
    } else if (value >= 0.5) {
      barColor = Colors.blueAccent;
    } else if (value > 0.2) {
      barColor = Colors.greenAccent;
    } else {
      barColor = Colors.blueGrey;
    }

    return BarChartGroupData(
      x: spot.x.toInt(),
      barRods: [
        BarChartRodData(
          toY: value * _animation.value,
          color: barColor,
          width: 30,
          borderRadius: BorderRadius.vertical(top: Radius.circular(100)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: _maxY,
            color: barColor.withOpacity(0.2),
          ),
        )
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: _moodData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Today Insight',
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Establishing consistent sleep patterns is essential for enhancing your overall well-being. By prioritizing a regular sleep schedule, you can significantly boost your mood and energy levels.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Chart
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: SizedBox(
                        width: _moodData.length * 40, // Adjust width per bar

                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) {
                            return BarChart(
                              BarChartData(
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (group) =>
                                        Colors.grey.shade100,
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      final date =
                                          DateTime.fromMillisecondsSinceEpoch(
                                              group.x.toInt());
                                      return BarTooltipItem(
                                        '${date.hour}:${date.minute.toString().padLeft(2, '0')}\nInsight: ${rod.toY.toStringAsFixed(2)}',
                                        const TextStyle(
                                          color: Colors.black,
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
                                      interval: 3600000,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: 0.2,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
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
                                  horizontalInterval: 0.2,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.shade300,
                                    strokeWidth: 1,
                                  ),
                                ),
                                maxY: _maxY,
                                minY: 0,
                                alignment: BarChartAlignment.spaceAround,
                                groupsSpace: 8,
                                backgroundColor: Colors.transparent,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.blueGrey, 'Sad'),
                      _buildLegendItem(Colors.greenAccent, 'Neutral'),
                      _buildLegendItem(Colors.blueAccent, 'Happy'),
                      _buildLegendItem(Colors.yellow, 'Joy'),
                    ],
                  )
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
