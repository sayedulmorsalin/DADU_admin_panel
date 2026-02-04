import 'dart:math';

import 'package:flutter/material.dart';
import 'package:clipboard/clipboard.dart';
import '../services/database_service.dart';

class Draw extends StatefulWidget {
  const Draw({super.key});

  @override
  State<Draw> createState() => _DrawState();
}

class _DrawState extends State<Draw> {
  final DatabaseService _dbService = DatabaseService();
  final Random _random = Random();

  List<Map<String, dynamic>> receivers = [];
  Map<String, dynamic>? selectedReceiver;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceivers();
  }

  Future<void> _loadReceivers() async {
    setState(() {
      isLoading = true;
    });
    try {
      final data = await _dbService.getAllFreeGiftRecevier();
      setState(() {
        receivers = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("Failed to load users: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _drawWinner() {
    if (receivers.isEmpty) {
      _showSnackBar("No users available for gift draw.");
      return;
    }

    final winner = receivers[_random.nextInt(receivers.length)];
    setState(() {
      selectedReceiver = winner;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Gift Winner"),
          content: _buildWinnerContent(winner),
          actions: [
            TextButton(
              onPressed: () => _copyWinnerInfo(winner),
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeDraw() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Close Draw"),
          content: const Text(
            "This will remove all free gift products and reset all gift users. Continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Close Draw"),
            ),
          ],
        );
      },
    );

    if (shouldClose != true) return;

    try {
      await _dbService.closeGiftDraw();
      setState(() {
        selectedReceiver = null;
      });
      await _loadReceivers();
      _showSnackBar("Draw closed successfully.");
    } catch (e) {
      _showSnackBar("Failed to close draw: $e");
    }
  }

  Widget _buildWinnerContent(Map<String, dynamic> winner) {
    final name = winner['name'] ?? winner['user_name'] ?? 'Unknown';
    final email = winner['email'] ?? winner['user_email'] ?? 'N/A';
    final phone = winner['phone'] ?? winner['user_phone'] ?? 'N/A';
    final address = winner['address'] ?? 'N/A';
    final thana = winner['thana'] ?? 'N/A';
    final district = winner['district'] ?? 'N/A';
    final id = winner['id'] ?? 'N/A';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Name: $name"),
        Text("Email: $email"),
        Text("Phone: $phone"),
        Text("Address: $address"),
        Text("Thana: $thana"),
        Text("District: $district"),
        Text("User ID: $id"),
      ],
    );
  }

  Future<void> _copyWinnerInfo(Map<String, dynamic> winner) async {
    final name = winner['name'] ?? winner['user_name'] ?? 'Unknown';
    final email = winner['email'] ?? winner['user_email'] ?? 'N/A';
    final phone = winner['phone'] ?? winner['user_phone'] ?? 'N/A';
    final address = winner['address'] ?? 'N/A';
    final thana = winner['thana'] ?? 'N/A';
    final district = winner['district'] ?? 'N/A';
    final id = winner['id'] ?? 'N/A';

    final summary = [
      "Name: $name",
      "Email: $email",
      "Phone: $phone",
      "Address: $address",
      "Thana: $thana",
      "District: $district",
      "User ID: $id",
    ].join('\n');

    try {
      await FlutterClipboard.copy(summary);
      _showSnackBar("Winner info copied.");
    } catch (e) {
      _showSnackBar("Failed to copy: $e");
    }
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: $text", style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Draw Gift",
          style: TextStyle(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadReceivers,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : receivers.isEmpty
              ? const Center(child: Text("No gift receivers found."))
              : Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Total Receivers: ${receivers.length}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _drawWinner,
                              icon: const Icon(Icons.card_giftcard),
                              label: const Text("Draw"),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _closeDraw,
                              icon: const Icon(Icons.close),
                              label: const Text("Close Draw"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedReceiver != null)
                      Card(
                        color: Colors.green.shade50,
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Last Winner",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInfoRow(
                                "Name",
                                selectedReceiver!['name'] ??
                                    selectedReceiver!['user_name'],
                              ),
                              _buildInfoRow(
                                "Email",
                                selectedReceiver!['email'] ??
                                    selectedReceiver!['user_email'],
                              ),
                              _buildInfoRow(
                                "Phone",
                                selectedReceiver!['phone'] ??
                                    selectedReceiver!['user_phone'],
                              ),
                              _buildInfoRow(
                                "Address",
                                selectedReceiver!['address'],
                              ),
                              _buildInfoRow(
                                "Thana",
                                selectedReceiver!['thana'],
                              ),
                              _buildInfoRow(
                                "District",
                                selectedReceiver!['district'],
                              ),
                              _buildInfoRow("User ID", selectedReceiver!['id']),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _copyWinnerInfo(selectedReceiver!),
                                  icon: const Icon(
                                    Icons.content_copy,
                                    size: 18,
                                  ),
                                  label: const Text("Copy All"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: receivers.length,
                        itemBuilder: (context, index) {
                          final receiver = receivers[index];
                          final name =
                              receiver['name'] ??
                              receiver['user_name'] ??
                              'Unknown';
                          final email =
                              receiver['email'] ??
                              receiver['user_email'] ??
                              'N/A';
                          final phone =
                              receiver['phone'] ??
                              receiver['user_phone'] ??
                              'N/A';
                          final address = receiver['address'] ?? 'N/A';
                          final thana = receiver['thana'] ?? 'N/A';
                          final district = receiver['district'] ?? 'N/A';
                          final id = receiver['id'] ?? 'N/A';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          name.toString().trim().isEmpty
                                              ? "?"
                                              : name
                                                  .toString()
                                                  .trim()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name.toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _buildInfoRow("Email", email),
                                  _buildInfoRow("Phone", phone),
                                  _buildInfoRow("Address", address),
                                  _buildInfoRow("Thana", thana),
                                  _buildInfoRow("District", district),
                                  _buildInfoRow("User ID", id),
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
    );
  }
}
