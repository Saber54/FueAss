import 'package:flutter/material.dart';

class Vehicle {
  String radioId;
  String crew;
  String agt;
  String type;
  String notes;
  String status;

  Vehicle({
    required this.radioId,
    required this.crew,
    required this.agt,
    required this.type,
    required this.notes,
    required this.status,
  });
}

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final List<Vehicle> _vehicles = [];
  int _calculatedPortions = 0;

  void _addVehicle() {
    final newVehicle = Vehicle(
      radioId: '',
      crew: '',
      agt: '',
      type: '',
      notes: '',
      status: '4',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fahrzeug hinzufügen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Funkrufname'),
                onChanged: (value) => newVehicle.radioId = value,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Besatzung (Format: 0/1/0/1)',
                  hintText: 'Letzte Zahl = Gesamtanzahl',
                ),
                onChanged: (value) => newVehicle.crew = value,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'AGT (Atemschutzgeräteträger)',
                  hintText: 'Anzahl eingeben',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => newVehicle.agt = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Typ'),
                onChanged: (value) => newVehicle.type = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Notizen'),
                onChanged: (value) => newVehicle.notes = value,
              ),
              DropdownButtonFormField<String>(
                value: newVehicle.status,
                items: List.generate(9, (index) => (index + 1).toString())
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    newVehicle.status = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _vehicles.add(newVehicle);
                _calculatePortions();
              });
              Navigator.pop(context);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _deleteVehicle(int index) {
    setState(() {
      _vehicles.removeAt(index);
      _calculatePortions();
    });
  }

  void _calculatePortions() {
    setState(() {
      _calculatedPortions = (_totalCrew * 1.07).ceil();
    });
  }

  int get _totalCrew {
    return _vehicles.fold(0, (sum, vehicle) {
      // Versuche zuerst die Besatzung als direkte Zahl zu parsen
      final directNumber = int.tryParse(vehicle.crew);
      if (directNumber != null) {
        return sum + directNumber;
      }

      // Prüfe das spezielle Schrägstrich-Format
      final parts = vehicle.crew.split('/');
      if (parts.length >= 4) {
        final total = int.tryParse(parts[3]) ?? 0;
        return sum + total;
      }

      return sum;
    });
  }

  int get _totalAGT {
    return _vehicles.fold(0, (sum, vehicle) {
      final agt = int.tryParse(vehicle.agt) ?? 0;
      return sum + agt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fahrzeuge & Essensbestellung',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                      children: [
                        const TextSpan(text: 'Fahrzeuge: '),
                        TextSpan(
                          text: '${_vehicles.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' | '),
                        const TextSpan(text: 'Einsatzkräfte: '),
                        TextSpan(
                          text: '$_totalCrew',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' | '),
                        const TextSpan(text: 'AGT: '),
                        TextSpan(
                          text: '$_totalAGT',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _vehicles[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                vehicle.type.isNotEmpty ? vehicle.type : 'Neues Fahrzeug',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteVehicle(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Funkrufname: ${vehicle.radioId}'),
                          Text('Besatzung: ${vehicle.crew}'),
                          if (vehicle.agt.isNotEmpty) 
                            Text('AGT: ${vehicle.agt}', style: const TextStyle(color: Colors.red)),
                          if (vehicle.notes.isNotEmpty) Text('Notizen: ${vehicle.notes}'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: vehicle.status,
                            items: List.generate(9, (index) => (index + 1).toString())
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  vehicle.status = value;
                                  _calculatePortions();
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant, size: 24, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Essensbestellung',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Einsatzkräfte:', style: TextStyle(fontSize: 16)),
                        Text('$_totalCrew', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('+7% Reserve:', style: TextStyle(fontSize: 16)),
                        Text('${(_totalCrew * 0.07).ceil()}', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Gesamtportionen:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('$_calculatedPortions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _calculatePortions,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Berechnung aktualisieren', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehicle,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}