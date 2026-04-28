import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

class BmcAdminDashboard extends StatefulWidget {
  const BmcAdminDashboard({super.key});

  @override
  State<BmcAdminDashboard> createState() => _BmcAdminDashboardState();
}

class _BmcAdminDashboardState extends State<BmcAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic>? _systemStats;
  List<dynamic>? _leaderboard;
  List<dynamic>? _complaints;
  List<dynamic>? _cleaners;
  List<dynamic>? _buildings;
  List<dynamic>? _alerts;
  bool _isLoading = true;
  Map<String, dynamic>? _systemSettings;
  final _wetPriceController = TextEditingController();
  final _dryPriceController = TextEditingController();
  final _rejectPriceController = TextEditingController();
  bool _isUpdatingPrices = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadData(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _wetPriceController.dispose();
    _dryPriceController.dispose();
    _rejectPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final statsRes = await http.get(Uri.parse('$baseUrl/system/stats'));
      final leaderboardRes = await http.get(Uri.parse('$baseUrl/buildings/leaderboard'));
      final complaintsRes = await http.get(Uri.parse('$baseUrl/complaints/all'));
      final cleanersRes = await http.get(Uri.parse('$baseUrl/cleaners'));
      final buildingsRes = await http.get(Uri.parse('$baseUrl/buildings/leaderboard'));
      final alertsRes = await http.get(Uri.parse('$baseUrl/system/alerts'));
      final settingsRes = await http.get(Uri.parse('$baseUrl/settings'));

      if (mounted) {
        setState(() {
          _systemStats = jsonDecode(statsRes.body);
          _leaderboard = jsonDecode(leaderboardRes.body);
          _complaints = jsonDecode(complaintsRes.body);
          _cleaners = jsonDecode(cleanersRes.body);
          _buildings = jsonDecode(buildingsRes.body);
          _alerts = jsonDecode(alertsRes.body);
          _systemSettings = jsonDecode(settingsRes.body);
          _wetPriceController.text = (_systemSettings?['wetWastePrice'] ?? 5).toString();
          _dryPriceController.text = (_systemSettings?['dryWastePrice'] ?? 5).toString();
          _rejectPriceController.text = (_systemSettings?['rejectWastePrice'] ?? 15).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updatePricing() async {
    setState(() => _isUpdatingPrices = true);
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'wetWastePrice': double.tryParse(_wetPriceController.text) ?? 5,
          'dryWastePrice': double.tryParse(_dryPriceController.text) ?? 5,
          'rejectWastePrice': double.tryParse(_rejectPriceController.text) ?? 15,
        }),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pricing updated successfully'),
            backgroundColor: Color(0xFF00FF94),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPrices = false);
      }
    }
  }

  Future<void> _downloadCSV() async {
    final url = Uri.parse('$baseUrl/reports/csv');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _downloadPDF() async {
    final url = Uri.parse('$baseUrl/reports/pdf');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _registerCleaner(String name, String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/cleaners'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'phone': phone}),
      );
      if (res.statusCode == 201) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaner registered successfully'), backgroundColor: Color(0xFF00FF94)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _createBuilding(String name, String address, String ward, String cleanerId, String buildingType) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/buildings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'address': address,
          'ward': ward,
          'assignedCleanerId': cleanerId,
          'buildingType': buildingType,
        }),
      );
      if (res.statusCode == 201) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Building created successfully'), backgroundColor: Color(0xFF00FF94)));
        }
      } else {
        final error = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error['error'] ?? 'Error creating building'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _toggleBuildingStatus(String id, String currentStatus) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/buildings/$id/status'));
      if (res.statusCode == 200) {
        _loadData();
        if (mounted) {
          final newStatus = currentStatus == 'Active' ? 'Suspended' : 'Active';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Building $newStatus'), backgroundColor: const Color(0xFF00FF94)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _resolveComplaint(String id) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/complaints/$id/resolve'));
      if (res.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint resolved'), backgroundColor: Color(0xFF00FF94)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('BMC Global Command', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Color(0xFF00FF94)),
        elevation: 0,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF94),
          labelColor: const Color(0xFF00FF94),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.analytics)),
            Tab(text: 'Cleaners', icon: Icon(Icons.people)),
            Tab(text: 'Buildings', icon: Icon(Icons.business)),
            Tab(text: 'Pricing', icon: Icon(Icons.attach_money)),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF94)))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildCleanersTab(),
              _buildBuildingsTab(),
              _buildPricingTab(),
            ],
          ),
    );
  }

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF00FF94), size: 24),
                    SizedBox(width: 10),
                    Text('Pricing Engine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Configure cost per kg for different waste types', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                const SizedBox(height: 24),
                _buildPriceField('Wet Waste Rate (₹/kg)', _wetPriceController, const Color(0xFF00FF94)),
                const SizedBox(height: 16),
                _buildPriceField('Dry Waste Rate (₹/kg)', _dryPriceController, const Color(0xFF00D4FF)),
                const SizedBox(height: 16),
                _buildPriceField('Reject Waste Rate (₹/kg)', _rejectPriceController, const Color(0xFFFF6B00)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUpdatingPrices ? null : _updatePricing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF94),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isUpdatingPrices
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0D0D0D), strokeWidth: 2))
                      : const Text('Update System Pricing', style: TextStyle(color: Color(0xFF0D0D0D), fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller, Color color) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: color.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00FF94),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsRow(),
            const SizedBox(height: 24),
            _buildAlertsSection(),
            const SizedBox(height: 24),
            _buildLeaderboardSection(),
            const SizedBox(height: 24),
            _buildComplaintsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanersTab() {
    final cleaners = _cleaners ?? [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FF94),
        onPressed: () => _showRegisterCleanerDialog(),
        child: const Icon(Icons.add, color: Color(0xFF0D0D0D)),
      ),
      body: cleaners.isEmpty
        ? const Center(child: Text('No cleaners registered', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cleaners.length,
            itemBuilder: (context, index) => _buildCleanerCard(cleaners[index]),
          ),
    );
  }

  Widget _buildBuildingsTab() {
    final buildings = _buildings ?? [];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FF94),
        onPressed: () => _showAddBuildingDialog(),
        child: const Icon(Icons.add, color: Color(0xFF0D0D0D)),
      ),
      body: buildings.isEmpty
        ? const Center(child: Text('No buildings registered', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: buildings.length,
            itemBuilder: (context, index) => _buildBuildingCard(buildings[index]),
          ),
    );
  }

  Widget _buildCleanerCard(Map<String, dynamic> cleaner) {
    final isActive = cleaner['status'] == 'Active';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xFF00FF94).withValues(alpha: 0.3) : Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isActive ? const Color(0xFF00FF94).withValues(alpha: 0.2) : Colors.white12,
            child: Icon(Icons.person, color: isActive ? const Color(0xFF00FF94) : Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleaner['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(cleaner['phone'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (cleaner['assignedWard'] != null)
                  Text('Ward: ${cleaner['assignedWard']}', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF00FF94).withValues(alpha: 0.2) : const Color(0xFFFF6B00).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(cleaner['status'] ?? 'Inactive', style: TextStyle(color: isActive ? const Color(0xFF00FF94) : const Color(0xFFFF6B00), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Map<String, dynamic> building) {
    final isActive = building['status'] == 'Active';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xFF00D4FF).withValues(alpha: 0.3) : const Color(0xFFFF6B00).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF00D4FF).withValues(alpha: 0.2) : const Color(0xFFFF6B00).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business, color: isActive ? const Color(0xFF00D4FF) : const Color(0xFFFF6B00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(building['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(building['address'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Green Score: ${building['currentGreenScore'] ?? 100}', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 11)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00FF94).withValues(alpha: 0.2) : const Color(0xFFFF6B00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(building['status'] ?? 'Active', style: TextStyle(color: isActive ? const Color(0xFF00FF94) : const Color(0xFFFF6B00), fontSize: 11)),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _toggleBuildingStatus(building['_id'], building['status'] ?? 'Active'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isActive ? 'Suspend' : 'Activate', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRegisterCleanerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Register Cleaner', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Name')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _registerCleaner(nameController.text, phoneController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF94)),
            child: const Text('Register', style: TextStyle(color: Color(0xFF0D0D0D))),
          ),
        ],
      ),
    );
  }

  void _showAddBuildingDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String? selectedWard;
    String? selectedCleanerId;
    String? selectedType;
    final wards = ['Ward A', 'Ward B', 'Ward C', 'Ward D'];

    final cleaners = _cleaners ?? [];
    final isFormValid = nameController.text.isNotEmpty && addressController.text.isNotEmpty && selectedWard != null && selectedCleanerId != null && selectedType != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Add New Building', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Building Name')),
                const SizedBox(height: 12),
                TextField(controller: addressController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Address')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWard,
                  dropdownColor: const Color(0xFF1A1A1A),
                  hint: const Text('Select Ward', style: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Ward'),
                  items: wards.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (v) => setDialogState(() => selectedWard = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1A1A1A),
                  hint: const Text('Building Type', style: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Building Type'),
                  items: ['Residential', 'Commercial'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCleanerId,
                  dropdownColor: const Color(0xFF1A1A1A),
                  hint: const Text('Assign Cleaner', style: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Assign Cleaner'),
                  items: cleaners.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['_id'] as String, child: Text(c['name'] ?? ''))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCleanerId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && addressController.text.isNotEmpty && selectedWard != null && selectedCleanerId != null && selectedType != null) {
                  Navigator.pop(ctx);
                  _createBuilding(nameController.text, addressController.text, selectedWard!, selectedCleanerId!, selectedType!);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF94)),
              child: const Text('Create', style: TextStyle(color: Color(0xFF0D0D0D))),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF94))),
    );
  }

  Widget _buildMetricsRow() {
    final stats = _systemStats ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildMetricCard('Buildings', '${stats['totalBuildings'] ?? 0}', Icons.business, const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            _buildMetricCard('Green Score', '${stats['systemAverageGreenScore'] ?? 0}%', Icons.eco, const Color(0xFF00FF94)),
            const SizedBox(width: 8),
            _buildMetricCard('Waste', '${stats['totalSystemWaste'] ?? 0}kg', Icons.delete_sweep, const Color(0xFFFFD700)),
            const SizedBox(width: 8),
            _buildMetricCard('Cleaners', '${stats['totalActiveCleaners'] ?? 0}', Icons.people, const Color(0xFFFF6B00)),
          ],
        ),
        const SizedBox(height: 16),
        _buildExportControls(),
      ],
    );
  }


  Widget _buildExportControls() {
    return Row(
      children: [
        const Text('Compliance & Export', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: _downloadCSV,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.download, color: Color(0xFF00D4FF), size: 16),
                SizedBox(width: 6),
                Text('CSV', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _downloadPDF,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Color(0xFFFF6B00), size: 16),
                SizedBox(width: 6),
                Text('PDF', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9), maxLines: 1),
        ]),
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    final leaderboard = _leaderboard ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Global Leaderboard', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (leaderboard.isEmpty) const Text('No data', style: TextStyle(color: Colors.white54))
          else ...leaderboard.take(5).toList().asMap().entries.map((e) => _buildLeaderboardItem(e.key + 1, e.value)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(int rank, Map<String, dynamic> building) {
    Color rankColor = Colors.white54;
    if (rank == 1) rankColor = const Color(0xFFFFD700);
    else if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    else if (rank == 3) rankColor = const Color(0xFFCD7F32);

    final score = building['currentGreenScore'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('#$rank', style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          Expanded(child: Text(building['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
          Text('$score', style: TextStyle(color: score >= 80 ? const Color(0xFF00FF94) : score >= 50 ? const Color(0xFFFFD700) : const Color(0xFFFF6B00), fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildComplaintsSection() {
    final complaints = _complaints ?? [];
    final pendingCount = complaints.where((c) => c['status'] == 'Pending' || c['status'] == 'Assigned').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Complaints', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF6B00).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('$pendingCount Pending', style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (complaints.isEmpty) const Text('No complaints', style: TextStyle(color: Colors.white54))
          else ...complaints.take(3).map((c) => _buildComplaintCard(c)),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final isPending = complaint['status'] == 'Pending';
    final isAssigned = complaint['status'] == 'Assigned';
    final isResolved = complaint['status'] == 'Resolved';
    final createdAtStr = complaint['createdAt'];
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : DateTime.now();
    final category = complaint['category'] ?? 'General';
    final cardColor = _getCategoryColor(category);
    final priority = _getCategoryPriority(category);
    
    String? assignedCleanerName;
    if ((isAssigned || isResolved) && complaint['assignedCleanerId'] != null) {
      final cleanerList = (_cleaners ?? []).where((c) => c['_id'] == complaint['assignedCleanerId']).toList();
      if (cleanerList.isNotEmpty) {
        assignedCleanerName = cleanerList.first['name'];
      }
    }

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final diff = now.difference(createdAt ?? now);
        final isBreached = diff.inMinutes >= 3 && !isResolved;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: isBreached 
                ? Border.all(color: Colors.red, width: 2)
                : Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBreached)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('⚠️ SLA BREACHED - ESCALATED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(complaint['buildingName'] ?? '', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4)),
                        child: Text(priority, style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(category, style: TextStyle(color: cardColor, fontSize: 10)),
                    ]),
                    const SizedBox(height: 4),
                    Text(complaint['description'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Time elapsed: ${diff.inMinutes}m ${diff.inSeconds % 60}s', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ])),
                  if (isPending)
                    GestureDetector(
                      onTap: () => _showAssignCollectorDialog(complaint['_id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF00D4FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Assign', style: TextStyle(color: Color(0xFF00D4FF), fontSize: 10)),
                      ),
                    ),
                  if (isAssigned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Text('Assigned', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                          if (assignedCleanerName != null)
                            Text(assignedCleanerName, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9)),
                        ],
                      ),
                    ),
                  if (isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF00FF94).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Text('Resolved ✓', style: TextStyle(color: Color(0xFF00FF94), fontSize: 10, fontWeight: FontWeight.bold)),
                          if (assignedCleanerName != null)
                            Text('by $assignedCleanerName', style: const TextStyle(color: Color(0xFF00FF94), fontSize: 9)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  void _showAssignCollectorDialog(String complaintId) async {
    List<dynamic> cleaners = [];
    try {
      final res = await http.get(Uri.parse('$baseUrl/cleaners/workload'));
      if (res.statusCode == 200) {
        cleaners = jsonDecode(res.body);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching workload: $e'), backgroundColor: Colors.red));
      return;
    }

    if (!mounted) return;

    String? selectedCleanerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Smart Assignment', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a cleaner based on current workload:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cleaners.length,
                    itemBuilder: (context, index) {
                      final cleaner = cleaners[index];
                      final isRecommended = index == 0;
                      final isSelected = selectedCleanerId == cleaner['_id'];
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedCleanerId = cleaner['_id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00D4FF).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected 
                                ? Border.all(color: const Color(0xFF00D4FF), width: 2) 
                                : isRecommended 
                                    ? Border.all(color: const Color(0xFF00FF94), width: 1) 
                                    : Border.all(color: Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cleaner['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('Active Tasks: ${cleaner['activeTasksCount']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              if (isRecommended)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF00FF94).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                  child: const Text('⭐ Recommended', style: TextStyle(color: Color(0xFF00FF94), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: selectedCleanerId == null
                  ? null
                  : () => _assignCollector(complaintId, selectedCleanerId!, () => Navigator.pop(ctx)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
              child: const Text('Confirm', style: TextStyle(color: Color(0xFF0D0D0D))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignCollector(String complaintId, String cleanerId, VoidCallback onClose) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/complaints/$complaintId/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cleanerId': cleanerId}),
      );
      if (res.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collector Assigned Successfully'), backgroundColor: Color(0xFF00FF94)));
          onClose();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Hygiene Issue': return Colors.red.shade100;
      case 'Overflowing Bins': return Colors.orange.shade100;
      case 'Broken Bins': return Colors.grey.shade200;
      default: return Colors.blue.shade100;
    }
  }

  String _getCategoryPriority(String category) {
    switch (category) {
      case 'Hygiene Issue': return 'URGENT';
      case 'Overflowing Bins': return 'HIGH';
      default: return 'LOW';
    }
  }

  Widget _buildAlertsSection() {
    final alerts = _alerts ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Active Alerts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${alerts.length}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active alerts – all systems healthy ✓', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ))
          else
            ...alerts.map((a) => _buildAlertCard(a)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alertData) {
    final isCritical = alertData['type'] == 'CRITICAL_SCORE';
    final alertColor = isCritical ? Colors.red : const Color(0xFFFFD700);
    final alertIcon = isCritical ? Icons.trending_down : Icons.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(alertIcon, color: alertColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alertData['buildingName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(alertData['message'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSendWarningDialog(alertData),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.withValues(alpha: 0.3), const Color(0xFFFFD700).withValues(alpha: 0.3)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alertColor.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Warn', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendWarningDialog(Map<String, dynamic> alertData) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text('Send Warning', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Building: ${alertData['buildingName']}', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Alert: ${alertData['message']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Additional Note (optional):', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add specific instructions or context...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFFD700)),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16, color: Color(0xFF0D0D0D)),
            label: const Text('Send Warning', style: TextStyle(color: Color(0xFF0D0D0D), fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _sendWarning(alertData, noteController.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendWarning(Map<String, dynamic> alertData, String additionalNote) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/warnings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buildingId': alertData['buildingId'],
          'buildingName': alertData['buildingName'],
          'alertType': alertData['type'],
          'message': alertData['message'],
          'additionalNote': additionalNote,
        }),
      );
      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Warning sent to building successfully'),
            backgroundColor: Color(0xFFFFD700),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to send warning'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
