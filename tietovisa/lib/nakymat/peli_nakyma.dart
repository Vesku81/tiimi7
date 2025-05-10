import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import 'package:audioplayers/audioplayers.dart'; // Audioplayer ääniä varten
import 'dart:async'; // Aikalaskuria varten tarvittava kirjasto
import '../tarjoajat/trivia_tarjoaja.dart'; // Trivia-pelin tila
import '../tarjoajat/asetukset_tarjoaja.dart'; // Asetusten tarjoaja
import 'tulokset_nakyma.dart'; // Tulokset-näkymä

class PeliNakyma extends StatefulWidget {
  final String kayttajaNimi;

  const PeliNakyma({super.key, required this.kayttajaNimi});

  @override
  State<PeliNakyma> createState() => PeliNakymaTila();
}

class PeliNakymaTila extends State<PeliNakyma> {
  late AudioPlayer _audioPlayer; // Ääntenhallinta
  Timer? _timer; // Aikalaskurin hallinta
  int _aikaJaljella = 10; // Kysymyksille määritelty 10 sekunnin aika
  bool kysymykseenVastattu = false; // Estää useamman vastauksen, jotta pelaaja voi vastata vain kerran

  // Lista, joka sisältää sekoitetut vastausvaihtoehdot ja se päivitetään uuden kysymyksen alkaessa.
  List<String> _vastaukset = [];

  @override
  void initState() {
    super.initState();

    // Alustetaan Audioplayer
    _audioPlayer = AudioPlayer();

    // Tarkistetaan, onko äänet päällä ja soitetaanko taustamusiikkia
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.aanetKaytossa) {
        _soitaTaustamusiikki(asetukset.aanenVoimakkuus);
      }

