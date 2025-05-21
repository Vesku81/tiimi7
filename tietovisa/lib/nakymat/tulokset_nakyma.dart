import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences tietojen tallennukseen
import 'package:audioplayers/audioplayers.dart'; // Audioplayer ääniä varten
import 'dart:convert'; // JSON-tietojen käsittely
import 'aloitus_nakyma.dart'; // Etusivun näkymä

// Tuloksetnakyma vastaa tulosten ja pistetaulukon näyttämisestä
class TuloksetNakyma extends StatefulWidget {
  final String kayttajaNimi; // Käyttäjän nimi
  final int? pisteet; // Käyttäjän keräämät pisteet (voi olla null, jos tullaan Drawerista)

  const TuloksetNakyma({super.key, required this.kayttajaNimi, this.pisteet});

  @override
  State<TuloksetNakyma> createState() => _TuloksetNakymaTila();
}

// _Tuloksetnakymatila vastaa näkymän tilanhallinnasta
class _TuloksetNakymaTila extends State<TuloksetNakyma> {
  List<Map<String, dynamic>> pistetaulukko = []; // Lista tallennetuista pisteistä
  late AudioPlayer _audioPlayer; // AudioPlayerin alustaminen ääniä varten

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer(); // Luodaan uusi AudioPlayer instanssi

    // ✅ Soitetaan ääni VAIN jos peli on juuri päättynyt
    if (widget.pisteet != null) {
      _soitaTulosaani(); // Soitetaan tulosääni pelin päättyessä
      _tallennaJaHaePisteet(); // Tallennetaan ja haetaan pistetiedot
    } else {
      _haePisteet(); // Haetaan vain pisteet, jos tullaan Drawerista
    }
  }

  // ✅ Funktio äänen toistamiseen vain pelin päätteeksi
  Future<void> _soitaTulosaani() async {
    if (widget.pisteet! > 0) {
      await _audioPlayer.play(AssetSource('sounds/victory.mp3')); // ✅ Voittoääni
    } else {
      await _audioPlayer.play(AssetSource('sounds/youlose.mp3')); // ✅ Häviöääni
    }
  }

  // ✅ Tallennetaan ja haetaan pistetiedot vain, jos peli on päättynyt
  Future<void> _tallennaJaHaePisteet() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tallennetutPisteet = prefs.getStringList('pistetaulukko') ?? [];

    // ✅ Lisätään nykyisen pelin tulos vain, jos peli on päättynyt
    tallennetutPisteet.add(jsonEncode({
      'nimi': widget.kayttajaNimi,
      'pisteet': widget.pisteet,
    }));

    // ✅ Päivitetään tallennetut tulokset
    await prefs.setStringList('pistetaulukko', tallennetutPisteet);

    _haePisteet(); // ✅ Haetaan päivitetyt pisteet
  }

  // ✅ Hakee pisteet ilman tallennusta (jos tullaan Drawerista)
  Future<void> _haePisteet() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tallennetutPisteet = prefs.getStringList('pistetaulukko') ?? [];

    List<Map<String, dynamic>> haetutPisteet = [];
    for (String piste in tallennetutPisteet) {
      try {
        final data = jsonDecode(piste) as Map<String, dynamic>;
        haetutPisteet.add(data);
      } catch (e) {
        print("Virhe tietojen käsittelyssä: $e");
      }
    }

    haetutPisteet.sort((a, b) => b['pisteet'].compareTo(a['pisteet']));

    setState(() {
      pistetaulukko = haetutPisteet;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // ✅ Vapautetaan AudioPlayerin resurssit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tulokset'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,   // kaikki AppBarin tekstit ja ikonit valkoisiksi
        titleTextStyle: const TextStyle(
          color: Colors.white,           // otsikon väri (yllä päällekkäin foregrounColorin kanssa)
          fontWeight: FontWeight.bold,   // boldattu
          fontSize: 24,                  // haluttu fonttikoko (voit säätää tarpeen mukaan)
        ),
      ),
      body: Stack(
        children: [
          // ✅ Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/tulokset_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // ✅ Pääsisältö
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.pisteet != null) // ✅ Näytetään vain, jos peli päättyi
                  Text(
                    '${widget.kayttajaNimi}, sait ${widget.pisteet} pistettä!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Pistetaulukko',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
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
                      return Card(
                        color: Colors.white.withOpacity(0.8),
                        child: ListTile(
                          leading: Text(
                            '${index + 1}.',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          title: Text(
                            pistetaulukko[index]['nimi'],
                            style: const TextStyle(fontSize: 18),
                          ),
                          trailing: Text(
                            '${pistetaulukko[index]['pisteet']} pistettä',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],   // Taustaväri
                    foregroundColor: Colors.white, // Tekstin väri
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Lisätyylit, esim. bold
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
