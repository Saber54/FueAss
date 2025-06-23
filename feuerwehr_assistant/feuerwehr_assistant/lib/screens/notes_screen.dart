import 'package:flutter/material.dart';
import 'dart:async';

class Note {
  String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime? reminderDateTime;
  Duration? reminderDuration;
  bool isReminderActive;
  bool hasNotifiedReminder;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.reminderDateTime,
    this.reminderDuration,
    this.isReminderActive = false,
    this.hasNotifiedReminder = false,
  });
}

class NotesScreen extends StatefulWidget {
  final Function(bool) onReminderStatusChanged;

  const NotesScreen({super.key, required this.onReminderStatusChanged});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> notes = [];
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _startReminderTimer();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    bool hasActiveReminder = false;
    final now = DateTime.now();

    for (var note in notes) {
      if (note.isReminderActive && !note.hasNotifiedReminder) {
        bool shouldNotify = false;

        if (note.reminderDateTime != null) {
          shouldNotify = now.isAfter(note.reminderDateTime!);
        } else if (note.reminderDuration != null) {
          final targetTime = note.createdAt.add(note.reminderDuration!);
          shouldNotify = now.isAfter(targetTime);
        }

        if (shouldNotify) {
          hasActiveReminder = true;
          break;
        }
      }
    }

