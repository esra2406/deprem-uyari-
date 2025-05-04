import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'bluetooth_cihazlar_sayfasi.dart';

void main() {
  runApp(DepremUyariApp());
}

class DepremUyariApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deprem Uyarı Sistemi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  String bilgi = "Hazır.";
  Position? kullaniciKonumu;

  @override
  void initState() {
    super.initState();
    _konumIzniAl();
  }

  Future<void> _konumIzniAl() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        bilgi = "Konum servisleri kapalı.";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      setState(() {
        bilgi = "Konum izni verilmedi.";
      });
      return;
    }

    kullaniciKonumu = await Geolocator.getCurrentPosition();
  }

  Future<void> depremTaramasiYap() async {
    final response = await http.get(Uri.parse('https://api.orhanaydogdu.com.tr/deprem/kandilli/live'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sonDepremler = data['result'];
      bool yakinDepremVar = false;
      String tumDepremler = "";

      for (var deprem in sonDepremler) {
        double? lat = double.tryParse(deprem['lat'] ?? '');
        double? lng = double.tryParse(deprem['lng'] ?? '');
        String title = deprem['title'] ?? 'Bilinmeyen';
        String mag = deprem['mag']?.toString() ?? '?';
        String depth = deprem['depth']?.toString() ?? '?';

        if (lat == null || lng == null || kullaniciKonumu == null) continue;

        double uzaklik = _hesaplaMesafe(
          kullaniciKonumu!.latitude,
          kullaniciKonumu!.longitude,
          lat,
          lng,
        );

        tumDepremler += "$title | $mag büyüklüğünde | $depth km derinlikte\n";

        if (uzaklik <= 700) {
          yakinDepremVar = true;
        }
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(yakinDepremVar ? "Yakınlarda Deprem Var" : "Yakınlarda Deprem Yok"),
          content: Text(tumDepremler),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Tamam")),
          ],
        ),
      );
    } else {
      setState(() {
        bilgi = "Deprem verisi alınamadı.";
      });
    }
  }

  Future<void> sonDepremleriGoster() async {
    final response = await http.get(Uri.parse('https://api.orhanaydogdu.com.tr/deprem/kandilli/live'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sonDepremler = data['result'];

      String tumDepremler = "";
      for (var deprem in sonDepremler.take(15)) {
        String title = deprem['title'] ?? 'Bilinmeyen';
        String mag = deprem['mag']?.toString() ?? '?';
        String depth = deprem['depth']?.toString() ?? '?';
        String date = deprem['date'] ?? '?';

        tumDepremler += "$date - $title | $mag büyüklüğünde | $depth km\n";
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Son Depremler (Türkiye)"),
          content: SingleChildScrollView(child: Text(tumDepremler)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Kapat")),
          ],
        ),
      );
    } else {
      setState(() {
        bilgi = "Son depremler alınamadı.";
      });
    }
  }

  double _hesaplaMesafe(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  Future<void> havaDurumuGetir() async {
    if (kullaniciKonumu == null) {
      setState(() {
        bilgi = "Konum alınamadı.";
      });
      return;
    }

    final apiKey = '9f08501f47395309329a5d148573ef8e';
    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${kullaniciKonumu!.latitude}&lon=${kullaniciKonumu!.longitude}&appid=$apiKey&units=metric&lang=tr';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String sehir = data['name'];
      String aciklama = data['weather'][0]['description'];
      String sicaklik = data['main']['temp'].toString();
      setState(() {
        bilgi = "$sehir: $sicaklik°C, $aciklama";
      });
    } else {
      setState(() {
        bilgi = "Hava durumu verisi alınamadı.";
      });
    }
  }

  void bluetoothMesaj() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BluetoothCihazlarSayfasi()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Deprem Uyarı Sistemi")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(bilgi, textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            SizedBox(height: 30),
            ElevatedButton(onPressed: depremTaramasiYap, child: Text("Deprem Tarama")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: sonDepremleriGoster, child: Text("Son Depremler")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: havaDurumuGetir, child: Text("Hava Durumu")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: bluetoothMesaj, child: Text("Bluetooth ile İletişim")),
          ],
        ),
      ),
    );
  }
}
