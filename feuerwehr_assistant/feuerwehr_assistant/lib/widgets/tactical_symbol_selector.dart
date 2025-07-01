// lib/widgets/tactical_symbol_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/tactical_symbols_loader.dart'; // Verwendet nur diese TacticalSymbol Klasse

class TacticalSymbolSelector extends StatefulWidget {
  final Function(TacticalSymbol)
  onSymbolSelected; // Verwendet die TacticalSymbol aus tactical_symbols_loader.dart

  const TacticalSymbolSelector({Key? key, required this.onSymbolSelected})
    : super(key: key);

  @override
  State<TacticalSymbolSelector> createState() => _TacticalSymbolSelectorState();
}

class _TacticalSymbolSelectorState extends State<TacticalSymbolSelector> {
  final TacticalSymbolsLoader _loader = TacticalSymbolsLoader();
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSymbols();
  }

  Future<void> _loadSymbols() async {
    await _loader.loadSymbols();
    if (mounted) {
      setState(() {
        _isLoading = false;
        // Wähle erste Kategorie als Standard
        if (_loader.categories.isNotEmpty) {
          _selectedCategory = _loader.categories.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Text(
                  'Taktische Zeichen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Kategorie-Dropdown
          Container(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategorie auswählen',
                border: OutlineInputBorder(),
              ),
              items:
                  _loader.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_loader.getCategoryDisplayName(category)),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
          ),

          // Symbole Grid
          Expanded(
            child:
                _selectedCategory == null
                    ? const Center(child: Text('Bitte Kategorie auswählen'))
                    : _buildSymbolGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolGrid() {
    final symbols = _loader.getSymbolsForCategory(_selectedCategory!);

    if (symbols.isEmpty) {
      return const Center(
        child: Text('Keine Symbole in dieser Kategorie gefunden'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return _buildSymbolCard(symbol);
      },
    );
  }

  Widget _buildSymbolCard(TacticalSymbol symbol) {
    return InkWell(
      onTap: () {
        widget.onSymbolSelected(symbol);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: _buildSymbolWidget(
                  symbol,
                ), // GEÄNDERT: Vereinfachtes Widget
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Text(
                  symbol.name,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEUE METHODE: Vereinfachtes Symbol-Widget
  Widget _buildSymbolWidget(TacticalSymbol symbol) {
    return SvgPicture.asset(
      symbol.assetPath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      // ENTFERNT: FutureBuilder - das verursacht Probleme
      placeholderBuilder:
          (context) =>
              const Icon(Icons.image_not_supported, color: Colors.grey),
      // HINZUGEFÜGT: Error-Handler
      errorBuilder: (context, error, stackTrace) {
        print('SVG Fehler für ${symbol.assetPath}: $error');
        return const Icon(Icons.image_not_supported, color: Colors.red);
      },
    );
  }
}
