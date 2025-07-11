import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../databases/db_helper.dart';
import 'package:custom_info_window/custom_info_window.dart';

class PeriksaLokasi extends StatefulWidget {
  final String idSuratTugas;

  const PeriksaLokasi({super.key, required this.idSuratTugas});

  @override
  PeriksaLokasiState createState() => PeriksaLokasiState();
}

class PeriksaLokasiState extends State<PeriksaLokasi> {
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  List<LatLng> _pendingPositions = [];
  LatLng _initialCameraTarget = const LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();
    _fetchLocationsFromDb();
  }

  Future<void> _fetchLocationsFromDb() async {
    final locations = await DatabaseHelper().getLokasiById(widget.idSuratTugas);

    List<LatLng> positions = [];

    setState(() {
      _markers.clear();
      _polylines.clear();

      if (locations.isNotEmpty) {
        _initialCameraTarget = LatLng(
          locations.first['latitude'] as double,
          locations.first['longitude'] as double,
        );
      }

      for (var row in locations) {
        final lat = row['latitude'] as double;
        final lng = row['longitude'] as double;
        final name = row['nama_lokasi'] ?? 'Tanpa Nama';
        final timestamp = row['timestamp'] ?? '-';

        final position = LatLng(lat, lng);
        positions.add(position);

        _markers.add(
          Marker(
            markerId: MarkerId(row['id_lokasi'].toString()),
            position: position,
            onTap: () {
              _customInfoWindowController.addInfoWindow!(
                Container(
                  width: 200,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFC5EAEC),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text("🕒 $timestamp", style: TextStyle(fontSize: 15)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _openGoogleMaps(position),
                          child: Text("Buka di Maps", style: TextStyle(color: Colors.blue)),
                        ),
                      ),
                    ],
                  ),
                ),
                position,
              );
            },
          ),
        );
      }

      if (positions.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId("route"),
            color: Colors.blue,
            width: 5,
            points: positions,
          ),
        );
      }

      if (_isMapReady && positions.isNotEmpty) {
        _moveCameraToFitMarkers(positions);
      } else {
        _pendingPositions = positions;
      }
    });
  }

  void _moveCameraToFitMarkers(List<LatLng> positions) {
    if (_mapController == null) return;

    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: positions.first, zoom: 16),
        ),
      );

    } else if (positions.length > 1) {

      final bounds = LatLngBounds(
        southwest: LatLng(
          positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
          positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
          positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _openGoogleMaps(LatLng position) async {
    final Uri url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (kDebugMode) {
        print("Tidak dapat membuka Google Maps.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Lacak Lokasi Penugasan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _initialCameraTarget, zoom: 12),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              _customInfoWindowController.googleMapController = controller;
              _isMapReady = true;

              if (_pendingPositions.isNotEmpty) {
                _moveCameraToFitMarkers(_pendingPositions);
                _pendingPositions = [];
              }
            },
            onTap: (position) => _customInfoWindowController.hideInfoWindow!(),
            onCameraMove: (_) => _customInfoWindowController.onCameraMove!(),
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 120,
            width: 200,
            offset: 50,
          ),
        ],
      ),
    );
  }
}