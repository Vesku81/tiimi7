// palvelut/kysymyspankki_palvelu.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint varten
import 'package:path_provider/path_provider.dart';
import '../mallit/kysymys.dart';
// Uuid-pakettia ei välttämättä tarvita tässä, jos Kysymys-luokka hoitaa ID:n luonnin

class KysymyspankkiPalvelu {
  static const String _fileName = 'kysymyspankki_v2.json'; // Päivitetty nimi, jos rakenne muuttuu

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Kysymys>> lataaKysymyksetPankista() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        debugPrint("Kysymyspankkitiedostoa '$_fileName' ei löydy, palautetaan tyhjä lista.");
        return [];
      }
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        debugPrint("Kysymyspankkitiedosto '$_fileName' on tyhjä.");
        return [];
      }
      final List<dynamic> jsonData = jsonDecode(contents);
      return jsonData.map((item) => Kysymys.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e, s) {
      debugPrint('Virhe kysymyspankin latauksessa: $e\nStacktrace: $s');
      // Harkitse tiedoston poistamista tai nimeämistä uudelleen, jos se on korruptoitunut
      // await _poistaKorruptoitunutTiedosto();
      return [];
    }
  }

  Future<void> tallennaKysymyksetPankkiin(List<Kysymys> kysymykset) async {
    try {
      final file = await _localFile;
      final List<Map<String, dynamic>> jsonData = kysymykset.map((k) => k.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
      debugPrint("${kysymykset.length} kysymystä tallennettu pankkiin '$_fileName'.");
    } catch (e) {
      debugPrint('Virhe kysymyspankin tallennuksessa: $e');
    }
  }

  Future<List<Kysymys>> lisaaKysymyksetJosUniikkeja(List<Kysymys> ehdokkaat) async {
    List<Kysymys> nykyisetPankissa = await lataaKysymyksetPankista();
    Set<String> nykyisetNormalisoidutTekstit = nykyisetPankissa.map((k) => k.normalisoituKysymysTeksti).toSet();
    List<Kysymys> lisatytKysymykset = [];

    for (var ehdokas in ehdokkaat) {
      final String normalisoituEhdokasTeksti = ehdokas.normalisoituKysymysTeksti;
      if (!nykyisetNormalisoidutTekstit.contains(normalisoituEhdokasTeksti)) {
        // Kysymys-luokan konstruktori hoitaa ID:n ja lisattyPvm, jos ne ovat null
        nykyisetPankissa.add(ehdokas);
        nykyisetNormalisoidutTekstit.add(normalisoituEhdokasTeksti);
        lisatytKysymykset.add(ehdokas);
        debugPrint("Lisätään uniikki kysymys pankkiin: ${ehdokas.kysymysTeksti}");
      } else {
        debugPrint("Duplikaatti hylätty pankkiin lisäyksessä: ${ehdokas.kysymysTeksti}");
      }
    }

    if (lisatytKysymykset.isNotEmpty) {
      await tallennaKysymyksetPankkiin(nykyisetPankissa); // Tallenna koko päivitetty lista
    }
    return lisatytKysymykset;
  }

  Future<void> tyhjennaKysymyspankki() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        debugPrint("Kysymyspankki '$_fileName' tyhjennetty.");
      } else {
        debugPrint("Kysymyspankkia '$_fileName' ei ollut olemassa, ei tarvetta tyhjentää.");
      }
    } catch (e) {
      debugPrint("Virhe kysymyspankin tyhjennyksessä: $e");
    }
  }

// Mahdollinen apumetodi korruptoituneen tiedoston käsittelyyn
// Future<void> _poistaKorruptoitunutTiedosto() async {
//   try {
//     final file = await _localFile;
//     if (await file.exists()) {
//       final korruptoitunutFile = File('${file.path}_korruptoitunut_${DateTime.now().millisecondsSinceEpoch}.json');
//       await file.rename(korruptoitunutFile.path);
//       debugPrint("Korruptoitunut kysymyspankkitiedosto nimetty uudelleen: ${korruptoitunutFile.path}");
//     }
//   } catch (e) {
//     debugPrint("Virhe korruptoituneen tiedoston uudelleennimeämisessä: $e");
//   }
// }
}