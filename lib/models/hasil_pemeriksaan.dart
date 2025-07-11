import 'package:intl/intl.dart';

class HasilPemeriksaan {
  final String idPemeriksaan;
  final String idSuratTugas;
  final String idKomoditas;
  final String namaKomoditas;
  final String idLokasi;
  final String namaLokasi;
  final String lat;
  final String long;
  final String target;
  final String metode;
  final String temuan;
  final String? catatan;
  final String tanggal;
  final int syncData;

  HasilPemeriksaan({
    required this.idPemeriksaan,
    required this.idSuratTugas,
    required this.idKomoditas,
    required this.namaKomoditas,
    required this.idLokasi,
    required this.namaLokasi,
    required this.lat,
    required this.long,
    required this.target,
    required this.metode,
    required this.temuan,
    this.catatan,
    required this.tanggal,
    this.syncData = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_pemeriksaan': idPemeriksaan,
      'id_surat_tugas': idSuratTugas,
      'id_komoditas': idKomoditas,
      'nama_komoditas': namaKomoditas,
      'id_lokasi': idLokasi,
      'nama_lokasi': namaLokasi,
      'lat': lat,
      'long': long,
      'target': target,
      'metode': metode,
      'temuan': temuan,
      'catatan': catatan,
      'tgl_periksa': tanggal,
      'syncdata': syncData,
    };
  }

  factory HasilPemeriksaan.fromMap(Map<String, dynamic> map) {
    return HasilPemeriksaan(
      idPemeriksaan: map['id_pemeriksaan'] ?? '',
      idSuratTugas: map['id_surat_tugas'] ?? '',
      idKomoditas: map['id_komoditas'] ?? '',
      namaKomoditas: map['nama_komoditas'] ?? '',
      idLokasi: map['id_lokasi'] ?? '',
      namaLokasi: map['nama_lokasi'] ?? '',
      lat: map['lat'] ?? '',
      long: map['long'] ?? '',
      target: map['target'] ?? '',
      metode: map['metode'] ?? '',
      temuan: map['temuan'] ?? '',
      catatan: map['catatan'],
      tanggal: map['tgl_periksa'] ?? '',
      syncData: map['syncdata'] ?? 0,
    );
  }

  Map<String, dynamic> toApiPayload({required String idPetugas}) {

    String formattedTglPeriksa = tanggal;
    try {
      DateTime parsedDate;
      if (tanggal.contains('T')) {
        parsedDate = DateTime.parse(tanggal);
      } else {
        parsedDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(tanggal);
      }
      formattedTglPeriksa = DateFormat("yyyy-MM-ddTHH:mm:ss").format(parsedDate);
    } catch (e) {
      formattedTglPeriksa = DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.now());
    }

    final Map<String, dynamic> payload = {
      'id': idPemeriksaan.trim(),
      'id_surat_tugas': idSuratTugas.trim(),
      'id_komoditas': idKomoditas.trim(),
      'id_lokasi': idLokasi.trim(),
      'lat': lat.trim(),
      'long': long.trim(),
      'target': target.trim(),
      'metode': metode.trim(),
      'temuan': temuan.trim(),
      'tgl_periksa': formattedTglPeriksa,
      'id_petugas': idPetugas.trim(),
    };

    if (catatan != null && catatan!.trim().isNotEmpty) {
      payload['catatan'] = catatan!.trim();
    }

    return payload;
  }

  HasilPemeriksaan copyWith({
    String? idPemeriksaan,
    String? idSuratTugas,
    String? idKomoditas,
    String? namaKomoditas,
    String? idLokasi,
    String? namaLokasi,
    String? lat,
    String? long,
    String? target,
    String? metode,
    String? temuan,
    String? catatan,
    String? tanggal,
    int? syncData,
  }) {
    return HasilPemeriksaan(
      idPemeriksaan: idPemeriksaan ?? this.idPemeriksaan,
      idSuratTugas: idSuratTugas ?? this.idSuratTugas,
      idKomoditas: idKomoditas ?? this.idKomoditas,
      namaKomoditas: namaKomoditas ?? this.namaKomoditas,
      idLokasi: idLokasi ?? this.idLokasi,
      namaLokasi: namaLokasi ?? this.namaLokasi,
      lat: lat ?? this.lat,
      long: long ?? this.long,
      target: target ?? this.target,
      metode: metode ?? this.metode,
      temuan: temuan ?? this.temuan,
      catatan: catatan ?? this.catatan,
      tanggal: tanggal ?? this.tanggal,
      syncData: syncData ?? this.syncData,
    );
  }

  @override
  String toString() {
    return 'HasilPemeriksaan{id: $idPemeriksaan, idSuratTugas: $idSuratTugas, komoditas: $namaKomoditas, lokasi: $namaLokasi, tanggal: $tanggal, syncData: $syncData}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HasilPemeriksaan &&
        other.idPemeriksaan == idPemeriksaan &&
        other.idSuratTugas == idSuratTugas &&
        other.idKomoditas == idKomoditas &&
        other.idLokasi == idLokasi;
  }

  @override
  int get hashCode {
    return idPemeriksaan.hashCode ^
    idSuratTugas.hashCode ^
    idKomoditas.hashCode ^
    idLokasi.hashCode;
  }
}