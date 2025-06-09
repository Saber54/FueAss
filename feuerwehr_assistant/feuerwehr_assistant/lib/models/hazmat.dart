class Hazmat {
  final String id;
  final String name;
  final String unNumber;
  final String dangerClass;
  final String protectiveMeasures;
  final String imagePath; // Lokaler Pfad oder URL

  Hazmat({
    required this.id,
    required this.name,
    required this.unNumber,
    required this.dangerClass,
    required this.protectiveMeasures,
    required this.imagePath,
  });

  // Mock-Datenbank
  static List<Hazmat> samples = [
    Hazmat(
      id: '1',
      name: 'Chlor',
      unNumber: '1017',
      dangerClass: '2.3 (Giftgas)',
      protectiveMeasures: 'CSA + Atemschutz',
      imagePath: 'assets/hazmat_images/chlorine.png',
    ),
    Hazmat(
      id: '2',
      name: 'Benzin',
      unNumber: '1203',
      dangerClass: '3 (Entzündbar)',
      protectiveMeasures: 'Chemikalienschutzanzug',
      imagePath: 'https://example.com/gasoline.jpg',
    ),
  ];

  factory Hazmat.fromJson(Map<String, dynamic> json) {
    return Hazmat(
      id: json['id'],
      name: json['name'],
      unNumber: json['unNumber'],
      dangerClass: json['dangerClass'],
      protectiveMeasures: json['protectiveMeasures'],
      imagePath: json['imagePath'],
    );
  }

   // toJson Methode
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unNumber': unNumber,
      'dangerClass': dangerClass,
      'protectiveMeasures': protectiveMeasures,
      'imagePath': imagePath,
    };
  }
}