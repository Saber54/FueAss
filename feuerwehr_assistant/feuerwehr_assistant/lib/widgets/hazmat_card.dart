import 'package:flutter/material.dart';
import '../models/hazmat.dart';

class HazmatCard extends StatelessWidget {
  final Hazmat hazmat;

  const HazmatCard({super.key, required this.hazmat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bild-Anzeige (falls vorhanden)
            if (hazmat.imagePath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: hazmat.imagePath.startsWith('http')
                    ? Image.network(
                        hazmat.imagePath,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.error),
                      )
                    : Image.asset(
                        hazmat.imagePath,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.error),
                      ),
              ),

            // Titel
            Text(
              hazmat.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            // UN-Nummer
            _buildInfoRow(context, 'UN-Nummer:', hazmat.unNumber),

            // Gefahrenklasse
            _buildInfoRow(context, 'Gefahrenklasse:', hazmat.dangerClass),

            // Schutzmaßnahmen
            _buildInfoRow(context, 'Schutzmaßnahmen:', hazmat.protectiveMeasures),

            // Warnsymbol
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade800),
                const SizedBox(width: 4),
                Text(
                  'Gefahrenstoff',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}