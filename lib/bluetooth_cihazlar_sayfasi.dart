import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:convert';
import 'dart:typed_data';

class BluetoothCihazlarSayfasi extends StatefulWidget {
  @override
  _BluetoothCihazlarSayfasiState createState() => _BluetoothCihazlarSayfasiState();
}

class _BluetoothCihazlarSayfasiState extends State<BluetoothCihazlarSayfasi> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> bulunanCihazlar = [];
  bool taramaDevamEdiyor = false;
  bool baglaniyor = false;
  String mesaj = "Yardım lazım!";

  void cihazlariTara() async {
    setState(() {
      bulunanCihazlar.clear();
      taramaDevamEdiyor = true;
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!bulunanCihazlar.contains(r.device)) {
          setState(() {
            bulunanCihazlar.add(r.device);
          });
        }
      }
    });

    await Future.delayed(Duration(seconds: 5));
    flutterBlue.stopScan();

    setState(() {
      taramaDevamEdiyor = false;
    });
  }

  Future<void> baglanVeMesajGonder(BluetoothDevice cihaz) async {
    setState(() {
      baglaniyor = true;
    });

    try {
      await cihaz.connect();
      List<BluetoothService> servisler = await cihaz.discoverServices();

      for (BluetoothService servis in servisler) {
        for (BluetoothCharacteristic ozellik in servis.characteristics) {
          if (ozellik.properties.write) {
            await ozellik.write(utf8.encode(mesaj) as Uint8List);
            _gosterDialog("Mesaj Gönderildi", "Mesaj başarıyla gönderildi.");
            await cihaz.disconnect();
            setState(() {
              baglaniyor = false;
            });
            return;
          }
        }
      }

      _gosterDialog("Mesaj Gönderilemedi", "Yazılabilir bir özellik bulunamadı.");
      await cihaz.disconnect();
    } catch (e) {
      _gosterDialog("Hata", "Bağlantı kurulamadı: $e");
    }

    setState(() {
      baglaniyor = false;
    });
  }

  void _gosterDialog(String baslik, String icerik) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(baslik),
        content: Text(icerik),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Tamam"))
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    cihazlariTara();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bluetooth Cihazları")),
      body: Column(
        children: [
          if (taramaDevamEdiyor || baglaniyor)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: bulunanCihazlar.length,
              itemBuilder: (context, index) {
                final cihaz = bulunanCihazlar[index];
                return ListTile(
                  title: Text(cihaz.name.isNotEmpty ? cihaz.name : "Bilinmeyen Cihaz"),
                  subtitle: Text(cihaz.id.id),
                  onTap: () {
                    baglanVeMesajGonder(cihaz);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
