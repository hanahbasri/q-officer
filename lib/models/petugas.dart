class Petugas {
  final String idPetugas;
  final String idSuratTugas;
  final String namaPetugas;
  final String nipPetugas;
  final String gol;
  final String pangkat;

  Petugas({
    required this.idPetugas,
    required this.idSuratTugas,
    required this.namaPetugas,
    required this.nipPetugas,
    required this.gol,
    required this.pangkat,
  });

  factory Petugas.fromApiResponseMap(Map<String, dynamic> map) {
    return Petugas(
      idPetugas: map['id'] ?? '',
      idSuratTugas: map['id_surat_tugas'] ?? '',
      namaPetugas: map['nama'] ?? '',
      nipPetugas: map['nip'] ?? '',
      gol: map['gol'] ?? '',
      pangkat: map['pangkat'] ?? '',
    );
  }

  factory Petugas.fromDbMap(Map<String, dynamic> map) {
    return Petugas(
      idPetugas: map['id_petugas']?.toString() ?? '',
      idSuratTugas: map['id_surat_tugas']?.toString() ?? '',
      namaPetugas: map['nama_petugas']?.toString() ?? '',
      nipPetugas: map['nip_petugas']?.toString() ?? '',
      gol: map['gol']?.toString() ?? '',
      pangkat: map['pangkat']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_petugas': idPetugas,
      'id_surat_tugas': idSuratTugas,
      'nama_petugas': namaPetugas,
      'nip_petugas': nipPetugas,
      'gol': gol,
      'pangkat': pangkat,
    };
  }
}
