class Komoditas {
  final String idKomoditas;
  final String idSuratTugas;
  final String namaKomoditas;
  final String? namaUmumTercetak;
  final String? namaLatin;
  final String? vol;
  final String? sat;
  final String? kdSat;
  final String? netto;
  final String? jantan;
  final String? betina;

  Komoditas({
    required this.idKomoditas,
    required this.idSuratTugas,
    required this.namaKomoditas,
    this.namaUmumTercetak,
    this.namaLatin,
    this.vol,
    this.sat,
    this.kdSat,
    this.netto,
    this.jantan,
    this.betina,
  });

  factory Komoditas.fromApiResponseMap(Map<String, dynamic> map) {
    return Komoditas(
      idKomoditas: map['id'] ?? '',
      idSuratTugas: map['id_surat_tugas'] ?? '',
      namaKomoditas: map['nama_komoditas'] ?? '',
      namaUmumTercetak: map['nama_eng'] ?? '',
      namaLatin: map['nama_latin'] ?? '',
      vol: map['vol'] ?? '',
      sat: map['sat'] ?? '',
      kdSat: '',
      netto: '',
      jantan: '',
      betina: '',
    );
  }

  factory Komoditas.fromDbMap(Map<String, dynamic> map) {
    return Komoditas(
      idKomoditas: map['id_komoditas']?.toString() ?? '',
      idSuratTugas: map['id_surat_tugas']?.toString() ?? '',
      namaKomoditas: map['nama_komoditas']?.toString() ?? '',
      namaUmumTercetak: map['nama_umum_tercetak']?.toString() ?? '',
      namaLatin: map['nama_latin']?.toString() ?? '',
      vol: map['vol']?.toString() ?? '',
      sat: map['sat']?.toString() ?? '',
      kdSat: map['kd_sat']?.toString() ?? '',
      netto: map['netto']?.toString() ?? '',
      jantan: map['jantan']?.toString() ?? '',
      betina: map['betina']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_komoditas': idKomoditas,
      'id_surat_tugas': idSuratTugas,
      'nama_komoditas': namaKomoditas,
      'nama_umum_tercetak': namaUmumTercetak,
      'nama_latin': namaLatin,
      'vol': vol,
      'sat': sat,
      'kd_sat': kdSat,
      'netto': netto,
      'jantan': jantan,
      'betina': betina,
    };
  }
}