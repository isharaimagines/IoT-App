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
  int? _touchedIndex; // Store the index of the touched bar

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
    final now = DateTime.now();
    print(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('recent')
        .doc(user.uid)
        .collection('activities')
        .where('addtime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('addtime', isLessThan: Timestamp.fromDate(endOfDay))
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
            ? 1.2
            : (data.map((spot) => spot.y).reduce(max) * 1.2);
      });
      _controller.reset();
      _controller.forward();
    }
  }

  Widget _buildTimeTitles(double value, TitleMeta meta) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return Padding(
      padding: const EdgeInsets.only(top: 8), // Add vertical spacing
      child: Text(
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  BarChartGroupData _makeBar(int index, FlSpot spot) {
    final double value = spot.y;
    final Color barColor;
    final isTouched = index == _touchedIndex;

    if (value >= 0.06) {
      barColor = Colors.yellow;
    } else if (value >= 0.03) {
      barColor = Colors.greenAccent;
    } else if (value >= 0) {
      barColor = Colors.blueAccent;
    } else {
      barColor = Colors.blueGrey;
    }

    return BarChartGroupData(
      x: spot.x.toInt(),
      barRods: [
        BarChartRodData(
          toY: value * _animation.value,
          color: isTouched ? Colors.deepPurpleAccent : barColor,
          width: 50,
          borderRadius: BorderRadius.circular(100),
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
        child: Column(
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
            _moodData.isEmpty
                ? const Center(
                    child: Text(
                      'No activities today',
                    ),
                  )
                : SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: SizedBox(
                        width: _moodData.length * 60, // Adjust width per bar

                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) {
                            return BarChart(
                              BarChartData(
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  allowTouchBarBackDraw:
                                      true, // Touch bar appears behind others

                                  touchCallback: (FlTouchEvent event,
                                      BarTouchResponse? response) {
                                    if (response == null ||
                                        response.spot == null) {
                                      setState(() => _touchedIndex = null);
                                      return;
                                    }

                                    setState(() {
                                      if (event is FlTapCancelEvent ||
                                          !event.isInterestedForInteractions) {
                                        _touchedIndex = null;
                                      } else {
                                        _touchedIndex =
                                            response.spot!.touchedBarGroupIndex;
                                      }
                                    });
                                  },
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (group) =>
                                        Colors.deepPurpleAccent,

                                    tooltipMargin: 5, // Distance from the bar
                                    tooltipRoundedRadius: 8,
                                    fitInsideHorizontally:
                                        true, // Allow tooltip to go beyond bounds if needed
                                    tooltipPadding: const EdgeInsets.all(8),
                                    maxContentWidth: 120,

                                    // tooltipPosition: TooltipPosition.right,
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      final date =
                                          DateTime.fromMillisecondsSinceEpoch(
                                              group.x.toInt());
                                      return BarTooltipItem(
                                        '${date.hour}:${date.minute.toString().padLeft(2, '0')} Insight: ${rod.toY.toStringAsFixed(3)}',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      );
                                    },
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
                                borderData: FlBorderData(show: false),
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
                                alignment: BarChartAlignment.start,
                                groupsSpace: 2,
                                backgroundColor: Colors.transparent,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            _moodData.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(Colors.blueAccent, 'Sad'),
                      _buildLegendItem(Colors.greenAccent, 'Neutral'),
                      _buildLegendItem(Colors.yellow, 'Happy'),
                      _buildLegendItem(Colors.redAccent, 'Uncomfortable'),
                      _buildLegendItem(Colors.deepPurpleAccent, 'Select'),
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