    widget.onReminderStatusChanged(hasActiveReminder);
  }

  void _acknowledgeReminder(String noteId) {
    setState(() {
      final noteIndex = notes.indexWhere((note) => note.id == noteId);
      if (noteIndex != -1) {
        notes[noteIndex].hasNotifiedReminder = true;
        notes[noteIndex].isReminderActive = false;
      }
    });
    _checkReminders();
  }

  void _addNote() {
    showDialog(
      context: context,
      builder:
          (context) => _NoteDialog(
            onSave: (title, content, reminderDateTime, reminderDuration) {
              setState(() {
                notes.add(
                  Note(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    content: content,
                    createdAt: DateTime.now(),
                    reminderDateTime: reminderDateTime,
                    reminderDuration: reminderDuration,
                    isReminderActive:
                        reminderDateTime != null || reminderDuration != null,
                  ),
                );
              });
              _checkReminders();
            },
          ),
    );
  }

  void _editNote(Note note) {
    showDialog(
      context: context,
      builder:
          (context) => _NoteDialog(
            note: note,
            onSave: (title, content, reminderDateTime, reminderDuration) {
              setState(() {
                final noteIndex = notes.indexWhere((n) => n.id == note.id);
                if (noteIndex != -1) {
                  notes[noteIndex].title = title;
                  notes[noteIndex].content = content;
                  notes[noteIndex].reminderDateTime = reminderDateTime;
                  notes[noteIndex].reminderDuration = reminderDuration;
                  notes[noteIndex].isReminderActive =
                      reminderDateTime != null || reminderDuration != null;
                  notes[noteIndex].hasNotifiedReminder = false;
                }
              });
              _checkReminders();
            },
          ),
    );
  }

  void _deleteNote(String noteId) {
    setState(() {
      notes.removeWhere((note) => note.id == noteId);
    });
    _checkReminders();
  }

  bool _isReminderDue(Note note) {
    if (!note.isReminderActive || note.hasNotifiedReminder) return false;

    final now = DateTime.now();
    if (note.reminderDateTime != null) {
      return now.isAfter(note.reminderDateTime!);
    } else if (note.reminderDuration != null) {
      final targetTime = note.createdAt.add(note.reminderDuration!);
      return now.isAfter(targetTime);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          notes.isEmpty
              ? const Center(
                child: Text(
                  'Keine Notizen vorhanden\nTippe auf + um eine neue Notiz zu erstellen',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final isReminderDue = _isReminderDue(note);

                  return Card(
                    color: isReminderDue ? Colors.red.withOpacity(0.1) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border:
                            isReminderDue
                                ? Border.all(color: Colors.red, width: 2)
                                : null,
                      ),
                      child: ListTile(
                        title: Text(
                          note.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isReminderDue ? Colors.red : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Erstellt: ${_formatDateTime(note.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (note.isReminderActive)
                              Text(
                                _getReminderText(note),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isReminderDue
                                          ? Colors.red
                                          : Colors.orange,
                                  fontWeight:
                                      isReminderDue ? FontWeight.bold : null,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isReminderDue)
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () => _acknowledgeReminder(note.id),
                                tooltip: 'Erinnerung bestätigen',
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _editNote(note);
                                    break;
                                  case 'delete':
                                    _deleteNote(note.id);
                                    break;
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text('Bearbeiten'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Löschen'),
                                        ],
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                        onTap: () => _editNote(note),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getReminderText(Note note) {
    if (note.reminderDateTime != null) {
      return 'Erinnerung: ${_formatDateTime(note.reminderDateTime!)}';
    } else if (note.reminderDuration != null) {
      final targetTime = note.createdAt.add(note.reminderDuration!);
      return 'Erinnerung: ${_formatDateTime(targetTime)}';
    }
    return '';
  }
}

class _NoteDialog extends StatefulWidget {
  final Note? note;
  final Function(String, String, DateTime?, Duration?) onSave;

  const _NoteDialog({this.note, required this.onSave});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  DateTime? _selectedDateTime;
  Duration? _selectedDuration;
  bool _hasReminder = false;
  bool _useDateTime = true; // true für Datum/Zeit, false für Zeitspanne

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _selectedDateTime = widget.note?.reminderDateTime;
    _selectedDuration = widget.note?.reminderDuration;
    _hasReminder = widget.note?.isReminderActive ?? false;
    _useDateTime =
        widget.note?.reminderDateTime != null ||
        (widget.note?.reminderDateTime == null &&
            widget.note?.reminderDuration == null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateTime ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDateTime ?? DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _selectedDuration = null;
        });
      }
    }
  }

  void _selectDuration() {
    showDialog(
      context: context,
      builder:
          (context) => _DurationPickerDialog(
            initialDuration: _selectedDuration ?? const Duration(hours: 1),
            onDurationSelected: (duration) {
              setState(() {
                _selectedDuration = duration;
                _selectedDateTime = null;
              });
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'Neue Notiz' : 'Notiz bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Inhalt',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Erinnerung aktivieren'),
              value: _hasReminder,
              onChanged: (value) {
                setState(() {
                  _hasReminder = value;
                  if (!value) {
                    _selectedDateTime = null;
                    _selectedDuration = null;
                  }
                });
              },
            ),
            if (_hasReminder) ...[
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'datetime',
                    label: Text('Datum/Zeit'),
                    icon: Icon(Icons.calendar_today),
                  ),
                  ButtonSegment(
                    value: 'duration',
                    label: Text('Zeitspanne'),
                    icon: Icon(Icons.timer),
                  ),
                ],
                selected: {_useDateTime ? 'datetime' : 'duration'},
                onSelectionChanged: (selection) {
                  setState(() {
                    _useDateTime = selection.first == 'datetime';
                    _selectedDateTime = null;
                    _selectedDuration = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_useDateTime) ...[
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Erinnerungsdatum und -zeit'),
                  subtitle: Text(
                    _selectedDateTime != null
                        ? '${_selectedDateTime!.day.toString().padLeft(2, '0')}.${_selectedDateTime!.month.toString().padLeft(2, '0')}.${_selectedDateTime!.year} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'
                        : 'Nicht ausgewählt',
                  ),
                  onTap: _selectDateTime,
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Zeitspanne nach Erstellung'),
                  subtitle: Text(
                    _selectedDuration != null
                        ? _formatDuration(_selectedDuration!)
                        : 'Nicht ausgewählt',
                  ),
                  onTap: _selectDuration,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bitte geben Sie einen Titel ein'),
                ),
              );
              return;
            }

            widget.onSave(
              _titleController.text.trim(),
              _contentController.text.trim(),
              _hasReminder && _useDateTime ? _selectedDateTime : null,
              _hasReminder && !_useDateTime ? _selectedDuration : null,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
}

class _DurationPickerDialog extends StatefulWidget {
  final Duration initialDuration;
  final Function(Duration) onDurationSelected;

  const _DurationPickerDialog({
    required this.initialDuration,
    required this.onDurationSelected,
  });

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours;
    _minutes = widget.initialDuration.inMinutes % 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zeitspanne auswählen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Stunden'),
                    DropdownButton<int>(
                      value: _hours,
                      items:
                          List.generate(24, (index) => index)
                              .map(
                                (hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text('$hour'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _hours = value ?? 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    const Text('Minuten'),
                    DropdownButton<int>(
                      value: _minutes,
                      items:
                          [0, 15, 30, 45]
                              .map(
                                (minute) => DropdownMenuItem(
                                  value: minute,
                                  child: Text('$minute'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _minutes = value ?? 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_hours == 0 && _minutes == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bitte wählen Sie eine gültige Zeitspanne'),
                ),
              );
              return;
            }

            widget.onDurationSelected(
              Duration(hours: _hours, minutes: _minutes),
            );
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
