import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SuratTugasService {
  static final String baseUrl = dotenv.env['API_SURTUG']!;
  static const String authHeader = 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm';

  static const int MAX_PAYLOAD_SIZE_BYTES = 100 * 1024;

  static Future<List<StLengkap>> getAllSuratTugasByNip(String nip) async {
    if (nip == '123456789012345678') {
      return _getDummySuratTugas();
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl?nip=$nip'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );
      if (kDebugMode) {
        print('🌐 API Response Status (getAllSuratTugasByNip): ${response.statusCode}');
      }
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == true && jsonData['data'] != null && jsonData['data'] is List) {
          final List<dynamic> allSuratTugasData = jsonData['data'];
          final List<StLengkap> hasilAkhir = [];
          for (var stData in allSuratTugasData) {
            final Map<String, dynamic> suratTugasMap = stData as Map<String, dynamic>;

            List<Komoditas> komoditasList = [];
            if (suratTugasMap['komoditas'] != null && suratTugasMap['komoditas'] is List) {
              try {
                komoditasList = (suratTugasMap['komoditas'] as List)
                    .map((k) => Komoditas.fromApiResponseMap(k as Map<String, dynamic>))
                    .toList();
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Error parsing komoditas from API: $e');
                }
              }
            }

            List<Petugas> petugasList = [];
            if (suratTugasMap['petugas'] != null && suratTugasMap['petugas'] is List) {
              try {
                petugasList = (suratTugasMap['petugas'] as List)
                    .map((p) => Petugas.fromApiResponseMap(p as Map<String, dynamic>))
                    .toList();
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Error parsing petugas from API: $e');
                }
              }
            }

            List<Lokasi> lokasiList = [];
            if (suratTugasMap['lokasi'] != null && suratTugasMap['lokasi'] is List) {
              try {
                lokasiList = (suratTugasMap['lokasi'] as List)
                    .map((l) => Lokasi.fromApiResponseMap(l as Map<String, dynamic>))
                    .toList();
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Error parsing lokasi from API: $e');
                }
              }
            }

            final stLengkap = StLengkap.fromApiResponseMap(
                suratTugasMap, petugasList, lokasiList, komoditasList);
            hasilAkhir.add(stLengkap);
          }
          return hasilAkhir;

        } else {
          if (kDebugMode) {
            print('❌ API response status false or data is not a List (getAllSuratTugasByNip)');
          }
        }
      } else {
        debugPrint('❌ Error API (getAllSuratTugasByNip): ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Exception saat fetch surat tugas: $e');
    }
    return [];
  }

  static Future<List<String>> getTargetUjiData(String? jenisKarantina, String fieldToExtract) async {
    if (jenisKarantina == 'H') {
      return _getDummyTargetUjiHewan();
    } else if (jenisKarantina == 'I') {
      return _getDummyTargetUjiIkan();
    } else if (jenisKarantina == 'T') {
      return _getDummyTargetUjiTumbuhan();
    }

    if (jenisKarantina == null || jenisKarantina.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Jenis karantina kosong, tidak dapat mengambil data target uji.');
      }
      return [];
    }
    try {
      final response = await http.get(
        Uri.parse('${dotenv.env['API_TARGET_UJI']!}?kar=$jenisKarantina'),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == true && jsonData['data'] != null && jsonData['data'] is List) {
          List<String> results = [];
          for (var item in (jsonData['data'] as List)) {
            if (item is Map && item.containsKey(fieldToExtract) && item[fieldToExtract] != null) {
              results.add(item[fieldToExtract].toString());
            }
          }
          return results;
        } else {
          if (kDebugMode) {
            print('❌ API Target Uji response status false or data null/invalid format');
          }
          return [];
        }
      } else {
        debugPrint('❌ Error API Target Uji: ${response.statusCode} - ${response.reasonPhrase}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Exception saat fetch data Target Uji: $e');
      return [];
    }
  }

  static Future<String?> getIdPetugasByNip(String userNip, String idSuratTugas) async {
    try {
      if (userNip.isEmpty) {
        if (kDebugMode) {
          print('❌ GAGAL (getIdPetugasByNip): userNip kosong.');
        }
        return null;
      }
      final dbHelper = DatabaseHelper();
      final petugasListMap = await dbHelper.getPetugasById(idSuratTugas);
      for (var petugasMap in petugasListMap) {
        final petugas = Petugas.fromDbMap(petugasMap);
        if (petugas.nipPetugas == userNip) {
          if (kDebugMode) {
            print('✅ Ditemukan petugas yang cocok (getIdPetugasByNip): ${petugas.idPetugas}');
          }
          return petugas.idPetugas;
        }
      }
      if (kDebugMode) {
        print('❌ Tidak ditemukan petugas dengan NIP: $userNip untuk ST ID: $idSuratTugas di DB lokal.');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saat getIdPetugasByNip dari DB: $e');
      }
      return null;
    }
  }

  static bool _validatePayloadSize(List<Uint8List> photos) {
    int totalCompressedSize = photos.fold(0, (sum, photo) => sum + photo.length);
    int estimatedBase64Size = (totalCompressedSize * 4 / 3).ceil();
    int estimatedJsonOverhead = 2000 + (photos.length * 150);
    int totalEstimatedPayload = estimatedBase64Size + estimatedJsonOverhead;
    if (kDebugMode) {
      print("🔍 Validasi ukuran payload di Service:");
      print("   - Jumlah foto: ${photos.length}");
      print("   - Ukuran total foto compressed: $totalCompressedSize bytes (${(totalCompressedSize / 1024).toStringAsFixed(2)} KB)");
      print("   - Estimasi base64: $estimatedBase64Size bytes (${(estimatedBase64Size / 1024).toStringAsFixed(2)} KB)");
      print("   - Total estimasi payload: $totalEstimatedPayload bytes (${(totalEstimatedPayload / 1024).toStringAsFixed(2)} KB)");
      print("   - Batas maksimal: ${(MAX_PAYLOAD_SIZE_BYTES / 1024).toStringAsFixed(2)} KB");
    }
    return totalEstimatedPayload <= MAX_PAYLOAD_SIZE_BYTES;
  }

  static Future<bool> submitHasilPemeriksaan(
      HasilPemeriksaan hasil,
      List<Uint8List> compressedPhotos,
      String userNip
      ) async {
    _validatePayloadSize(compressedPhotos);
    // Dummy response
    return true;
  }

  static List<StLengkap> _getDummySuratTugas() {
    final List<Map<String, String>> dummyPetugasData = [
      {
        'nama': 'Burhanudin Raja',
        'nip': '123456789012345678',
        'gol': 'III/c',
        'pangkat': 'Penata'
      },
      {
        'nama': 'Siti Nurhaliza',
        'nip': '198765432109876543',
        'gol': 'III/d',
        'pangkat': 'Penata Tk. I'
      },
      {
        'nama': 'Ahmad Fauzi',
        'nip': '111222333444555666',
        'gol': 'III/b',
        'pangkat': 'Penata Muda Tk. I'
      },
      {
        'nama': 'Dewi Sartika',
        'nip': '777888999000111222',
        'gol': 'III/a',
        'pangkat': 'Penata Muda'
      },
      {
        'nama': 'Budi Santoso',
        'nip': '333444555666777888',
        'gol': 'II/d',
        'pangkat': 'Pengatur Tk. I'
      },
      {
        'nama': 'Rina Marlina',
        'nip': '999000111222333444',
        'gol': 'II/c',
        'pangkat': 'Pengatur'
      },
    ];

    return [
      // Surat Tugas Masuk
      ...List.generate(3, (index) {
        final i = index + 1;

        List<Petugas> petugasList = dummyPetugasData.map((petugasData) {
          return Petugas(
            idPetugas: 'petugas-${petugasData['nip']}-st-$i',
            idSuratTugas: 'st-masuk-$i',
            namaPetugas: petugasData['nama']!,
            nipPetugas: petugasData['nip']!,
            gol: petugasData['gol']!,
            pangkat: petugasData['pangkat']!,
          );
        }).toList();

        return StLengkap(
          idSuratTugas: 'st-masuk-$i',
          noSt: 'ST/MASUK/00$i',
          dasar: 'Dasar $i',
          tanggal: '2025-07-1$i',
          namaTtd: 'Jajat Surono $i',
          nipTtd: '6789$i',
          hal: 'Pemeriksaan Masuk $i',
          status: 'tertunda',
          link: 'https://example.com/st-masuk-$i.pdf',
          ptkId: 'ptk-$i',
          jenisKarantina: i % 3 == 0 ? 'T' : (i % 2 == 0 ? 'I' : 'H'),
          petugas: petugasList,
          lokasi: [
            Lokasi(
                idLokasi: 'lok-$i',
                idSuratTugas: 'st-masuk-$i',
                namaLokasi: 'Lokasi Masuk $i',
                latitude: -6.2088 + (i * 0.01),
                longitude: 106.8456 + (i * 0.01),
                detail: 'Detail lokasi masuk $i',
                timestamp: '2023-02-0$i 10:00:00')
          ],
          komoditas: [
            Komoditas(
                idKomoditas: 'kom-$i',
                idSuratTugas: 'st-masuk-$i',
                namaKomoditas: 'Komoditas Masuk $i'),
          ],
        );
      }),
    ];
  }

  static List<String> _getDummyTargetUjiHewan() {
    return [
      "African Swine Fever (ASF)",
      "Avian Influenza (AI)",
      "Brucellosis",
      "Foot and Mouth Disease (FMD)",
      "Rabies",
      "Anthrax",
      "Classical Swine Fever (CSF)",
      "Jembrana",
      "Bovine Spongiform Encephalopathy (BSE)",
      "Peste des Petits Ruminants (PPR)",
      "Surra (Trypanosoma evansi)",
      "Hog Cholera",
      "Leptospirosis",
      "Q Fever (Coxiella burnetii)",
      "Rift Valley Fever",
      "Scrapie",
      "Swine Vesicular Disease (SVD)",
      "Glanders (Burkholderia mallei)",
      "Dourine (Trypanosoma equiperdum)",
      "Contagious Bovine Pleuropneumonia (CBPP)",
      "Lumpy Skin Disease (LSD)",
    ];
  }

  static List<String> _getDummyTargetUjiIkan() {
    return [
      "White Spot Syndrome Virus (WSSV)",
      "Taura Syndrome Virus (TSV)",
      "Infectious Myonecrosis Virus (IMNV)",
      "Yellow Head Virus (YHV)",
      "Koi Herpes Virus (KHV)",
      "Viral Hemorrhagic Septicemia (VHS)",
      "Infectious Hematopoietic Necrosis (IHN)",
      "Infectious Salmon Anemia (ISA)",
      "Acute Hepatopancreatic Necrosis Disease (AHPND)",
      "Enterocytozoon hepatopenaei (EHP)",
      "Spring Viremia of Carp (SVC)",
      "Epizootic Ulcerative Syndrome (EUS)",
      "Tilapia Lake Virus (TiLV)",
      "Streptococcus iniae",
      "Streptococcus agalactiae",
      "Vibrio harveyi",
      "Vibrio parahaemolyticus",
      "Aeromonas salmonicida",
      "Edwardsiella tarda",
      "Flexibacter columnaris",
      "Iridovirus",
    ];
  }

  static List<String> _getDummyTargetUjiTumbuhan() {
    return [
      "Bactrocera dorsalis",
      "Liriomyza huidobrensis",
      "Thrips palmi",
      "Ralstonia solanacearum",
      "Xanthomonas oryzae pv. oryzae",
      "Phytophthora infestans",
      "Fusarium oxysporum f.sp. cubense",
      "Erwinia amylovora",
      "Globodera rostochiensis",
      "Ceratocystis fimbriata",
      "Tilletia indica",
      "Clavibacter michiganensis",
      "Pantoea stewartii",
      "Plum Pox Virus (PPV)",
      "Citrus Vein Phloem Degeneration (CVPD)",
      "Banana Bunchy Top Virus (BBTV)",
      "Tomato Spotted Wilt Virus (TSWV)",
      "Potato Spindle Tuber Viroid (PSTVd)",
      "Candidatus Liberibacter asiaticus",
      "Xylella fastidiosa",
      "Anastrepha fraterculus",
    ];
  }
}