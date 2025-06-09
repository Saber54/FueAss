class AdminScreen extends StatelessWidget {
  final List<Einsatz> _einsaetze = [
    Einsatz(id: '1', ort: 'Schwarzenbach', status: 'Aktiv'),
    Einsatz(id: '2', ort: 'Naila', status: 'Abgeschlossen'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin-Bereich'),
        actions: [
          IconButton(
            icon: Icon(Icons.export),
            onPressed: () => Navigator.pushNamed(context, '/export'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _einsaetze.length,
              itemBuilder: (ctx, index) => Card(
                child: ListTile(
                  title: Text(_einsaetze[index].ort),
                  subtitle: Text('Status: ${_einsaetze[index].status}'),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () => _showEinsatzDetails(context, _einsaetze[index]),
                ),
              ),
            ),
          ),
          FlutterMap(
            options: MapOptions(center: LatLng(50.2227, 11.9350), zoom: 13.0),
            layers: [
              TileLayerOptions(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEinsatzDetails(BuildContext context, Einsatz einsatz) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Einsatz ${einsatz.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ort: ${einsatz.ort}'),
            Text('Status: ${einsatz.status}'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Schließen'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

class Einsatz {
  final String id;
  final String ort;
  final String status;

  Einsatz({required this.id, required this.ort, required this.status});
}