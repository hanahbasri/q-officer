import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';

class StLengkap {
  final String idSuratTugas;
  final String noSt;
  final String dasar;
  final String tanggal;
  final String namaTtd;
  final String nipTtd;
  final String hal;
  final String status;
  final String link;
  final String? ptkId;
  final String? jenisKarantina;
  final List<Petugas> petugas;
  final List<Lokasi> lokasi;
  final List<Komoditas> komoditas;
  final DateTime? tanggalSelesai;

  StLengkap({
    required this.idSuratTugas,
    required this.noSt,
    required this.dasar,
    required this.tanggal,
    required this.namaTtd,
    required this.nipTtd,
    required this.hal,
    required this.status,
    required this.link,
    required this.ptkId,
    this.jenisKarantina,
    required this.petugas,
    required this.lokasi,
    required this.komoditas,
    this.tanggalSelesai,
  });

  StLengkap copyWith({
    String? status,
    String? jenisKarantina,
    DateTime? tanggalSelesai,
  }) {
    return StLengkap(
      idSuratTugas: idSuratTugas,
      noSt: noSt,
      dasar: dasar,
      tanggal: tanggal,
      namaTtd: namaTtd,
      nipTtd: nipTtd,
      hal: hal,
      status: status ?? this.status,
      link: link,
      ptkId: ptkId,
      jenisKarantina: jenisKarantina ?? this.jenisKarantina,
      petugas: petugas,
      lokasi: lokasi,
      komoditas: komoditas,
      tanggalSelesai: tanggalSelesai ?? this.tanggalSelesai,
    );

  }

  factory StLengkap.fromApiResponseMap(Map<String, dynamic> map,
      List<Petugas> petugas, List<Lokasi> lokasi, List<Komoditas> komoditas) {
    return StLengkap(
      idSuratTugas: map['id']?.toString() ?? '',
      noSt: map['no_st']?.toString() ?? '',
      dasar: map['dasar']?.toString() ?? '',
      tanggal: map['tgl_tugas']?.toString() ?? '',
      namaTtd: map['ttd_nama']?.toString() ?? '',
      nipTtd: map['ttd_nip']?.toString() ?? '',
      hal: map['hal']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      link: map['link']?.toString() ?? '',
      ptkId: map['ptk_id']?.toString(),
      jenisKarantina: map['jenis_karantina']?.toString(),
      petugas: petugas,
      lokasi: lokasi,
      komoditas: komoditas,
    );
  }

  factory StLengkap.fromDbMap(Map<String, dynamic> map,
      List<Petugas> petugas, List<Lokasi> lokasi, List<Komoditas> komoditas,
      {DateTime? tanggalSelesai}) {
    return StLengkap(
      idSuratTugas: map['id_surat_tugas']?.toString() ?? '',
      noSt: map['no_st']?.toString() ?? '',
      dasar: map['dasar']?.toString() ?? '',
      tanggal: map['tanggal']?.toString() ?? '',
      namaTtd: map['nama_ttd']?.toString() ?? '',
      nipTtd: map['nip_ttd']?.toString() ?? '',
      hal: map['hal']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      link: map['link']?.toString() ?? '',
      ptkId: map['ptk_id']?.toString(),
      jenisKarantina: map['jenis_karantina']?.toString(),
      petugas: petugas,
      lokasi: lokasi,
      komoditas: komoditas,
      tanggalSelesai: tanggalSelesai,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_surat_tugas': idSuratTugas,
      'no_st': noSt,
      'dasar': dasar,
      'tanggal': tanggal,
      'nama_ttd': namaTtd,
      'nip_ttd': nipTtd,
      'hal': hal,
      'status': status,
      'link': link,
      'ptk_id': ptkId,
      'jenis_karantina': jenisKarantina,
    };
  }
}
