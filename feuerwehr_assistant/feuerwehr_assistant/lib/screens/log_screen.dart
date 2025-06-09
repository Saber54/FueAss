// ignore_for_file: unused_element, unused_import

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import '../providers/auth_provider.dart';

class LogEntry {
  final String id;
  String incidentType;
  String incidentName;
  DateTime alarmTime;
  String location;
  final List<String> logEntries;
  String lastEditor;
  DateTime lastEditTime;

  LogEntry({
    required this.id,
    required this.incidentType,
    required this.incidentName,
    required this.alarmTime,
    required this.location,
    this.logEntries = const [],
    this.lastEditor = '',
    DateTime? lastEditTime,
  }) : lastEditTime = lastEditTime ?? alarmTime;
}

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<LogEntry> _logEntries = [];
  List<String> _addressSuggestions = [];
  bool _isLoadingAddresses = false;
  bool _shouldFetchAddresses = false;
  final _searchDebouncer = Debouncer(milliseconds: 300);
  final _addressCache = <String, List<String>>{};

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchAddressSuggestions(String query, {int retryCount = 2}) async {
    if (query.length < 3) {
      if (mounted) setState(() => _addressSuggestions = []);
      return;
    }

    if (_addressCache.containsKey(query)) {
      if (mounted) setState(() => _addressSuggestions = _addressCache[query]!);
      return;
    }

    if (mounted) setState(() => _isLoadingAddresses = true);

    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/search')
              .replace(queryParameters: {
            'format': 'jsonv2',
            'q': query,
            'addressdetails': '1',
            'limit': '5',
            'countrycodes': 'de',
            'namedetails': '1',
          }),
          headers: {'User-Agent': 'FeuerwehrAssistant/1.0 (kontakt@ihre-domain.de)'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          final suggestions = data.map<String>((item) {
            final address = item['address'] as Map<String, dynamic>? ?? {};
            final namedetails = item['namedetails'] as Map<String, dynamic>? ?? {};
            
            final street = address['road'] ?? namedetails['name'] ?? '';
            final housenumber = address['house_number'] ?? '';
            final postcode = address['postcode'] ?? '';
            final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
            
            return '${street}${housenumber.isNotEmpty ? ' $housenumber' : ''}, $postcode $city'
                .replaceAll(' ,', ',')
                .trim();
          }).where((s) => s.isNotEmpty).toList();

          _addressCache[query] = suggestions;
          
          if (mounted) {
            setState(() {
              _addressSuggestions = suggestions;
              _isLoadingAddresses = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Fehler bei Adresssuche: $e');
        if (attempt == retryCount && mounted) {
          setState(() {
            _addressSuggestions = [];
            _isLoadingAddresses = false;
          });
        }
      }
    }
  }

  void _handleAddressSearch(String query) {
    if (_shouldFetchAddresses) {
      _searchDebouncer.run(() => _fetchAddressSuggestions(query));
    }
  }

  void _addNewEntry() {
    final newId = (_logEntries.isEmpty ? 1 : int.parse(_logEntries.last.id) + 1).toString();
    final newEntry = LogEntry(
      id: newId,
      incidentType: 'THL1',
      incidentName: '',
      alarmTime: DateTime.now(),
      location: '',
    );
    _navigateToDetail(newEntry, isNew: true);
  }

  void _navigateToDetail(LogEntry entry, {bool isNew = false}) async {
    final updatedEntry = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(
        builder: (context) => LogDetailScreen(
          entry: entry,
          addressSuggestions: _addressSuggestions,
          onAddressSearch: _handleAddressSearch,
          isLoadingAddresses: _isLoadingAddresses,
          isNewEntry: isNew,
        ),
      ),
    );

    if (updatedEntry != null && mounted) {
      setState(() {
        final index = _logEntries.indexWhere((e) => e.id == updatedEntry.id);
        if (index != -1) {
          _logEntries[index] = updatedEntry;
        } else {
          _logEntries.add(updatedEntry);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shouldFetchAddresses = true;
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    super.dispose();
  }

  Color _getIncidentColor(String type) {
    return type.contains('THL') 
      ? Colors.orange.shade100 
      : type.contains('Brand') 
        ? Colors.red.shade100 
        : Colors.blue.shade100;
  }

  Color _getTextColor(String type) {
    return type.contains('THL') 
      ? Colors.orange.shade800 
      : type.contains('Brand') 
        ? Colors.red.shade800 
        : Colors.blue.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = Provider.of<AuthProvider>(context).isMaster;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Einsatzübersicht')),
      body: _logEntries.isEmpty
          ? const Center(child: Text('Kein Einsatz bisher', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logEntries.length,
              itemBuilder: (ctx, index) {
                final entry = _logEntries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigateToDetail(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${entry.id}', style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: Colors.grey,
                                fontSize: 14
                              )),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getIncidentColor(entry.incidentType),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  entry.incidentType,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getTextColor(entry.incidentType),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            entry.incidentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.location,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(entry.alarmTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: isMaster
          ? FloatingActionButton(
              onPressed: _addNewEntry,
              child: const Icon(Icons.add),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }
}

class LogDetailScreen extends StatefulWidget {
  final LogEntry entry;
  final List<String> addressSuggestions;
  final Function(String) onAddressSearch;
  final bool isLoadingAddresses;
  final bool isNewEntry;

  const LogDetailScreen({
    required this.entry,
    required this.addressSuggestions,
    required this.onAddressSearch,
    required this.isLoadingAddresses,
    this.isNewEntry = false,
    super.key,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  late TextEditingController _logEntryController;
  late TextEditingController _editorController;
  late TextEditingController _incidentTypeController;
  late TextEditingController _incidentNameController;
  late TextEditingController _locationController;
  late DateTime _alarmTime;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _logEntryController = TextEditingController();
    _editorController = TextEditingController(text: widget.entry.lastEditor);
    _incidentTypeController = TextEditingController(text: widget.entry.incidentType);
    _incidentNameController = TextEditingController(text: widget.entry.incidentName);
    _locationController = TextEditingController(text: widget.entry.location);
    _alarmTime = widget.entry.alarmTime;
    
    if (_incidentTypeController.text.isEmpty) {
      _incidentTypeController.text = 'THL1';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _alarmTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _alarmTime) {
      _validateDateTime(picked, _alarmTime);
      setState(() {
        _alarmTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _alarmTime.hour,
          _alarmTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_alarmTime),
    );
    if (picked != null) {
      final newDateTime = DateTime(
        _alarmTime.year,
        _alarmTime.month,
        _alarmTime.day,
        picked.hour,
        picked.minute,
      );
      _validateDateTime(_alarmTime, newDateTime);
      setState(() {
        _alarmTime = newDateTime;
      });
    }
  }

  void _validateDateTime(DateTime date, DateTime newTime) {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      newTime.hour,
      newTime.minute,
    );

    if (selectedDateTime.isAfter(now)) {
      setState(() {
        _timeError = 'Alarmzeit darf nicht in der Zukunft liegen';
      });
    } else {
      setState(() {
        _timeError = null;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_alarmTime.isAfter(DateTime.now())) {
      setState(() {
        _timeError = 'Alarmzeit darf nicht in der Zukunft liegen';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler: Alarmzeit liegt in der Zukunft'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    final updatedEntry = LogEntry(
      id: widget.entry.id,
      incidentType: _incidentTypeController.text,
      incidentName: _incidentNameController.text,
      alarmTime: _alarmTime,
      location: _locationController.text,
      logEntries: [
        ...widget.entry.logEntries,
        if (_logEntryController.text.isNotEmpty) _logEntryController.text,
      ],
      lastEditor: _editorController.text,
      lastEditTime: DateTime.now(),
    );
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einsatz erfolgreich gespeichert'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Nur zurück navigieren wenn es sich um einen neuen Eintrag handelt
      if (widget.isNewEntry) {
        Navigator.pop(context, updatedEntry);
      } else {
        // Aktualisierten Eintrag zurückgeben ohne zu navigieren
        Navigator.pop(context, updatedEntry);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LogDetailScreen(
              entry: updatedEntry,
              addressSuggestions: widget.addressSuggestions,
              onAddressSearch: widget.onAddressSearch,
              isLoadingAddresses: widget.isLoadingAddresses,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Einsatz #${widget.entry.id}'),
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveEntry,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alarmzeit Auswahl
              const Text('Alarmzeit:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _timeError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _selectDate,
                    child: Text('${_alarmTime.day}.${_alarmTime.month}.${_alarmTime.year}'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _selectTime,
                    child: Text('${_alarmTime.hour.toString().padLeft(2, '0')}:${_alarmTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Einsatzart
              DropdownButtonFormField<String>(
                value: _incidentTypeController.text,
                decoration: const InputDecoration(
                  labelText: 'Einsatzart',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'THL1', child: Text('THL1')),
                  DropdownMenuItem(value: 'THL2', child: Text('THL2')),
                  DropdownMenuItem(value: 'Brand1', child: Text('Brand1')),
                  DropdownMenuItem(value: 'Brand2', child: Text('Brand2')),
                  DropdownMenuItem(value: 'Sonder', child: Text('Sonder')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _incidentTypeController.text = value;
                    });
                  }
                },
                validator: (value) => value == null ? 'Bitte auswählen' : null,
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _incidentNameController,
                decoration: const InputDecoration(
                  labelText: 'Einsatzname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Bitte eingeben' : null,
              ),
              
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  widget.onAddressSearch(textEditingValue.text);
                  return widget.addressSuggestions;
                },
                onSelected: (String selection) {
                  setState(() {
                    _locationController.text = selection;
                  });
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController fieldController,
                  FocusNode fieldFocusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  return TextFormField(
                    controller: _locationController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Einsatzort',
                      border: const OutlineInputBorder(),
                      suffixIcon: widget.isLoadingAddresses
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      widget.onAddressSearch(value);
                    },
                    validator: (value) => value!.isEmpty ? 'Bitte eingeben' : null,
                  );
                },
              ),
              
              const SizedBox(height: 24),
              const Text('Einsatztagebuch:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...widget.entry.logEntries.map((entry) {
                final index = widget.entry.logEntries.indexOf(entry);
                final entryTime = index == widget.entry.logEntries.length - 1 
                    ? widget.entry.lastEditTime 
                    : widget.entry.alarmTime.add(Duration(minutes: index * 5));
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${_formatFullDateTime(entryTime)} - ${widget.entry.lastEditor}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _editorController,
                decoration: const InputDecoration(
                  labelText: 'Bearbeiter',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Bitte eingeben' : null,
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _logEntryController,
                decoration: const InputDecoration(
                  labelText: 'Neuer Tagebucheintrag',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEntry,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}