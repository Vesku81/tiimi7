import 'package:flutter/material.dart';              // Flutterin peruswidgetit ja tyylit
import 'package:shared_preferences/shared_preferences.dart'; // Tallennettujen pistetietojen käsittelyyn
import 'package:audioplayers/audioplayers.dart';    // Äänien toistamiseen
import 'dart:convert';                              // JSON-muotoisten merkkijonojen käsittely
import 'aloitus_nakyma.dart';                       // Etusivun näkymä

/// Näyttää pelin lopputuloksen ja historiapistetilaston.
class TuloksetNakyma extends StatefulWidget {
  final String kayttajaNimi; // Pelaajan nimi
  final int? pisteet;        // Tämä pelisession pisteet (null jos tulokkaasta valitaan drawerin kautta)

  const TuloksetNakyma({super.key, required this.kayttajaNimi, this.pisteet});

  @override
  State<TuloksetNakyma> createState() => _TuloksetNakymaTila();
}

/// Hallinnoi pistetietojen latausta, äänien soittamista ja listan näyttämistä.
class _TuloksetNakymaTila extends State<TuloksetNakyma> {
  List<Map<String, dynamic>> pistetaulukko = []; // Koko pelihistorian pistetiedot
  late AudioPlayer _audioPlayer;                // Äänen toistoon

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Jos tulokset saatiin suoraan pelistä (ei drawerista), soita ääni ja tallenna uusi tulos
    if (widget.pisteet != null) {
      _soitaTulosaani();
      _tallennaJaHaePisteet();
    } else {
      // Jos tuloksia selataan myöhemmin drawerista, hae vain jo tallennetut pistetiedot
      _haePisteet();
    }
  }

  /// Toistaa voittajan/jääpään ääniraidan riippuen pisteistä.
  Future<void> _soitaTulosaani() async {
    if (widget.pisteet! > 0) {
      await _audioPlayer.play(AssetSource('sounds/victory.mp3'));
    } else {
      await _audioPlayer.play(AssetSource('sounds/youlose.mp3'));
    }
  }

  /// Lisää tämän session pisteet SharedPreferencesiin ja hakee päivitetyn listan.
  Future<void> _tallennaJaHaePisteet() async {
    final prefs = await SharedPreferences.getInstance();
    final tallennetut = prefs.getStringList('pistetaulukko') ?? [];

    // Lisää uusi tulos JSONina listalle
    tallennetut.add(jsonEncode({
      'nimi': widget.kayttajaNimi,
      'pisteet': widget.pisteet,
    }));

    // Tallenna päivitetty lista
    await prefs.setStringList('pistetaulukko', tallennetut);
    _haePisteet();
  }

  /// Lataa ja lajittelee tallennetut pistetiedot ilman uuden tuloksen tallennusta.
  Future<void> _haePisteet() async {
    final prefs = await SharedPreferences.getInstance();
    final tallennetut = prefs.getStringList('pistetaulukko') ?? [];

    final haetut = <Map<String, dynamic>>[];
    for (var s in tallennetut) {
      try {
        haetut.add(jsonDecode(s) as Map<String, dynamic>);
      } catch (e) {
        debugPrint("Virhe datan jäsentämisessä: $e");
      }
    }

    // Suurimmasta pienimpään
    haetut.sort((a, b) => b['pisteet'].compareTo(a['pisteet']));

    setState(() {
      pistetaulukko = haetut;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Vapauta audio-resurssit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ylävalikko
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tulokset'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      body: Stack(
        children: [
          // Taustakuva koko näkymälle
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/tulokset_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Pääsisältö päälle
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Näytä tämän session pistetulos, jos peli päättyi juuri
                if (widget.pisteet != null)
                  Text(
                    '${widget.kayttajaNimi}, sait ${widget.pisteet} pistettä!',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white
                    ),
                  ),

                const SizedBox(height: 20),

                // Otsikko pistetaulukolle
                const Text(
                  'Pistetaulukko',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),

                const SizedBox(height: 10),

                // Lista tallennetuista tuloksista
                Expanded(
                  child: pistetaulukko.isEmpty
                      ? const Center(
                    child: Text(
                      'Ei tallennettuja pisteitä.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                      : ListView.builder(
                    itemCount: pistetaulukko.length,
                    itemBuilder: (context, index) {
                      final entry = pistetaulukko[index];
                      return Card(
                        color: Colors.white.withOpacity(0.8),
                        child: ListTile(
                          leading: Text(
                            '${index + 1}.',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          title: Text(entry['nimi'], style: const TextStyle(fontSize: 18)),
                          trailing: Text(
                            '${entry['pisteet']} pistettä',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Paluu etusivulle -painike
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const AloitusNakyma()),
                          (route) => false,
                    );
                  },
                  child: const Text('Etusivulle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
