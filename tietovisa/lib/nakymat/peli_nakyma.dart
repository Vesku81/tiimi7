import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import 'package:audioplayers/audioplayers.dart'; // Audioplayer ääniä varten
import 'dart:async'; // Aikalaskuria varten tarvittava kirjasto
import '../tarjoajat/trivia_tarjoaja.dart'; // Trivia-pelin tila
import '../tarjoajat/asetukset_tarjoaja.dart'; // Asetusten tarjoaja
import '../palvelut/puhepalvelu.dart'; // Puhepalvelu (STT & TTS)
import 'tulokset_nakyma.dart'; // Tulokset-näkymä

class PeliNakyma extends StatefulWidget {
  final String kayttajaNimi;

  const PeliNakyma({super.key, required this.kayttajaNimi});

  @override
  State<PeliNakyma> createState() => PeliNakymaTila();
}

class PeliNakymaTila extends State<PeliNakyma> {
  late AudioPlayer _audioPlayer;      // Ääntenhallinta
  late final Puhepalvelu _puhe;       // Puhepalvelu instanssi
  Timer? _timer;                      // Aikalaskurin hallinta
  int _aikaJaljella = 20;             // Kysymyksille määritelty 10 sekunnin aika
  bool kysymykseenVastattu = false;   // Estää useamman vastauksen
  bool _isListening = false;          // Puhekuuntelun tila

  // Lista, joka sisältää sekoitetut vastausvaihtoehdot ja se päivitetään uuden kysymyksen alkaessa.
  List<String> _vastaukset = [];

  @override
  void initState() {
    super.initState();

    // Alustetaan Audioplayer
    _audioPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.aanetKaytossa) {
        _soitaTaustamusiikki(asetukset.aanenVoimakkuus);
      }

      // Alustetaan puhepalvelu
      _puhe = Provider.of<Puhepalvelu>(context, listen: false);
      _puhe.initSpeech().then((available) {
        if (!available) {
          debugPrint('Speech-to-Text ei ole saatavilla');
        }
      });

      // Haetaan kysymykset ja aloitetaan laskuri
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, 'easy', context)
          .then((_) {
        _paivitaVastaukset();   // Päivitetään vastausvaihtoehdot
        _aloitaAikalaskuri();    // Aloitetaan aikalaskuri

        // Vaihe 2 automaattisesti: aloitetaan puhekuuntelu
        if (Provider.of<AsetuksetTarjoaja>(context, listen: false).kaytaSpeechToText) {
          _puhe.startListening(onResult: _onSpeechResult);
        }
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
    final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      List<String> sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle();
      setState(() {
        _vastaukset = sekoitetut;
      });
    }
  }

  // Aloitetaan aikalaskuri
  void _aloitaAikalaskuri() {
    _timer?.cancel();        // Nollataan edellinen laskuri
    _aikaJaljella = 20;      // Aikaa 10 sekuntia
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--;   // Aika vähenee
        } else {
          timer.cancel();
          _lukitseKysymys(); // Aika loppui
        }
      });
    });
  }

  // Lukitsee kysymyksen ja vähentää 5 pistettä
  void _lukitseKysymys() {
    if (!kysymykseenVastattu) {
      Provider.of<TriviaTarjoaja>(context, listen: false).vastaaKysymykseen(false);
      naytaPisteetSnackBar(context, false);
      setState(() {
        kysymykseenVastattu = true;
      });
    }
  }

  // Vaihe 2: togglaa puhekuuntelun
  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      _puhe.startListening(onResult: _onSpeechResult);
    } else {
      _puhe.stopListening();
    }
  }

  // Vaiheet 3 & 4: käsittelee tunnistetun puhetekstin ja rekisteröi vastauksen
  void _onSpeechResult(String recognized) {
    final input = recognized.toLowerCase().trim();
    final trivia = Provider.of<TriviaTarjoaja>(context, listen: false);
    final kys = trivia.kysymykset[trivia.nykyinenIndeksi];
    final oikea = kys.oikeaVastaus.toLowerCase();

    bool oikein = false;
    if (input == oikea) {
      oikein = true;
    } else {
      for (var v in _vastaukset) {
        if (input == v.toLowerCase()) {
          oikein = v == kys.oikeaVastaus;
          break;
        }
      }
    }

    trivia.vastaaKysymykseen(oikein);
    naytaPisteetSnackBar(context, oikein);
    setState(() {
      kysymykseenVastattu = true;
      _isListening = false;
    });
    _timer?.cancel();
    _puhe.stopListening();
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

  // Siirrytään tulokset-sivulle, kun peli päättyy
  void siirryTuloksetNakymaan(TriviaTarjoaja triviaTarjoaja) {
    _timer?.cancel();
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
    _timer?.cancel();        // Lopetetaan aikalaskuri
    _puhe.dispose();         // Suljetaan puhepalvelu
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Keskitetään AppBarin otsikko
        title: const Text('TriviaVisa'),
        backgroundColor: Colors.deepPurpleAccent,
        actions: [
          Consumer<AsetuksetTarjoaja>(
            builder: (_, aset, __) {
              if (!aset.kaytaSpeechToText) return const SizedBox();
              return IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                onPressed: _toggleListening,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Trivia-pelin sisältö
          Consumer<TriviaTarjoaja>(
            builder: (context, triviaTarjoaja, child) {
              if (triviaTarjoaja.onLataus) {
                return const Center(child: CircularProgressIndicator());
              }
              if (triviaTarjoaja.virhe != null) {
                return Center(
                  child: Text(
                    triviaTarjoaja.virhe!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (triviaTarjoaja.kysymykset.isEmpty) {
                return const Center(child: Text("Kysymyksiä ei löytynyt."));
              }
              if (triviaTarjoaja.nykyinenIndeksi >= triviaTarjoaja.kysymykset.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  siirryTuloksetNakymaan(triviaTarjoaja);
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
                                  bool oikein = vastaus == kysymys.oikeaVastaus;
                                  naytaPisteetSnackBar(context, oikein);
                                  triviaTarjoaja.vastaaKysymykseen(oikein);
                                  setState(() {
                                    kysymykseenVastattu = true;
                                  });
                                  _timer?.cancel();
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
                                kysymykseenVastattu = false;
                              });
                              if (triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length - 1) {
                                triviaTarjoaja.seuraavaKysymys();
                                _paivitaVastaukset();
                                _aloitaAikalaskuri();

                                // Vaihe 2 automaattisesti: aloitetaan puhekuuntelu
                                if (Provider.of<AsetuksetTarjoaja>(context, listen: false).kaytaSpeechToText) {
                                  _puhe.startListening(onResult: _onSpeechResult);
                                }
                              } else {
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
                            child: const Text('Seuraava kysymys'),
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
