import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../utils/constants.dart';
import 'login_screen.dart';

class CleanerDashboard extends StatefulWidget {
  final String cleanerId;
  const CleanerDashboard({super.key, required this.cleanerId});

  @override
  State<CleanerDashboard> createState() => _CleanerDashboardState();
}

class _CleanerDashboardState extends State<CleanerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  String? _selectedBuilding;
  
  final _wetController = TextEditingController();
  final _dryController = TextEditingController();
  final _rejectController = TextEditingController();
  
  bool _isSubmitting = false;
  bool _isLoadingBuildings = true;

  List<dynamic> _buildings = [];

  List<dynamic> _assignedTasks = [];
  bool _isLoadingTasks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBuildings();
    _loadAssignedTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wetController.dispose();
    _dryController.dispose();
    _rejectController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/buildings'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _buildings = jsonDecode(res.body);
            _isLoadingBuildings = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBuildings = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading buildings: $e')));
      }
    }
  }

  Future<void> _loadAssignedTasks() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/complaints/cleaner/${widget.cleanerId}'));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _assignedTasks = jsonDecode(res.body);
            _isLoadingTasks = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading tasks: $e')));
      }
    }
  }

  Future<void> _resolveTask(String complaintId) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/complaints/$complaintId/resolve'));
      if (res.statusCode == 200) {
        _loadAssignedTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task marked as resolved'), backgroundColor: Color(0xFF00FF94)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resolve task'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resolving task: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _submitWasteLog() async {
    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a building'), backgroundColor: Colors.red),
      );
      return;
    }

    final wet = double.tryParse(_wetController.text) ?? 0.0;
    final dry = double.tryParse(_dryController.text) ?? 0.0;
    final reject = double.tryParse(_rejectController.text) ?? 0.0;

    if (wet <= 0 && dry <= 0 && reject <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one valid weight'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/waste'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buildingId': _selectedBuilding,
          'wetWeight': wet,
          'dryWeight': dry,
          'rejectWeight': reject,
          'cleanerId': widget.cleanerId,
        }),
      );

      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waste Logged Successfully!'), backgroundColor: Color(0xFF00FF94)),
          );
          _wetController.clear();
          _dryController.clear();
          _rejectController.clear();
          setState(() {
            _selectedBuilding = null;
          });
        }
      } else {
        final error = jsonDecode(res.body)['error'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Cleaner Hub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFF6B00)),
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
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Log Daily Waste', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Assigned Tasks', icon: Icon(Icons.task_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLogWasteTab(), _buildAssignedTasksTab()],
      ),
    );
  }

  Widget _buildLogWasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Building', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: _isLoadingBuildings 
                ? const Padding(
                    padding: EdgeInsets.all(12), 
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFFF6B00), strokeWidth: 2)))
                  )
                : DropdownButton<String>(
                    value: _selectedBuilding,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A1A),
                    underline: const SizedBox(),
                    hint: const Text('Choose building...', style: TextStyle(color: Colors.white54)),
                    items: _buildings.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['_id'],
                        child: Text(b['name'], style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBuilding = val),
                  ),
            ),
            const SizedBox(height: 24),
            _buildWeightInput('Wet Waste (kg)', _wetController, const Color(0xFF00FF94)),
            const SizedBox(height: 16),
            _buildWeightInput('Dry Waste (kg)', _dryController, const Color(0xFF00D4FF)),
            const SizedBox(height: 16),
            _buildWeightInput('Reject Waste (kg)', _rejectController, const Color(0xFFFF6B00)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitWasteLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Collection', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightInput(String label, TextEditingController controller, Color focusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 2),
            ),
            suffixText: 'kg',
            suffixStyle: const TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedTasksTab() {
    if (_isLoadingTasks) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    if (_assignedTasks.isEmpty) {
      return const Center(
        child: Text('No assigned tasks right now. Great job!', style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignedTasks.length,
      itemBuilder: (context, index) {
        final complaint = _assignedTasks[index];
        final isResolved = complaint['status'] == 'Resolved';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    complaint['buildingName'] ?? 'Unknown Building',
                    style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResolved 
                        ? const Color(0xFF00FF94).withValues(alpha: 0.2)
                        : const Color(0xFFFF6B00).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      complaint['status'] ?? 'Unknown',
                      style: TextStyle(color: isResolved ? const Color(0xFF00FF94) : const Color(0xFFFF6B00), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (complaint['category'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                    child: Text(complaint['category'], style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
                ),
              Text(
                complaint['description'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (!isResolved)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _resolveTask(complaint['_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF94),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Mark Resolved',
                      style: TextStyle(color: Color(0xFF0D0D0D), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
