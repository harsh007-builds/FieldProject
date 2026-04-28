import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

class BuildingAdminDashboard extends StatefulWidget {
  final String buildingId;
  const BuildingAdminDashboard({super.key, required this.buildingId});

  @override
  State<BuildingAdminDashboard> createState() => _BuildingAdminDashboardState();
}

class _BuildingAdminDashboardState extends State<BuildingAdminDashboard> {
  
  Map<String, dynamic>? _stats;
  List<dynamic>? _complaints;
  List<dynamic>? _warnings;
  bool _isLoading = true;
  Timer? _refreshTimer;
  final List<String> complaintCategories = ['Missed Collection', 'Overflowing Bins', 'Improper Segregation', 'Broken Bins', 'Bulky Waste Pickup', 'Hygiene Issue', 'Other'];
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadData(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final statsRes = await http.get(Uri.parse('$baseUrl/buildings/${widget.buildingId}/stats'));
      final complaintsRes = await http.get(Uri.parse('$baseUrl/complaints/building/${widget.buildingId}'));
      final warningsRes = await http.get(Uri.parse('$baseUrl/warnings/building/${widget.buildingId}'));
      
      if (mounted) {
        setState(() {
          _stats = jsonDecode(statsRes.body);
          _complaints = jsonDecode(complaintsRes.body);
          _warnings = jsonDecode(warningsRes.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _raiseComplaint(String description, String category) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/complaints'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buildingId': widget.buildingId,
          'description': description,
          'category': category,
          'raisedBy': 'Building Admin',
        }),
      );
      if (res.statusCode == 201) {
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint raised successfully'), backgroundColor: Color(0xFF00FF94)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  String _getSmartSuggestion(int greenScore, double rejectKg, double totalKg) {
    if (totalKg == 0) return 'No waste data yet. Start logging to get insights.';
    final rejectRatio = rejectKg / totalKg;
    if (greenScore >= 80) return 'Excellent segregation! Keep up the good work.';
    if (rejectRatio > 0.25) return 'High reject waste detected. Consider a resident awareness drive.';
    if (greenScore < 50) return 'Critical: Immediate intervention needed. Review waste management practices.';
    return 'Good progress. Focus on reducing reject waste for better scores.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_stats?['building']?['name'] ?? 'Building Overview', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF94)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => _showComplaintDialog(),
          child: const Icon(Icons.add_comment, color: Colors.white),
        ),
      ),
      body: _isLoading 
        ? _buildLoadingGradient()
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A192F), Color(0xFF0D2137), Color(0xFF051726)],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF00D4FF),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGlassHeader(),
                      const SizedBox(height: 20),
                      _buildGreenScoreGauge(),
                      const SizedBox(height: 20),
                      _buildMetricsRow(),
                      const SizedBox(height: 20),
                      _buildWarningsSection(),
                      const SizedBox(height: 20),
                      _buildDonutChart(),
                      const SizedBox(height: 20),
                      _buildFinancialTile(),
                      const SizedBox(height: 20),
                      _buildSuggestionCard(),
                      const SizedBox(height: 20),
                      _buildComplaintsList(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildLoadingGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A192F), Color(0xFF0D2137), Color(0xFF051726)],
        ),
      ),
      child: const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF))),
    );
  }

  Widget _buildGlassHeader() {
    final rank = _stats?['rank']?['position'] ?? 0;
    final total = _stats?['rank']?['totalBuildings'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF94)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_stats?['building']?['address'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                const Text('Global Ranking ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('#$rank of $total', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF94).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.trending_up, color: Color(0xFF00FF94), size: 16),
              const SizedBox(width: 4),
              Text('Top ${total > 0 ? ((total - rank + 1) / total * 100).toInt() : 0}%', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildGreenScoreGauge() {
    final score = (_stats?['building']?['currentGreenScore'] ?? 70).toDouble();
    Color scoreColor;
    if (score >= 80) scoreColor = const Color(0xFF00FF94);
    else if (score >= 50) scoreColor = const Color(0xFFFFD700);
    else scoreColor = const Color(0xFFFF6B00);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: scoreColor.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text('Environmental Performance', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          SizedBox(
            width: 220, height: 140,
            child: CustomPaint(
              painter: _SemiCircleGaugePainter(score: score, color: scoreColor),
              child: Center(child: Padding(padding: const EdgeInsets.only(top: 20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(score.toInt().toString(), style: TextStyle(color: scoreColor, fontSize: 42, fontWeight: FontWeight.bold)),
                Text('Green Score', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ]))),
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricChips(score, scoreColor),
        ],
      ),
    );
  }

  Widget _buildMetricChips(double score, Color color) {
    final wet = _stats?['wasteStats']?['wetKg'] ?? 0;
    final dry = _stats?['wasteStats']?['dryKg'] ?? 0;
    final reject = _stats?['wasteStats']?['rejectKg'] ?? 0;
    final total = wet + dry + reject;
    final segregation = total > 0 ? ((wet + dry) / total * 100).toInt() : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildChip('Segregation', '$segregation%', const Color(0xFF00FF94)),
        _buildChip('Total Waste', '${total}kg', const Color(0xFF00D4FF)),
        _buildChip('Reject Rate', '${total > 0 ? (reject / total * 100).toInt() : 0}%', const Color(0xFFFF6B00)),
      ],
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
      ]),
    );
  }

  Widget _buildMetricsRow() {
    final wet = _stats?['wasteStats']?['wetKg'] ?? 0;
    final dry = _stats?['wasteStats']?['dryKg'] ?? 0;
    final reject = _stats?['wasteStats']?['rejectKg'] ?? 0;

    return Row(
      children: [
        _buildMetricTile('Wet Waste', '$wet kg', const Color(0xFF00FF94), Icons.water_drop),
        const SizedBox(width: 12),
        _buildMetricTile('Dry Waste', '$dry kg', const Color(0xFF00D4FF), Icons.eco),
        const SizedBox(width: 12),
        _buildMetricTile('Reject', '$reject kg', const Color(0xFFFF6B00), Icons.delete_forever),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildDonutChart() {
    final wet = (_stats?['wasteStats']?['wetKg'] ?? 50).toDouble();
    final dry = (_stats?['wasteStats']?['dryKg'] ?? 30).toDouble();
    final reject = (_stats?['wasteStats']?['rejectKg'] ?? 20).toDouble();
    final total = wet + dry + reject;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Waste Distribution Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: total > 0 ? [
                        PieChartSectionData(value: wet, color: const Color(0xFF00FF94), title: '${(wet/total*100).toInt()}%\nWet', titleStyle: const TextStyle(color: Color(0xFF0D0D0D), fontSize: 11, fontWeight: FontWeight.bold), radius: 50),
                        PieChartSectionData(value: dry, color: const Color(0xFF00D4FF), title: '${(dry/total*100).toInt()}%\nDry', titleStyle: const TextStyle(color: Color(0xFF0D0D0D), fontSize: 11, fontWeight: FontWeight.bold), radius: 50),
                        PieChartSectionData(value: reject, color: const Color(0xFFFF6B00), title: '${(reject/total*100).toInt()}%\nReject', titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), radius: 50),
                      ] : [
                        PieChartSectionData(value: 1, color: Colors.grey.withValues(alpha: 0.2), title: 'No Data', titleStyle: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold), radius: 50),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDonutLegend('Wet', const Color(0xFF00FF94), wet.toInt()),
                    const SizedBox(height: 12),
                    _buildDonutLegend('Dry', const Color(0xFF00D4FF), dry.toInt()),
                    const SizedBox(height: 12),
                    _buildDonutLegend('Reject', const Color(0xFFFF6B00), reject.toInt()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegend(String label, Color color, int value) {
    return Row(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        Text('$value kg', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    ]);
  }

  Widget _buildFinancialTile() {
    final billing = _stats?['billing'];
    final currentBill = billing?['currentBill'] ?? 0.0;
    final penaltyAmount = billing?['penaltyAmount'] ?? 0.0;
    final rates = billing?['rates'] ?? {};
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00D4FF).withValues(alpha: 0.2), const Color(0xFF00FF94).withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF00D4FF), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estimated Monthly Bill', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('₹$currentBill', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ]),
              ),
              SizedBox(
                width: 60, height: 40,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [const FlSpot(0, 10), const FlSpot(1, 15), const FlSpot(2, 12), const FlSpot(3, 18), const FlSpot(4, 14), const FlSpot(5, 20)],
                        isCurved: true,
                        color: const Color(0xFF00FF94),
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: const Color(0xFF00FF94).withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (penaltyAmount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Penalty Alert', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('₹$penaltyAmount extra paid due to Reject Waste. Segregate better to save!', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          )
        else if (penaltyAmount == 0 && currentBill > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF94).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00FF94), size: 24),
                SizedBox(width: 12),
                Expanded(child: Text('Perfect Segregation: ₹0 Penalties Applied!', style: TextStyle(color: Color(0xFF00FF94), fontSize: 14, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showRatesDialog(rates),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.white54, size: 16),
                SizedBox(width: 6),
                Text('Current Municipal Rates', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRatesDialog(Map<String, dynamic> rates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Municipal Waste Rates', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRateRow('Wet Waste', rates['wetWastePrice'] ?? 5, const Color(0xFF00FF94)),
            const SizedBox(height: 8),
            _buildRateRow('Dry Waste', rates['dryWastePrice'] ?? 5, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _buildRateRow('Reject Waste', rates['rejectWastePrice'] ?? 15, const Color(0xFFFF6B00)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String label, int rate, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text('₹$rate/kg', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSuggestionCard() {
    final greenScore = _stats?['building']?['currentGreenScore'] ?? 70;
    final rejectKg = (_stats?['wasteStats']?['rejectKg'] ?? 0).toDouble();
    final totalKg = (_stats?['wasteStats']?['totalKg'] ?? 0).toDouble();
    final suggestion = _getSmartSuggestion(greenScore, rejectKg, totalKg);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Smart Insight', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(suggestion, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ])),
        ],
      ),
    );
  }

  Widget _buildComplaintsList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent Complaints', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (_complaints == null || _complaints!.isEmpty)
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Center(child: Text('No complaints recorded', style: TextStyle(color: Colors.white54))))
      else
        ..._complaints!.take(5).map((c) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c['status'] == 'Resolved' ? const Color(0xFF00FF94).withValues(alpha: 0.15) : const Color(0xFFFF6B00).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(c['status'] == 'Resolved' ? Icons.check_circle : Icons.pending, color: c['status'] == 'Resolved' ? const Color(0xFF00FF94) : const Color(0xFFFF6B00), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['category'] ?? 'General', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(c['description'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(_formatDate(c['createdAt']), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c['status'] == 'Resolved' ? const Color(0xFF00FF94).withValues(alpha: 0.15) : const Color(0xFFFF6B00).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(c['status'] ?? 'Pending', style: TextStyle(color: c['status'] == 'Resolved' ? const Color(0xFF00FF94) : const Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
        )),
    ]);
  }

  void _showComplaintDialog() {
    final controller = TextEditingController();
    selectedCategory = null;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A192F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                 value: selectedCategory,
                 dropdownColor: const Color(0xFF0A192F),
                 decoration: InputDecoration(
                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))), 
                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D4FF)))
                 ),
                 hint: const Text('Select Category', style: TextStyle(color: Colors.white38)),
                 items: complaintCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                 onChanged: (val) => setDialogState(() => selectedCategory = val),
               ),
               const SizedBox(height: 16),
               TextField(controller: controller, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Describe the problem...', hintStyle: const TextStyle(color: Colors.white38), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00D4FF))))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () { 
                if (selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red));
                  return;
                }
                if (controller.text.isNotEmpty) { 
                  Navigator.pop(ctx); 
                  _raiseComplaint(controller.text, selectedCategory!); 
                } 
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Submit', style: TextStyle(color: Color(0xFF0D0D0D), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildWarningsSection() {
    final warnings = _warnings ?? [];
    final unreadCount = warnings.where((w) => w['status'] == 'Unread').length;
    
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD700), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('BMC Warnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  child: Text('$unreadCount NEW', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...warnings.take(5).map((w) => _buildWarningCard(w)),
        ],
      ),
    );
  }

  Widget _buildWarningCard(Map<String, dynamic> warning) {
    final isUnread = warning['status'] == 'Unread';
    final isCritical = warning['alertType'] == 'CRITICAL_SCORE';
    final borderColor = isCritical ? Colors.red : const Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread 
            ? borderColor.withValues(alpha: 0.1) 
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? borderColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? Icons.error : Icons.schedule,
                color: borderColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCritical ? 'Critical Score Alert' : 'Missed Collection Alert',
                  style: TextStyle(color: borderColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              if (isUnread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 8),
              Text(_formatTimeAgo(warning['createdAt']), style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(warning['message'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
          if (warning['additionalNote'] != null && warning['additionalNote'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Colors.white.withValues(alpha: 0.4), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning['additionalNote'],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isUnread) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _markWarningRead(warning['_id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF94).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.3)),
                  ),
                  child: const Text('Mark as Read', style: TextStyle(color: Color(0xFF00FF94), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markWarningRead(String warningId) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/warnings/$warningId/read'));
      if (res.statusCode == 200) {
        _loadData(showSpinner: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _SemiCircleGaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _SemiCircleGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 15;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.14159, 3.14159, false, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 3.14159;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.14159, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
