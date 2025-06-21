// widgets/tactical_symbol_picker.dart
import 'package:flutter/material.dart';
import '../models/tactical_symbol.dart';
import '../services/tactical_symbol_service.dart';

class TacticalSymbolPicker extends StatefulWidget {
  final TacticalSymbolCategory category;
  final Function(TacticalSymbol) onSymbolSelected;

  const TacticalSymbolPicker({
    super.key,
    required this.category,
    required this.onSymbolSelected,
  });

  @override
  State<TacticalSymbolPicker> createState() => _TacticalSymbolPickerState();
}

class _TacticalSymbolPickerState extends State<TacticalSymbolPicker> with TickerProviderStateMixin {
  final TacticalSymbolService _symbolService = TacticalSymbolService();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _categoryTitle {
    switch (widget.category) {
      case TacticalSymbolCategory.vehicle:
        return 'Fahrzeuge';
      case TacticalSymbolCategory.hazard:
        return 'Gefahren';
      case TacticalSymbolCategory.equipment:
        return 'Ausrüstung';
      case TacticalSymbolCategory.personnel:
        return 'Personal';
      case TacticalSymbolCategory.infrastructure:
        return 'Infrastruktur';
    }
  }

  IconData get _categoryIcon {
    switch (widget.category) {
      case TacticalSymbolCategory.vehicle:
        return Icons.directions_car;
      case TacticalSymbolCategory.hazard:
        return Icons.warning;
      case TacticalSymbolCategory.equipment:
        return Icons.build;
      case TacticalSymbolCategory.personnel:
        return Icons.person;
      case TacticalSymbolCategory.infrastructure:
        return Icons.business;
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbols = _symbolService.getSymbolsByCategory(widget.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _categoryIcon,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _categoryTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Symbols Grid
          Flexible(
            child: symbols.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Keine Symbole verfügbar',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fügen Sie Symbole im Ordner\ntactical_symbols/${widget.category.name}/ hinzu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: symbols.length,
                    itemBuilder: (context, index) {
                      final symbol = symbols[index];
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final slideAnimation = Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              index * 0.1,
                              1.0,
                              curve: Curves.easeOutBack,
                            ),
                          ));

                          return SlideTransition(
                            position: slideAnimation,
                            child: _SymbolCard(
                              symbol: symbol,
                              onTap: () {
                                widget.onSymbolSelected(symbol);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SymbolCard extends StatelessWidget {
  final TacticalSymbol symbol;
  final VoidCallback onTap;

  const _SymbolCard({
    required this.symbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: symbol.backgroundColor?.withOpacity(0.1) ?? 
                           Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _buildSymbolImage(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: Text(
                  symbol.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolImage() {
    // Hier würde normalerweise das tatsächliche Bild geladen werden
    // Für Demo-Zwecke verwenden wir Icons
    IconData iconData;
    switch (symbol.id) {
      case 'vehicle_fire_truck':
        iconData = Icons.fire_truck;
        break;
      case 'vehicle_ambulance':
        iconData = Icons.local_hospital;
        break;
      case 'vehicle_police':
        iconData = Icons.local_police;
        break;
      case 'hazard_fire':
        iconData = Icons.local_fire_department;
        break;
      case 'hazard_chemical':
        iconData = Icons.science;
        break;
      case 'hazard_explosion':
        iconData = Icons.dangerous;
        break;
      default:
        iconData = Icons.place;
    }

    return Icon(
      iconData,
      size: 32,
      color: symbol.backgroundColor ?? Colors.grey[700],
    );

    // Für echte Asset-Bilder würde man folgendes verwenden:
    /*
    return Image.asset(
      symbol.assetPath,
      width: 32,
      height: 32,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.broken_image,
          size: 32,
          color: Colors.grey[400],
        );
      },
    );
    */
  }
}