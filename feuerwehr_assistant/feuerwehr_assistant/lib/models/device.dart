class Device {
  final String id;
  final String name;
  final bool isMaster;
  final bool isServer;
  final String? ipAddress;

  Device({
    required this.id,
    required this.name,
    this.isMaster = false,
    this.isServer = false,
    this.ipAddress,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      isMaster: json['isMaster'] ?? false,
      isServer: json['isServer'] ?? false,
      ipAddress: json['ipAddress'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isMaster': isMaster,
    'isServer': isServer,
    'ipAddress': ipAddress,
  };
}