// ignore_for_file: unused_element, unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crypto/crypto.dart';
import '../providers/auth_provider.dart';

class CommanderEntry {
  final String name;
  final DateTime timestamp;

  CommanderEntry({required this.name, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'name': name,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CommanderEntry.fromJson(Map<String, dynamic> json) => CommanderEntry(
    name: json['name'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class LogEntry {
  final String id;
  String incidentType;
  String incidentName;
  DateTime alarmTime;
  String location;
  final List<String> logEntries;
  final List<DateTime> logTimestamps;
  final List<String> logEditors;
  String lastEditor;
  DateTime lastEditTime;
  final List<CommanderEntry> commanders;

  LogEntry({
    required this.id,
    required this.incidentType,
    required this.incidentName,
    required this.alarmTime,
    required this.location,
    this.logEntries = const [],
    this.logTimestamps = const [],
    this.logEditors = const [],
    this.lastEditor = '',
    DateTime? lastEditTime,
    this.commanders = const [],
  }) : lastEditTime = lastEditTime ?? alarmTime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'incidentType': incidentType,
    'incidentName': incidentName,
    'alarmTime': alarmTime.toIso8601String(),
    'location': location,
    'logEntries': logEntries,
    'logTimestamps': logTimestamps.map((t) => t.toIso8601String()).toList(),
    'logEditors': logEditors,
    'lastEditor': lastEditor,
    'lastEditTime': lastEditTime.toIso8601String(),
    'commanders': commanders.map((c) => c.toJson()).toList(),
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    incidentType: json['incidentType'],
    incidentName: json['incidentName'],
    alarmTime: DateTime.parse(json['alarmTime']),
    location: json['location'],
    logEntries: List<String>.from(json['logEntries'] ?? []),
    logTimestamps:
        (json['logTimestamps'] as List?)
            ?.map((t) => DateTime.parse(t))
            .toList() ??
        [],
    logEditors: List<String>.from(json['logEditors'] ?? []),
    lastEditor: json['lastEditor'] ?? '',
    lastEditTime:
        json['lastEditTime'] != null
            ? DateTime.parse(json['lastEditTime'])
            : DateTime.now(),
    commanders:
        (json['commanders'] as List?)
            ?.map((c) => CommanderEntry.fromJson(c))
            .toList() ??
        [],
  );

  LogEntry copyWith({
    String? incidentType,
    String? incidentName,
    DateTime? alarmTime,
    String? location,
    List<String>? logEntries,
    List<DateTime>? logTimestamps,
    List<String>? logEditors,
    String? lastEditor,
    DateTime? lastEditTime,
    List<CommanderEntry>? commanders,
  }) => LogEntry(
    id: id,
    incidentType: incidentType ?? this.incidentType,
    incidentName: incidentName ?? this.incidentName,
    alarmTime: alarmTime ?? this.alarmTime,
    location: location ?? this.location,
    logEntries: logEntries ?? this.logEntries,
    logTimestamps: logTimestamps ?? this.logTimestamps,
    logEditors: logEditors ?? this.logEditors,
    lastEditor: lastEditor ?? this.lastEditor,
    lastEditTime: lastEditTime ?? this.lastEditTime,
    commanders: commanders ?? this.commanders,
  );
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

  @override
  void initState() {
    super.initState();
    _loadLogEntries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shouldFetchAddresses = true;
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    super.dispose();
  }

  // Speichern und Laden der Einsätze
  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/feuerwehr_logs.json');
  }

  Future<void> _saveLogEntries() async {
    try {
      final file = await _getLogFile();
      final data = {
        'entries': _logEntries.map((e) => e.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'checksum': _generateChecksum(_logEntries),
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadLogEntries() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents);

        // Validiere Checksum
        final entries =
            (data['entries'] as List).map((e) => LogEntry.fromJson(e)).toList();
        final expectedChecksum = _generateChecksum(entries);
        final storedChecksum = data['checksum'];

        if (expectedChecksum != storedChecksum) {
          throw Exception(
            'Datei wurde manipuliert - Checksum stimmt nicht überein',
          );
        }

        setState(() {
          _logEntries = entries;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateChecksum(List<LogEntry> entries) {
    final data = entries.map((e) => e.toJson()).toList();
    final bytes = utf8.encode(json.encode(data));
    return sha256.convert(bytes).toString();
  }

  // PDF-Export
  Future<void> _exportToPDF(LogEntry entry) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'EINSATZPROTOKOLL',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Einsatz #${entry.id}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Einsatzdaten
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EINSATZDATEN',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Einsatzart: ${entry.incidentType}'),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Alarmzeit: ${_formatDateTime(entry.alarmTime)}',
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('Einsatzname: ${entry.incidentName}'),
                    pw.SizedBox(height: 5),
                    pw.Text('Einsatzort: ${entry.location}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Einsatzleiter
              if (entry.commanders.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EINSATZLEITER',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 10),
                      ...entry.commanders.map(
                        (commander) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text(
                            '${_formatDateTime(commander.timestamp)}: ${commander.name}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Einsatztagebuch
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EINSATZTAGEBUCH',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    ...List.generate(entry.logEntries.length, (index) {
                      final logEntry = entry.logEntries[index];
                      final timestamp =
                          index < entry.logTimestamps.length
                              ? entry.logTimestamps[index]
                              : entry.alarmTime.add(
                                Duration(minutes: index * 5),
                              );
                      final editor =
                          index < entry.logEditors.length
                              ? entry.logEditors[index]
                              : entry.lastEditor;

                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(logEntry),
                            pw.SizedBox(height: 5),
                            pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                '${_formatDateTime(timestamp)} - $editor',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              pw.Spacer(),

              // Unterschriftenfelder - KORRIGIERT
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 40),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(
                            height: 60,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide()),
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Unterschrift Einsatzleiter',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 40),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(
                            height: 60,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide()),
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Unterschrift Führungsassistent',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Fußzeile
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20),
                child: pw.Text(
                  'Erstellt am: ${_formatDateTime(DateTime.now())} | Dieses Dokument ist schreibgeschützt',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ];
          },
        ),
      );

      // PDF schreibgeschützt machen
      final bytes = await pdf.save();

      // PDF anzeigen/teilen
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name:
            'Einsatz_${entry.id}_${entry.incidentName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim PDF-Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchAddressSuggestions(
    String query, {
    int retryCount = 2,
  }) async {
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
        final response = await http
            .get(
              Uri.parse('https://nominatim.openstreetmap.org/search').replace(
                queryParameters: {
                  'format': 'jsonv2',
                  'q': query,
                  'addressdetails': '1',
                  'limit': '5',
                  'countrycodes': 'de',
                  'namedetails': '1',
                },
              ),
              headers: {
                'User-Agent': 'FeuerwehrAssistant/1.0 (kontakt@ihre-domain.de)',
              },
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          final suggestions =
              data
                  .map<String>((item) {
                    final address =
                        item['address'] as Map<String, dynamic>? ?? {};
                    final namedetails =
                        item['namedetails'] as Map<String, dynamic>? ?? {};

                    final street = address['road'] ?? namedetails['name'] ?? '';
                    final housenumber = address['house_number'] ?? '';
                    final postcode = address['postcode'] ?? '';
                    final city =
                        address['city'] ??
                        address['town'] ??
                        address['village'] ??
                        '';

                    return '${street}${housenumber.isNotEmpty ? ' $housenumber' : ''}, $postcode $city'
                        .replaceAll(' ,', ',')
                        .trim();
                  })
                  .where((s) => s.isNotEmpty)
                  .toList();

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
    final newId =
        (_logEntries.isEmpty ? 1 : int.parse(_logEntries.last.id) + 1)
            .toString();
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
        builder:
            (context) => LogDetailScreen(
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
      await _saveLogEntries();
    }
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
      appBar: AppBar(
        title: const Text('Einsatzübersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogEntries,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body:
          _logEntries.isEmpty
              ? const Center(
                child: Text(
                  'Kein Einsatz bisher',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
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
                                Text(
                                  '#${entry.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getIncidentColor(
                                      entry.incidentType,
                                    ),
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
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  onPressed: () => _exportToPDF(entry),
                                  tooltip: 'Als PDF exportieren',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              entry.incidentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.location,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey,
                                ),
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
                            if (entry.commanders.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'EL: ${entry.commanders.last.name}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton:
          isMaster
              ? FloatingActionButton(
                onPressed: _addNewEntry,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

// LogDetailScreen mit Einsatzleiter-Verwaltung
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
  late TextEditingController _commanderController;
  late DateTime _alarmTime;
  late List<CommanderEntry> _commanders;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _logEntryController = TextEditingController();
    _editorController = TextEditingController(text: widget.entry.lastEditor);
    _incidentTypeController = TextEditingController(
      text: widget.entry.incidentType,
    );
    _incidentNameController = TextEditingController(
      text: widget.entry.incidentName,
    );
    _locationController = TextEditingController(text: widget.entry.location);
    _commanderController = TextEditingController();
    _alarmTime = widget.entry.alarmTime;
    _commanders = List.from(widget.entry.commanders);

    if (_incidentTypeController.text.isEmpty) {
      _incidentTypeController.text = 'THL1';
    }
  }

  @override
  void dispose() {
    _logEntryController.dispose();
    _editorController.dispose();
    _incidentTypeController.dispose();
    _incidentNameController.dispose();
    _locationController.dispose();
    _commanderController.dispose();
    super.dispose();
  }

  void _addCommander() {
    if (_commanderController.text.isNotEmpty) {
      setState(() {
        _commanders.add(
          CommanderEntry(
            name: _commanderController.text,
            timestamp: DateTime.now(),
          ),
        );
        _commanderController.clear();
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

    final newLogEntries = List<String>.from(widget.entry.logEntries);
    final newLogTimestamps = List<DateTime>.from(widget.entry.logTimestamps);
    final newLogEditors = List<String>.from(widget.entry.logEditors);

    if (_logEntryController.text.isNotEmpty) {
      newLogEntries.add(_logEntryController.text);
      newLogTimestamps.add(DateTime.now());
      newLogEditors.add(_editorController.text);
    }

    final updatedEntry = widget.entry.copyWith(
      incidentType: _incidentTypeController.text,
      incidentName: _incidentNameController.text,
      alarmTime: _alarmTime,
      location: _locationController.text,
      logEntries: newLogEntries,
      logTimestamps: newLogTimestamps,
      logEditors: newLogEditors,
      lastEditor: _editorController.text,
      lastEditTime: DateTime.now(),
      commanders: _commanders,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einsatz erfolgreich gespeichert'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, updatedEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Einsatz #${widget.entry.id}'),
        actions: [
          IconButton(
            icon:
                _isSaving
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
              const Text(
                'Alarmzeit:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _timeError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _selectDate,
                    child: Text(
                      '${_alarmTime.day}.${_alarmTime.month}.${_alarmTime.year}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _selectTime,
                    child: Text(
                      '${_alarmTime.hour.toString().padLeft(2, '0')}:${_alarmTime.minute.toString().padLeft(2, '0')}',
                    ),
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
              // Einsatzort mit Autocomplete
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
                      suffixIcon:
                          widget.isLoadingAddresses
                              ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : null,
                    ),
                    onChanged: (value) => widget.onAddressSearch(value),
                    validator:
                        (value) => value!.isEmpty ? 'Bitte eingeben' : null,
                  );
                },
              ),

              const SizedBox(height: 24),

              // Einsatzleiter Verwaltung
              const Text(
                'Einsatzleiter:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _commanderController,
                      decoration: const InputDecoration(
                        labelText: 'Neuer Einsatzleiter',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCommander,
                    child: const Text('Hinzufügen'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Liste der Einsatzleiter
              ..._commanders.map(
                (commander) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    title: Text(commander.name),
                    subtitle: Text(_formatDateTime(commander.timestamp)),
                    leading: const Icon(Icons.person),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _commanders.remove(commander);
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Einsatztagebuch:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Bestehende Tagebucheinträge
              ...List.generate(widget.entry.logEntries.length, (index) {
                final entry = widget.entry.logEntries[index];
                final timestamp =
                    index < widget.entry.logTimestamps.length
                        ? widget.entry.logTimestamps[index]
                        : widget.entry.alarmTime.add(
                          Duration(minutes: index * 5),
                        );
                final editor =
                    index < widget.entry.logEditors.length
                        ? widget.entry.logEditors[index]
                        : widget.entry.lastEditor;

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
                            '${_formatDateTime(timestamp)} - $editor',
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
                  child:
                      _isSaving
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
