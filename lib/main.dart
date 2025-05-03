import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      appBar: AppBar(
        title: const Text("Kullanıcı Adı Girişi"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _isimController,
              decoration: InputDecoration(labelText: "Adınızı girin"),
            ),
            ElevatedButton(
              onPressed: () async {
                String kullaniciAdi = _isimController.text;
                if (kullaniciAdi.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('kullaniciAdi', kullaniciAdi);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AnaSayfa(kullaniciAdi: kullaniciAdi),
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

  @override
  void initState() {
    super.initState();
    _kullaniciKarshilama();
  }

  Future<void> _kullaniciKarshilama() async {
    try {
      final konum = await Geolocator.getCurrentPosition()
          .timeout(Duration(seconds: 7));
      final lat = konum.latitude;
      final lon = konum.longitude;

      var havaDurumu =
          await havaDurumuAl(lat, lon).timeout(Duration(seconds: 7));
      String havaDurumuAciklama =
          "Bugün ${havaDurumu['main']['temp']}°C, ${havaDurumu['weather'][0]['description']}.";

      await tts.setLanguage("tr-TR");
      await tts.setSpeechRate(0.5);
      await tts.speak(
          "Hoş geldiniz ${widget.kullaniciAdi}. $havaDurumuAciklama");

      setState(() {
        bilgi =
            "Hoş geldiniz ${widget.kullaniciAdi}. $havaDurumuAciklama";
        havaDurumuGeldi = true;
      });
    } catch (e) {
      await tts.setLanguage("tr-TR");
      await tts.setSpeechRate(0.5);
      await tts.speak(
          "Hoş geldiniz ${widget.kullaniciAdi}. Hava durumu alınamadı.");

      setState(() {
        bilgi =
            "Hoş geldiniz ${widget.kullaniciAdi}. Hava durumu alınamadı.";
        havaDurumuGeldi = true;
      });
    }
  }

  Future<Map<String, dynamic>> havaDurumuAl(double lat, double lon) async {
    final apiKey = '9f08501f47395309329a5d148573efe8';
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=tr';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Hava durumu verisi alınamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            bilgi,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
          SizedBox(height: 40),
          if (havaDurumuGeldi)
            ElevatedButton(
              onPressed: () {
                print("Deprem taraması başlatıldı");
              },
              child: Text("Deprem Tarama"),
            ),
        ],
      ),
    );
  }
}
