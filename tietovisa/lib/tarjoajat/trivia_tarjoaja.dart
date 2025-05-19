// tarjoajat/trivia_tarjoaja.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math'; // Satunnaislukugeneraattoriin
import 'package:html_unescape/html_unescape.dart';
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import '../palvelut/openai_palvelu.dart';
import '../palvelut/kysymyspankki_palvelu.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'asetukset_tarjoaja.dart';

class TriviaTarjoaja with ChangeNotifier {
  final TriviaApiPalvelu _triviaApiPalvelu = TriviaApiPalvelu();
  final OpenAIPalvelu _openAIPalvelu = OpenAIPalvelu();
  final KysymyspankkiPalvelu _kysymyspankkiPalvelu = KysymyspankkiPalvelu();
  final HtmlUnescape _htmlUnescape = HtmlUnescape(); // Instanssi HTML-entiteettien dekoodaukseen
  final Random _random = Random();

  List<Kysymys> _pelinKysymykset = [];
  int _nykyinenIndeksi = 0;
  int _pisteet = 0;
  bool _onLataus = false;
  String? _virhe;

  final OnDeviceTranslator _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.finnish,
  );
  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();

  TriviaTarjoaja() {
    _varmistaKaannosmallit();
  }

  Future<void> _varmistaKaannosmallit() async {
    try {
      final englishDownloaded = await _modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode);
      if (!englishDownloaded) {
        debugPrint("Ladataan englannin käännösmallia...");
        await _modelManager.downloadModel(TranslateLanguage.english.bcpCode, isWifiRequired: false);
        debugPrint("Englannin käännösmalli ladattu.");
      }
      final finnishDownloaded = await _modelManager.isModelDownloaded(TranslateLanguage.finnish.bcpCode);
      if (!finnishDownloaded) {
        debugPrint("Ladataan suomen käännösmallia...");
        await _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode, isWifiRequired: false);
        debugPrint("Suomen käännösmalli ladattu.");
      }
    } catch (e) {
      debugPrint("Virhe käännösmallien latauksessa/tarkistuksessa: $e");
    }
  }

  List<Kysymys> get kysymykset => _pelinKysymykset;
  int get nykyinenIndeksi => _nykyinenIndeksi;
  int get pisteet => _pisteet;
  bool get onLataus => _onLataus;
  String? get virhe => _virhe;

  Future<void> haeKysymykset(
      int pyydettyMaara,
      String vaikeus,
      BuildContext context,
      ) async {
    if (pyydettyMaara <= 0) {
      _virhe = "Kysymysten määrän tulee olla positiivinen.";
      _pelinKysymykset = [];
      _onLataus = false;
      notifyListeners();
      return;
    }
    _onLataus = true;
    _virhe = null;
    _pelinKysymykset = [];
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    notifyListeners();

    try {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI = asetukset.kaytaOpenAIKysymyksia;
      final kaytaKaannoksetPerinteiselleAPIlle = asetukset.kaytaKaannokset;
      final String valittuAihealueOpenAI = asetukset.valittuAihealue;

      List<Kysymys> kaikkiPankinKysymykset = await _kysymyspankkiPalvelu.lataaKysymyksetPankista();
      List<Kysymys> ehdokkaatPeliin = [];

      List<Kysymys> sopivatPankista = kaikkiPankinKysymykset.where((k) {
        bool vaikeusOk = k.vaikeus?.toLowerCase() == vaikeus.toLowerCase() || vaikeus.toLowerCase() == "any";
        bool kategoriaOk;
        if (kaytaOpenAI) {
          kategoriaOk = k.lahde == "openai_generoitu" && k.kategoria?.toLowerCase() == valittuAihealueOpenAI.toLowerCase();
        } else {
          kategoriaOk = (k.lahde == "trivia_api_käännetty" || k.lahde == "trivia_api_alkuperainen");
        }
        return vaikeusOk && kategoriaOk;
      }).toList();

      sopivatPankista.shuffle(_random);
      ehdokkaatPeliin.addAll(sopivatPankista.take(pyydettyMaara));
      debugPrint("Löytyi ${ehdokkaatPeliin.length} sopivaa kysymystä paikallisesta pankista (Lähde: ${kaytaOpenAI ? 'OpenAI' : 'API'}, Kategoria: ${kaytaOpenAI ? valittuAihealueOpenAI : 'API-kategoriat'}, Vaikeus: $vaikeus).");

      int tarvitaanLisaa = pyydettyMaara - ehdokkaatPeliin.length;

      if (tarvitaanLisaa > 0) {
        debugPrint("Tarvitaan $tarvitaanLisaa lisäkysymystä lähteestä.");
        List<Kysymys> uudetGeneroidutTaiHaetut = [];

        Set<String> olemassaolevatTekstit = ehdokkaatPeliin.map((k) => k.normalisoituKysymysTeksti).toSet();
        // KORJAUS 2: Muutetaan forEach for-in silmukaksi
        for (var k in kaikkiPankinKysymykset) {
          olemassaolevatTekstit.add(k.normalisoituKysymysTeksti);
        }

        if (kaytaOpenAI) {
          debugPrint("Haetaan OpenAI:lta aiheesta '$valittuAihealueOpenAI' ($vaikeus)...");
          int yrityksetOpenAI = 0;
          int maksimiGenerointiyritykset = (tarvitaanLisaa * 2) + 5;
          while (uudetGeneroidutTaiHaetut.length < tarvitaanLisaa && yrityksetOpenAI < maksimiGenerointiyritykset) {
            yrityksetOpenAI++;
            Kysymys? raakaKysymys = await _openAIPalvelu.generoiYksiKysymys(valittuAihealueOpenAI, vaikeus);
            if (raakaKysymys != null) {
              String kysymysTekstiOpenAI = _htmlUnescape.convert(raakaKysymys.kysymysTeksti);
              String oikeaVastausOpenAI = _htmlUnescape.convert(raakaKysymys.oikeaVastaus);
              List<String> vaaratVastauksetOpenAI = raakaKysymys.vaaratVastaukset.map((v) => _htmlUnescape.convert(v)).toList();

              // KORJAUS 1: Lisätään 'lahde' parametri
              final Kysymys tarkistettavaKysymysOpenAI = Kysymys(
                kysymysTeksti: kysymysTekstiOpenAI,
                oikeaVastaus: oikeaVastausOpenAI,
                vaaratVastaukset: vaaratVastauksetOpenAI,
                lahde: "openai_generoitu", // Lisätty vaadittu lahde-parametri
                // kategoria ja vaikeus eivät välttämättä ole pakollisia tässä
                // väliaikaisessa oliossa, jos Kysymys-konstruktori sallii niiden olevan null.
                // Jos ne ovat pakollisia, nekin pitää lisätä:
                // kategoria: valittuAihealueOpenAI,
                // vaikeus: vaikeus,
              );

              if (!olemassaolevatTekstit.contains(tarkistettavaKysymysOpenAI.normalisoituKysymysTeksti)) {
                final Kysymys taydennettyUusi = Kysymys(
                  kysymysTeksti: kysymysTekstiOpenAI,
                  oikeaVastaus: oikeaVastausOpenAI,
                  vaaratVastaukset: vaaratVastauksetOpenAI,
                  kategoria: valittuAihealueOpenAI,
                  vaikeus: vaikeus,
                  lahde: "openai_generoitu",
                );
                uudetGeneroidutTaiHaetut.add(taydennettyUusi);
                olemassaolevatTekstit.add(taydennettyUusi.normalisoituKysymysTeksti);
                debugPrint("OpenAI: Generoitu uniikki (HTML-dekoodattu): ${taydennettyUusi.kysymysTeksti}");
              } else {
                debugPrint("OpenAI: Generoitu duplikaatti hylätty (HTML-dekoodattu): $kysymysTekstiOpenAI");
              }
            }
            if (uudetGeneroidutTaiHaetut.length < tarvitaanLisaa && yrityksetOpenAI < maksimiGenerointiyritykset) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          } // while (OpenAI)
        } else { // Käytä perinteistä Trivia API:a
          debugPrint("Haetaan Trivia API:sta (vaikeus: $vaikeus)...");
          int apiFetchAmount = (tarvitaanLisaa * 1.5).ceil(); // Haetaan hieman enemmän varalle
          if (apiFetchAmount < tarvitaanLisaa + 3) apiFetchAmount = tarvitaanLisaa + 3;

          List<dynamic> apiData = await _triviaApiPalvelu.haeKysymyksetRaaAllaDatalistana(
            amount: apiFetchAmount,
            difficulty: vaikeus == "any" ? null : vaikeus,
            // category: Voitaisiin lisätä, jos AsetuksetTarjoajassa olisi API-kohtainen kategoriavalinta
          );

          for (var data in apiData) {
            if (uudetGeneroidutTaiHaetut.length >= tarvitaanLisaa) break;

            String kysymysTeksti = data['question'] as String? ?? "Virheellinen kysymysdata";
            String oikeaVastaus = data['correct_answer'] as String? ?? "Virheellinen vastausdata";
            List<dynamic> incorrectAnswersDynamic = data['incorrect_answers'] as List<dynamic>? ?? [];
            List<String> vaaratVastaukset = incorrectAnswersDynamic.map((ans) => ans.toString()).toList();
            String? kategoriaApi = data['category'] as String?;
            String? vaikeusApi = data['difficulty'] as String?;
            String? tyyppiApi = data['type'] as String?;

            // 1. DEKOODAA HTML-ENTITEETIT ALKUPERÄISISTÄ TEKSTEISTÄ (API:lta saaduista)
            kysymysTeksti = _htmlUnescape.convert(kysymysTeksti);
            oikeaVastaus = _htmlUnescape.convert(oikeaVastaus);
            vaaratVastaukset = vaaratVastaukset.map((v) => _htmlUnescape.convert(v)).toList();
            if (kategoriaApi != null) kategoriaApi = _htmlUnescape.convert(kategoriaApi);
            if (vaikeusApi != null) vaikeusApi = _htmlUnescape.convert(vaikeusApi);
            if (tyyppiApi != null) tyyppiApi = _htmlUnescape.convert(tyyppiApi);

            // Tarkista virheellinen data HTML-dekoodattujen arvojen perusteella
            // Vertaillaan dekoodattuun virhetekstiin, jos virheteksti itsessään voisi sisältää entiteettejä (epätodennäköistä, mutta varmaa)
            if (kysymysTeksti == _htmlUnescape.convert("Virheellinen kysymysdata") ||
                oikeaVastaus == _htmlUnescape.convert("Virheellinen vastausdata") ||
                vaaratVastaukset.isEmpty || vaaratVastaukset.any((v) => v.isEmpty)) { // Tarkistetaan myös tyhjät vastaukset listassa
              debugPrint("API: Virheellistä dataa vastaanotettu (HTML-dekoodauksen jälkeen), skipataan kysymys: $data");
              continue;
            }

            if (kaytaKaannoksetPerinteiselleAPIlle) {
              try {
                // Käännä jo HTML-dekoodatut tekstit
                kysymysTeksti = await _translator.translateText(kysymysTeksti);
                oikeaVastaus = await _translator.translateText(oikeaVastaus);
                List<String> kaannetytVaarat = [];
                for (String vaara in vaaratVastaukset) {
                  kaannetytVaarat.add(await _translator.translateText(vaara));
                }
                vaaratVastaukset = kaannetytVaarat;

                // 2. DEKOODAA HTML-ENTITEETIT MYÖS KÄÄNNETYISTÄ TEKSTEISTÄ
                kysymysTeksti = _htmlUnescape.convert(kysymysTeksti);
                oikeaVastaus = _htmlUnescape.convert(oikeaVastaus);
                vaaratVastaukset = vaaratVastaukset.map((v) => _htmlUnescape.convert(v)).toList();

                debugPrint("API: Kysymys käännetty ja HTML-dekoodattu: ${kysymysTeksti.substring(0, min(kysymysTeksti.length, 50))}...");
              } catch (e) {
                debugPrint("Virhe kysymyksen kääntämisessä API:sta: $e. Käytetään alkuperäistä (jo HTML-dekoodattua) tekstiä.");
              }
            }

            final Kysymys potentiaalinenUusiApiKysymys = Kysymys(
              kysymysTeksti: kysymysTeksti,
              oikeaVastaus: oikeaVastaus,
              vaaratVastaukset: vaaratVastaukset,
              kategoria: kategoriaApi,
              vaikeus: vaikeusApi,
              tyyppi: tyyppiApi,
              lahde: kaytaKaannoksetPerinteiselleAPIlle ? "trivia_api_käännetty" : "trivia_api_alkuperainen",
            );

            if (!olemassaolevatTekstit.contains(potentiaalinenUusiApiKysymys.normalisoituKysymysTeksti)) {
              uudetGeneroidutTaiHaetut.add(potentiaalinenUusiApiKysymys);
              olemassaolevatTekstit.add(potentiaalinenUusiApiKysymys.normalisoituKysymysTeksti);
              debugPrint("API: Lisätty uniikki (HTML-dekoodattu/käännetty): ${potentiaalinenUusiApiKysymys.kysymysTeksti.substring(0, min(potentiaalinenUusiApiKysymys.kysymysTeksti.length, 50))}...");
            } else {
              debugPrint("API: Duplikaatti hylätty (HTML-dekoodattu/käännetty): ${kysymysTeksti.substring(0, min(kysymysTeksti.length, 50))}...");
            }
          } // for (var data in apiData)
        } // else (eli !kaytaOpenAI)

        // Lisää uudet uniikit kysymykset pankkiin ja sitten peliin
        if (uudetGeneroidutTaiHaetut.isNotEmpty) {
          List<Kysymys> todellaLisatytPankkiin = await _kysymyspankkiPalvelu.lisaaKysymyksetJosUniikkeja(uudetGeneroidutTaiHaetut);
          debugPrint("${todellaLisatytPankkiin.length} uutta kysymystä lisätty onnistuneesti kysymyspankkiin.");
          for (var lisattyPankkiin in todellaLisatytPankkiin) {
            if (ehdokkaatPeliin.length < pyydettyMaara &&
                !ehdokkaatPeliin.any((peliKys) => peliKys.normalisoituKysymysTeksti == lisattyPankkiin.normalisoituKysymysTeksti)) {
              ehdokkaatPeliin.add(lisattyPankkiin);
            }
          }
        }
      } // if (tarvitaanLisaa > 0)

      // Varmista, että pelissä on oikea määrä kysymyksiä ja sekoita ne
      ehdokkaatPeliin.shuffle(_random);
      _pelinKysymykset = ehdokkaatPeliin.take(pyydettyMaara).toList();

      if (_pelinKysymykset.length < pyydettyMaara && pyydettyMaara > 0) {
        _virhe = "Ei saatu tarpeeksi (${_pelinKysymykset.length}/$pyydettyMaara) uniikkeja kysymyksiä valituilla asetuksilla.";
        debugPrint(_virhe);
      } else if (_pelinKysymykset.isEmpty && pyydettyMaara > 0) {
        _virhe = "Kysymyksiä ei löytynyt valituilla asetuksilla.";
        debugPrint(_virhe);
      } else if (_pelinKysymykset.isNotEmpty) {
        debugPrint("Peliin valittu ${_pelinKysymykset.length} kysymystä.");
      }

    } catch (e, s) {
      _pelinKysymykset = [];
      _virhe = "Kysymysten lataamisessa tapahtui odottamaton virhe: $e";
      debugPrint("HaeKysymykset virhe: $_virhe\nStacktrace: $s");
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  } // --- HaeKysymykset-metodin loppu ---

  void vastaaKysymykseen(String valittuVastaus) {
    if (_nykyinenIndeksi < _pelinKysymykset.length) {
      final Kysymys nykyinenKysymys = _pelinKysymykset[_nykyinenIndeksi];
      // Varmistetaan, että sekä valittu vastaus että oikea vastaus ovat HTML-dekoodattuja vertailua varten
      // Oikean vastauksen pitäisi olla jo dekoodattu haeKysymykset-vaiheessa.
      // Valitun vastauksen pitäisi tulla UI:sta jo dekoodattuna (jos se on peräisin Kysymys-oliosta).
      if (valittuVastaus == nykyinenKysymys.oikeaVastaus) {
        _pisteet += 20;
        debugPrint("Oikea vastaus! Pisteet: $_pisteet");
      } else {
        _pisteet -= 5;
        debugPrint("Väärä vastaus. Oikea oli: ${nykyinenKysymys.oikeaVastaus}. Pisteet: $_pisteet");
      }
      notifyListeners();
    }
  }

  bool onkoViimeinenKysymys() {
    if (_pelinKysymykset.isEmpty) return true;
    return _nykyinenIndeksi >= _pelinKysymykset.length - 1;
  }

  void seuraavaKysymys() {
    if (_pelinKysymykset.isEmpty) {
      debugPrint("Ei kysymyksiä, ei voida siirtyä seuraavaan.");
      return;
    }
    if (!onkoViimeinenKysymys()) {
      _nykyinenIndeksi++;
      notifyListeners();
    } else {
      debugPrint("Peli päättyi. Lopulliset pisteet: $_pisteet / ${_pelinKysymykset.length * 20}");
      // Tässä voisi asettaa tilan pelin päättymiselle, jotta UI voi reagoida.
    }
  }

  void nollaaPeli() {
    _pelinKysymykset = [];
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _virhe = null;
    _onLataus = false;
    debugPrint("Peli nollattu TriviaTarjoajassa.");
    notifyListeners();
  }

  Future<void> tyhjennaKokoKysymyspankki() async {
    _onLataus = true;
    notifyListeners();
    try {
      await _kysymyspankkiPalvelu.tyhjennaKysymyspankki();
      nollaaPeli(); // Nollaa myös nykyisen pelitilan
      _virhe = "Kysymyspankki tyhjennetty onnistuneesti."; // Tämä voisi olla myös ilmoitus, ei välttämättä virhe
      debugPrint("Koko kysymyspankki tyhjennetty TriviaTarjoajan kautta.");
    } catch (e) {
      _virhe = "Virhe kysymyspankin tyhjennyksessä: $e";
      debugPrint(_virhe);
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _translator.close();
    debugPrint("TriviaTarjoaja disposed ja translator closed.");
    super.dispose();
  }
}