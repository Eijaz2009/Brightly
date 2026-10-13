import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_style.dart';
import '../../widgets/scholarship_card.dart';

/// Scholarship distribution overview.
///
/// Bug fix: this used to render hard-coded numbers with a fake "+12.5%" badge,
/// which looked like real analytics but was not. It now counts the actual
/// catalogue and falls back to an honest empty state.
class AnalyticsChart extends StatelessWidget {
  const AnalyticsChart({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Object?>>(
      stream: FirebaseFirestore.instance.collection('scholarships').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs;

        if (snapshot.connectionState == ConnectionState.waiting && docs == null) {
          return _shell(
            context,
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return _shell(context, _message(context, 'Gagal memuat data'));
        }

        final counts = <String, int>{'S1': 0, 'S2': 0, 'S3': 0};
        var total = 0;

        for (final doc in docs ?? const []) {
          final data = (doc.data() as Map?)?.cast<String, dynamic>();
          if (data == null) continue;
          total++;

          final level = ScholarshipCard.levelOf(data).toUpperCase();
          if (level.contains('S1')) counts['S1'] = counts['S1']! + 1;
          if (level.contains('S2')) counts['S2'] = counts['S2']! + 1;
          if (level.contains('S3')) counts['S3'] = counts['S3']! + 1;
        }

        if (total == 0) {
          return _shell(
            context,
            _message(context, 'Belum ada data beasiswa untuk dianalisis'),
          );
        }

        final maxValue = <int>[
          counts['S1']!,
          counts['S2']!,
          counts['S3']!,
        ].reduce((a, b) => a > b ? a : b);

        final bars = <BarChartGroupData>[
          _bar(context, 'S1', counts['S1']!, maxValue, AppStyle.primaryBlue),
          _bar(
            context,
            'S2',
            counts['S2']!,
            maxValue,
            AppStyle.accentOrange,
          ),
          _bar(
            context,
            'S3',
            counts['S3']!,
            maxValue,
            AppStyle.successGreen,
          ),
        ];

        return _shell(
          context,
          Column(
            children: [
              Row(
                children: [
                  _legend(context, AppStyle.primaryBlue, 'S1', counts['S1']!),
                  const SizedBox(width: 14),
                  _legend(context, AppStyle.accentOrange, 'S2', counts['S2']!),
                  const SizedBox(width: 14),
                  _legend(context, AppStyle.successGreen, 'S3', counts['S3']!),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxValue * 1.25).clamp(4, double.infinity),
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppStyle.getBorderColor(context),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index > 2) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                const ['S1', 'S2', 'S3'][index],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppStyle.getSubtitleColor(context),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: bars,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shell(BuildContext context, Widget child) {
    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.2),
        boxShadow: AppStyle.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sebaran Beasiswa',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppStyle.getTextColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Jumlah beasiswa per jenjang pendidikan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppStyle.getSubtitleColor(context),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppStyle.getSubtitleColor(context),
          ),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, int value) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppStyle.getSubtitleColor(context),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static BarChartGroupData _bar(
    BuildContext context,
    String label,
    int value,
    int maxValue,
    Color color,
  ) {
    return BarChartGroupData(
      x: int.parse(label.substring(1)) - 1,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          width: 34,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color.withValues(alpha: 0.65), color],
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxValue.toDouble(),
            color: AppStyle.getBorderColor(context).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
