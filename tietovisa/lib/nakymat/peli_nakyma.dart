import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../tarjoajat/trivia_tarjoaja.dart';
import '../tarjoajat/asetukset_tarjoaja.dart';
import '../palvelut/puhepalvelu.dart';
import 'tulokset_nakyma.dart';

class PeliNakyma extends StatefulWidget {
  final String kayttajaNimi;

  const PeliNakyma({super.key, required this.kayttajaNimi});

  @override
  State<PeliNakyma> createState() => PeliNakymaTila();
}

class PeliNakymaTila extends State<PeliNakyma> {
  late AudioPlayer _audioPlayer;
  late final Puhepalvelu _puhe;
  Timer? _timer;
  int _aikaJaljella = 20;
  bool kysymykseenVastattu = false;
  bool _isListening = false;
  Timer? _listeningStartTimer;
  Timer? _microphoneTimer;
  int _microphoneTimeLeft = 5;
  bool _showMicrophoneUI = false;
  List<String> _vastaukset = [];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      // Taustamusiikki
      if (asetukset.aanetKaytossa) {
        _soitaTaustamusiikki(asetukset.aanenVoimakkuus);
      }
      // Puhepalvelu (STT/TTS)
      _puhe = Provider.of<Puhepalvelu>(context, listen: false);
      _puhe.initSpeech().then((available) {
        if (!available) debugPrint('Speech-to-Text ei ole saatavilla');
      });
      // Haetaan kysymykset valitulla vaikeustasolla
      final String valittu = asetukset.valittuVaikeustaso ?? 'Helppo';
      String apiTaso;
      switch (valittu) {
        case 'Keskitaso':
          apiTaso = 'medium';
          break;
        case 'Vaikea':
          apiTaso = 'hard';
          break;
        case 'Helppo':
        default:
          apiTaso = 'easy';
      }
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, apiTaso, context)
          .then((_) async {
        await _paivitaVastaukset();
        _aloitaAikalaskuri();
      });
    });
  }

  Future<void> _soitaTaustamusiikki(int voimakkuus) async {
    await _audioPlayer.setVolume(voimakkuus / 100);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/background_music.mp3'));
  }

  Future<void> _paivitaVastaukset() async {
    final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      // Sekoitetaan vastaukset
      final sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle();
      setState(() => _vastaukset = sekoitetut);

      // Lue kysymys ääneen käyttäjän asetusten mukaan
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.kaytaTts) {
        await _puhe.speak(
          kysymys.kysymysTeksti,
          rate: asetukset.ttsRate,
          pitch: asetukset.ttsPitch,
          volume: asetukset.aanenVoimakkuus / 100,
        );
      }
    }
  }

  void _aloitaAikalaskuri() {
    _timer?.cancel();
    _aikaJaljella = 20;
    kysymykseenVastattu = false;
    _stopListening();
    _hideMicrophoneUI();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--;
          if (_aikaJaljella == 10) _startListeningWithDelay();
        } else {
          timer.cancel();
          _lukitseKysymys();
        }
      });
    });
  }

  void _startListeningWithDelay() {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    if (asetukset.kaytaSpeechToText &&
        !kysymykseenVastattu &&
        !_isListening &&
        _puhe.isInitialized) {
      _listeningStartTimer?.cancel();
      _listeningStartTimer = Timer(const Duration(seconds: 0), () {
        _startListening();
        _showMicrophoneUIWithTimer();
      });
    }
  }

  void _lukitseKysymys() {
    if (!kysymykseenVastattu) {
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .vastaaKysymykseen(false);
      naytaPisteetSnackBar(context, false);
      setState(() => kysymykseenVastattu = true);
      _stopListening();
      _hideMicrophoneUI();
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
      _hideMicrophoneUI();
    } else {
      _startListening();
      _showMicrophoneUIWithTimer();
    }
  }

  void _startListening() async {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    if (asetukset.kaytaSpeechToText &&
        !kysymykseenVastattu &&
        !_isListening) {
      if (_puhe.isInitialized) {
        _puhe.startListening(onResult: _onSpeechResult);
        setState(() => _isListening = true);
      } else {
        debugPrint("Puhepalvelu ei ole alustettu.");
      }
    }
  }

  void _stopListening() {
    _puhe.stopListening();
    _listeningStartTimer?.cancel();
    _microphoneTimer?.cancel();
    setState(() {
      _isListening = false;
      _showMicrophoneUI = false;
    });
  }

  void _showMicrophoneUIWithTimer() {
    _microphoneTimer?.cancel();
    _microphoneTimeLeft = 5;
    setState(() => _showMicrophoneUI = true);

    _microphoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_microphoneTimeLeft > 0) {
          _microphoneTimeLeft--;
        } else {
          timer.cancel();
          _hideMicrophoneUI();
        }
      });
    });
  }

  void _hideMicrophoneUI() {
    _microphoneTimer?.cancel();
    setState(() {
      _showMicrophoneUI = false;
      _microphoneTimeLeft = 5;
    });
  }

  void _onSpeechResult(String recognized) {
    final input = recognized.toLowerCase().trim();
    final trivia = Provider.of<TriviaTarjoaja>(context, listen: false);
    final kys = trivia.kysymykset[trivia.nykyinenIndeksi];
    final oikea = kys.oikeaVastaus.toLowerCase();

    bool oikein = input == oikea;
    if (!oikein) {
      for (var v in _vastaukset) {
        if (input == v.toLowerCase()) {
          oikein = v == kys.oikeaVastaus;
          break;
        }
      }
    }

    if (!kysymykseenVastattu) {
      trivia.vastaaKysymykseen(oikein);
      naytaPisteetSnackBar(context, oikein);
      setState(() {
        kysymykseenVastattu = true;
        _isListening = false;
      });
      _timer?.cancel();
      _stopListening();
      _hideMicrophoneUI();
    }
  }

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

  void siirryTuloksetNakymaan(TriviaTarjoaja triviaTarjoaja) {
    _timer?.cancel();
    _stopListening();
    _hideMicrophoneUI();
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
    _audioPlayer.dispose();
    _timer?.cancel();
    _puhe.dispose();
    _listeningStartTimer?.cancel();
    _microphoneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tietovisa'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,   // kaikki AppBarin tekstit ja ikonit valkoisiksi
        titleTextStyle: const TextStyle(
          color: Colors.white,           // otsikon väri (yllä päällekkäin foregrounColorin kanssa)
          fontWeight: FontWeight.bold,   // boldattu
          fontSize: 24,                  // haluttu fonttikoko (voit säätää tarpeen mukaan)
        ),
        actions: [
          Consumer<AsetuksetTarjoaja>(
            builder: (_, aset, __) {
              if (!aset.kaytaSpeechToText) return const SizedBox();
              return IconButton(
                icon:
                Icon(_isListening ? Icons.mic_off : Icons.mic_none),
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
                image: AssetImage('assets/images/peli_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Trivia-sisältö
          Consumer<TriviaTarjoaja>(
            builder: (context, triviaTarjoaja, child) {
              if (triviaTarjoaja.onLataus) {
                return const Center(child: CircularProgressIndicator());
              }
              if (triviaTarjoaja.virhe != null) {
                return Center(
                  child: Text(
                    triviaTarjoaja.virhe!,
                    style: const TextStyle(
                        fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (triviaTarjoaja.kysymykset.isEmpty) {
                return const Center(
                    child: Text("Kysymyksiä ei löytynyt."));
              }
              if (triviaTarjoaja.nykyinenIndeksi >=
                  triviaTarjoaja.kysymykset.length) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) {
                  siirryTuloksetNakymaan(triviaTarjoaja);
                });
                return const SizedBox();
              }

              final kysymys = triviaTarjoaja
                  .kysymykset[triviaTarjoaja.nykyinenIndeksi];

              return Column(
                children: [
                  const SizedBox(height: 50),

                  // Tekstin ympärille 8 pikselin pystysuuntainen padding
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Tervetuloa, ${widget.kayttajaNimi}!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Kysymys ${triviaTarjoaja.nykyinenIndeksi + 1}/${triviaTarjoaja.kysymykset.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Aikaa jäljellä: $_aikaJaljella sekuntia',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            kysymys.kysymysTeksti,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // Vastausvaihtoehdot
                          ..._vastaukset.map((vastaus) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],   // Taustaväri
                                  foregroundColor: Colors.white, // Tekstin väri
                                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Lisätyylit, esim. bold
                                ),
                                onPressed: kysymykseenVastattu
                                    ? null
                                    : () {
                                  final oikein = vastaus ==
                                      kysymys.oikeaVastaus;
                                  naytaPisteetSnackBar(
                                      context, oikein);
                                  triviaTarjoaja
                                      .vastaaKysymykseen(oikein);
                                  setState(() {
                                    kysymykseenVastattu =
                                    true;
                                  });
                                  _timer?.cancel();
                                  _stopListening();
                                  _hideMicrophoneUI();
                                },
                                child: Text(vastaus),
                              ),
                            );
                          }),
                          // Seuraava-painike
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],   // Taustaväri
                              foregroundColor: Colors.white, // Tekstin väri
                              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Lisätyylit, esim. bold
                            ),
                            onPressed: kysymykseenVastattu
                                ? () {
                              setState(() {
                                kysymykseenVastattu =
                                false;
                              });
                              if (triviaTarjoaja
                                  .nykyinenIndeksi <
                                  triviaTarjoaja.kysymykset
                                      .length -
                                      1) {
                                triviaTarjoaja
                                    .seuraavaKysymys();
                                _paivitaVastaukset();
                                _aloitaAikalaskuri();
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TuloksetNakyma(
                                          kayttajaNimi:
                                          widget.kayttajaNimi,
                                          pisteet:
                                          triviaTarjoaja
                                              .pisteet,
                                        ),
                                  ),
                                );
                              }
                            }
                                : null,
                            child:
                            const Text('Seuraava kysymys'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Mikrofonin UI
          if (_showMicrophoneUI)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                    BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isListening
                            ? Icons.mic_off
                            : Icons.mic_none,
                        color: _isListening
                            ? Colors.redAccent
                            : Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$_microphoneTimeLeft s',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
