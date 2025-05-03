import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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
      home: KullaniciAdiEkrani(),
    );
  }
}

class KullaniciAdiEkrani extends StatefulWidget {
  @override
  _KullaniciAdiEkraniState createState() => _KullaniciAdiEkraniState();
}

class _KullaniciAdiEkraniState extends State<KullaniciAdiEkrani> {
  TextEditingController _isimController = TextEditingController();
  String bilgi = "";

  @override
  void initState() {
    super.initState();
    _kontrolEtKullaniciAdi();
  }

  Future<void> _kontrolEtKullaniciAdi() async {
    final prefs = await SharedPreferences.getInstance();
    final kullaniciAdi = prefs.getString('kullaniciAdi');

    if (kullaniciAdi != null && kullaniciAdi.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AnaSayfa(kullaniciAdi: kullaniciAdi),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanıcı Adı Girişi"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _isimController, decoration: InputDecoration(labelText: "Adınızı girin")),
            ElevatedButton(
              onPressed: () async {
                String kullaniciAdi = _isimController.text;
                if (kullaniciAdi.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('kullaniciAdi', kullaniciAdi);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnaSayfa(kullaniciAdi: kullaniciAdi),
                    ),
                  );
                } else {
                  setState(() {
                    bilgi = "Lütfen bir isim girin.";
                  });
                }
              },
              child: Text("Devam Et"),
            ),
            if (bilgi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  bilgi,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  final String kullaniciAdi;

  AnaSayfa({required this.kullaniciAdi});

  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final FlutterTts tts = FlutterTts();
  String bilgi = "Hoş geldiniz! Hava durumu alınıyor...";
  bool havaDurumuGeldi = false;
  late Position kullaniciKonumu;

  @override
  void initState() {
    super.initState();
    _kullaniciKarshilama();
  }

  Future<void> _kullaniciKarshilama() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          bilgi = "Konum servisleri kapalı. Lütfen etkinleştirin.";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
          setState(() {
            bilgi = "Konum izni verilmedi.";
          });
          return;
        }
      }

      kullaniciKonumu = await Geolocator.getCurrentPosition().timeout(Duration(seconds: 10));

      await tts.setLanguage("tr-TR");
      await tts.setSpeechRate(0.5);
      await tts.awaitSpeakCompletion(true);
      await tts.speak("Hoş geldiniz ${widget.kullaniciAdi}.");

      setState(() {
        bilgi = "Hoş geldiniz ${widget.kullaniciAdi}. Deprem kontrolü yapılabilir.";
        havaDurumuGeldi = true;
      });
    } catch (e) {
      print("HATA: $e");
      await tts.setLanguage("tr-TR");
      await tts.setSpeechRate(0.5);
      await tts.awaitSpeakCompletion(true);
      await tts.speak("Hoş geldiniz ${widget.kullaniciAdi}. Konum alınamadı.");
      setState(() {
        bilgi = "Hoş geldiniz ${widget.kullaniciAdi}. Konum alınamadı.";
        havaDurumuGeldi = true;
      });
    }
  }

  Future<void> depremTaramasiYap() async {
    final response = await http.get(Uri.parse('https://api.orhanaydogdu.com.tr/deprem/kandilli/live'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sonDepremler = data['result'];

      for (var deprem in sonDepremler) {
        double lat = double.parse(deprem['lat']);
        double lng = double.parse(deprem['lng']);
        double uzaklik = _hesaplaMesafe(kullaniciKonumu.latitude, kullaniciKonumu.longitude, lat, lng);

        if (uzaklik <= 700) {
          String mesaj = "${deprem['title']}, ${deprem['mag']} büyüklüğünde, ${deprem['depth']} km derinlikte bir deprem saptandı. Güvende olun.";
          await tts.speak("Dikkat ${widget.kullaniciAdi}. $mesaj");
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Yakın Deprem Tespit Edildi"),
              content: Text(mesaj),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Tamam"),
                )
              ],
            ),
          );
          return;
        }
      }

      await tts.speak("Yakınlarda büyük bir deprem tespit edilmedi.");
    } else {
      print("Deprem verisi alınamadı.");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ana Sayfa"), centerTitle: true),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(bilgi, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white)),
          SizedBox(height: 40),
          if (havaDurumuGeldi)
            ElevatedButton(
              onPressed: depremTaramasiYap,
              child: Text("Deprem Tarama"),
            ),
        ],
      ),
    );
  }
}