      // Haetaan kysymykset ja aloitetaan laskuri
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, 'easy')
          .then((_) {
        _paivitaVastaukset(); // Päivitetään vastausvaihtoehdot kysymykselle
        _aloitaAikalaskuri(); // Aloitetaan aikalaskuri
      });
    });
  }

  // Funktio, joka soittaa taustamusiikkia
  Future<void> _soitaTaustamusiikki(int voimakkuus) async {
    await _audioPlayer.setVolume(voimakkuus / 100);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/background_music.mp3'));
  }

  // Funktio, joka sekoittaa vastausvaihtoehdot uuden kysymyksen alkaessa
  void _paivitaVastaukset() {
    final triviaTarjoaja =
    Provider.of<TriviaTarjoaja>(context, listen: false);
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys =
      triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      // Luodaan uusi lista, johon lisätään ensin väärät vastaukset ja sen jälkeen oikea vastaus
      List<String> sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle(); // Sekoitetaan vastaukset vain kerran uuden kysymyksen alussa
      setState(() {
        _vastaukset = sekoitetut;
      });
    }
  }

  // Aloitetaan aikalaskuri
  void _aloitaAikalaskuri() {
    _timer?.cancel(); // Nollataan edellinen laskuri
    _aikaJaljella = 10; // Annetaan jokaiselle kysymyksen vastaamiseen 10 sekuntia aikaa
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--; // Aika vähenee joka sekunti
        } else {
          timer.cancel();
          _lukitseKysymys(); // Lukitaan vastaus, kun aika loppuu
        }
      });
    });
  }

  // Lukitsee kysymyksen ja vähentää 5 pistettä, jos aikaa ei ole jäljellä
  void _lukitseKysymys() {
    if (!kysymykseenVastattu) {
      Provider.of<TriviaTarjoaja>(context, listen: false).vastaaKysymykseen(false);
      naytaPisteetSnackBar(context, false); // Näytetään -5 pistettä ilmoitus SnackBarissa
      setState(() {
        kysymykseenVastattu = true; // Estetään uudelleen vastaaminen
      });
    }
  }

  // Näytetään SnackBarin avulla pisteiden lisäys tai vähennys
  void naytaPisteetSnackBar(BuildContext context, bool oikein) {
    final snackBar = SnackBar(
      content: Text(
        oikein ? '+20 pistettä!' : '-5 pistettä!',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: oikein ? Colors.green : Colors.red,
      duration: const Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Siirrytään tulokset-sivulle, kun kaikki kysymykset on vastattu ja peli päättyy
  void siirryTuloksetNakymaan(TriviaTarjoaja triviaTarjoaja) {
    _timer?.cancel(); // Lopetetaan laskuri
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TuloksetNakyma(
          kayttajaNimi: widget.kayttajaNimi,
          pisteet: triviaTarjoaja.pisteet,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Vapautetaan audioplayerin resurssit
    _timer?.cancel(); // Lopetetaan laskuri
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Keskitetään AppBarin otsikko
        title: const Text('TriviaVisa'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'), // Sivun taustakuva
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Trivia-pelin sisältö
          Consumer<TriviaTarjoaja>(
            builder: (context, triviaTarjoaja, child) {
              if (triviaTarjoaja.onLataus) {
                return const Center(child: CircularProgressIndicator()); // Näytetään latausanimaatio
              }

              if (triviaTarjoaja.virhe != null) {
                return Center(
                  child: Text(
                    triviaTarjoaja.virhe!, // Näytetään mahdollinen virheviesti
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (triviaTarjoaja.kysymykset.isEmpty) {
                return const Center(child: Text("Kysymyksiä ei löytynyt."));
              }

              // Tarkistetaan, onko kaikkiin kysymyksiin vastattu ja peli päättynyt
              if (triviaTarjoaja.nykyinenIndeksi >= triviaTarjoaja.kysymykset.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  siirryTuloksetNakymaan(triviaTarjoaja); // Siirrytään tulokset-sivulle
                });
                return const SizedBox();
              }

              // Haetaan nykyinen kysymys
              final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];

              return Column(
                children: [
                  const SizedBox(height: 50),
                  Text(
                    'Tervetuloa, ${widget.kayttajaNimi}!',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kysymys ${triviaTarjoaja.nykyinenIndeksi + 1}/${triviaTarjoaja.kysymykset.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aikaa jäljellä: $_aikaJaljella sekuntia',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.yellow),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            kysymys.kysymysTeksti,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // Näytetään sekoitetut vastausvaihtoehdot
                          ..._vastaukset.map((vastaus) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                onPressed: kysymykseenVastattu
                                    ? null
                                    : () {
                                  bool oikein =
                                      vastaus == kysymys.oikeaVastaus;
                                  naytaPisteetSnackBar(context, oikein);
                                  triviaTarjoaja.vastaaKysymykseen(oikein);
                                  setState(() {
                                    kysymykseenVastattu = true; // Lukitaan vastaus
                                  });
                                  _timer?.cancel(); // Lopetetaan aikalaskuri
                                },
                                child: Text(vastaus),
                              ),
                            );
                          }),
                          // Seuraava kysymys -painike
                          ElevatedButton(
                            onPressed: kysymykseenVastattu
                                ? () {
                              setState(() {
                                kysymykseenVastattu = false; // Nollataan tila seuraavaa kysymystä varten
                              });
                              if (triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length - 1) {
                                triviaTarjoaja.seuraavaKysymys(); // Siirrytään seuraavaan kysymykseen
                                _paivitaVastaukset(); // Sekoitetaan vastausvaihtoehdot uuden kysymyksen alussa
                                _aloitaAikalaskuri(); // Aloitetaan uusi aikalaskuri
                              } else {
                                // Kaikkiin kysymyksiin on vastattu, siirrytään tulokset-sivulle
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TuloksetNakyma(
                                      kayttajaNimi: widget.kayttajaNimi,
                                      pisteet: triviaTarjoaja.pisteet,
                                    ),
                                  ),
                                );
                              }
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Seuraava kysymys'), // Painikkeen teksti
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
