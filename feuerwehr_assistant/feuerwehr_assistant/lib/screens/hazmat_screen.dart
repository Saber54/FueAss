import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hazmat_provider.dart';
import '../widgets/hazmat_card.dart'; // Stellen Sie sicher, dass diese Datei existiert

class HazmatScreen extends StatefulWidget {
  const HazmatScreen({super.key});

  @override
  State<HazmatScreen> createState() => _HazmatScreenState();
}

class _HazmatScreenState extends State<HazmatScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<HazmatProvider>().loadHazmats();
  }

  @override
  Widget build(BuildContext context) {
    final hazmatProvider = Provider.of<HazmatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gefahrgut-Datenbank'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Suche nach Name/UN-Nummer',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => hazmatProvider.search(_searchController.text),
                ),
              ),
              onChanged: hazmatProvider.search,
            ),
          ),
          Expanded(
            child: hazmatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: hazmatProvider.hazmats.length,
                    itemBuilder: (ctx, i) => HazmatCard(hazmat: hazmatProvider.hazmats[i]),
                  ),
          ),
        ],
      ),
    );
  }
}