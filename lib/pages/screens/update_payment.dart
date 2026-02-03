import 'package:dadu_admin_panel/pages/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdatePayment extends StatefulWidget {
  const UpdatePayment({super.key});

  @override
  State<UpdatePayment> createState() => _UpdatePaymentState();
}

class _UpdatePaymentState extends State<UpdatePayment> {
  DatabaseService dbService = DatabaseService();
  static const String _prefsKeyNumbers = 'payment_numbers';

  final TextEditingController _paymentNumberController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  List<String> _paymentEntries = <String>[];
  String? _selectedEntry;

  @override
  void initState() {
    super.initState();
    _loadPaymentNumbers();
  }

  Future<void> _loadPaymentNumbers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> stored =
        prefs.getStringList(_prefsKeyNumbers) ?? <String>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _paymentEntries = stored;
      if (_paymentEntries.isNotEmpty) {
        _selectedEntry ??= _paymentEntries.first;
      }
    });
  }

  Future<void> _addPaymentNumber() async {
    final String number = _paymentNumberController.text.trim();
    final String name = _nameController.text.trim();
    if (number.isEmpty || name.isEmpty) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> updated = List<String>.from(_paymentEntries);
    final String entry = '$name|$number';
    if (!updated.contains(entry)) {
      updated.add(entry);
      await prefs.setStringList(_prefsKeyNumbers, updated);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _paymentEntries = updated;
      _selectedEntry = entry;
    });

    _paymentNumberController.clear();
    _nameController.clear();
  }

  Future<void> _resetAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyNumbers);
    if (!mounted) {
      return;
    }
    setState(() {
      _paymentEntries = <String>[];
      _selectedEntry = null;
    });
  }

  String _entryLabel(String entry) {
    final List<String> parts = entry.split('|');
    if (parts.length >= 2) {
      return parts.first;
    }
    return entry;
  }

  String _entryNumber(String entry) {
    final List<String> parts = entry.split('|');
    if (parts.length >= 2) {
      return parts[1];
    }
    return entry;
  }

  @override
  void dispose() {
    _paymentNumberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Payment"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Payment Numbers",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Add a name and number, then choose from the list.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _paymentNumberController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Payment Number',
                                prefixIcon: const Icon(Icons.payments_outlined),
                                filled: true,
                                fillColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _addPaymentNumber,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _resetAll,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
                                    side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<String>(
                          value: _selectedEntry,
                          items:
                              _paymentEntries
                                  .map(
                                    (String value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(_entryLabel(value)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedEntry = value;
                            });
                            try {
                              final String entry = value ?? '';
                              dbService.setPaymentNumber(_entryNumber(entry));
                            } on Exception catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Name',
                            prefixIcon: const Icon(Icons.list_alt_outlined),
                            filled: true,
                            fillColor:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
