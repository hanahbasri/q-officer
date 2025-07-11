class Lokasi {
  final String idLokasi;
  final String idSuratTugas;
  final String namaLokasi;
  final double latitude;
  final double longitude;
  final String detail;
  final String timestamp;

  Lokasi({
    required this.idLokasi,
    required this.idSuratTugas,
    required this.namaLokasi,
    required this.latitude,
    required this.longitude,
    required this.detail,
    required this.timestamp,
  });

  factory Lokasi.fromApiResponseMap(Map<String, dynamic> map) {
    return Lokasi(
      idLokasi: map['id'] ?? '',
      idSuratTugas: map['id_surat_tugas'] ?? '',
      namaLokasi: map['locationName'] ?? '',
      latitude: double.tryParse(map['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '0') ?? 0.0,
      detail: map['detail'] ?? '',
      timestamp: map['created_at'] ?? '',
    );
  }

  factory Lokasi.fromDbMap(Map<String, dynamic> map) {
    return Lokasi(
      idLokasi: map['id_lokasi']?.toString() ?? '',
      idSuratTugas: map['id_surat_tugas']?.toString() ?? '',
      namaLokasi: map['nama_lokasi']?.toString() ?? '',
      latitude: double.tryParse(map['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '0') ?? 0.0,
      detail: map['detail']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_lokasi': idLokasi,
      'id_surat_tugas': idSuratTugas,
      'nama_lokasi': namaLokasi,
      'latitude': latitude,
      'longitude': longitude,
      'detail': detail,
      'timestamp': timestamp,
    };
  }
}