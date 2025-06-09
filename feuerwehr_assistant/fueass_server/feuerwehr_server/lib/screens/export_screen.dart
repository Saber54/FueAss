class ExportScreen extends StatefulWidget {
  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _exportFormat = 'PDF';
  bool _includeFahrzeuge = true;
  bool _includeProtokolle = true;

  Future<void> _exportData() async {
    // Hier API-Aufruf zum Server für den Export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export als $_exportFormat gestartet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Einsatzexport')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _exportFormat,
              items: ['PDF', 'CSV', 'JSON'].map((format) {
                return DropdownMenuItem(
                  value: format,
                  child: Text(format),
                );
              }).toList(),
              onChanged: (value) => setState(() => _exportFormat = value!),
              decoration: InputDecoration(labelText: 'Exportformat'),
            ),
            SwitchListTile(
              title: Text('Fahrzeugdaten einbeziehen'),
              value: _includeFahrzeuge,
              onChanged: (value) => setState(() => _includeFahrzeuge = value),
            ),
            SwitchListTile(
              title: Text('Protokolle einbeziehen'),
              value: _includeProtokolle,
              onChanged: (value) => setState(() => _includeProtokolle = value),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _exportData,
              child: Text('Export starten'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}