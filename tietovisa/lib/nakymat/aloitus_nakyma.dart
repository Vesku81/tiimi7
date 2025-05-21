import 'package:flutter/material.dart';           // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart';          // Provider‐kirjasto tilanhallintaan

import '../tarjoajat/trivia_tarjoaja.dart';       // Trivia‐pelin tila
import 'peli_nakyma.dart';                        // Peli‐näkymä
import 'asetukset_nakyma.dart';                   // Asetukset‐näkymä
import 'tulokset_nakyma.dart';                    // Tulokset‐näkymä

/// Aloitusnäkymä toimii sovelluksen aloitusnäyttönä
class AloitusNakyma extends StatefulWidget {
  const AloitusNakyma({super.key});

  @override
  State<AloitusNakyma> createState() => AloitusNakymaTila();
}

/// Hallitsee näkymän tilaa, kuten käyttäjän syöttämää nimeä
class AloitusNakymaTila extends State<AloitusNakyma> {
  final TextEditingController _nimiOhjain = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tervetuloa Tietovisaan'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,   // kaikki AppBarin tekstit ja ikonit valkoisiksi
        titleTextStyle: const TextStyle(
          color: Colors.white,           // otsikon väri (yllä päällekkäin foregrounColorin kanssa)
          fontWeight: FontWeight.bold,   // boldattu
          fontSize: 24,                  // haluttu fonttikoko (voit säätää tarpeen mukaan)
        ),
      ),
      drawer: Drawer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/nav_menu.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/drawer_header_background.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const SizedBox.shrink(), // tyhjä child, pakollinen
                ),

                // --- "Tietovisa" yläpuolelle Aloita-painiketta ---
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      'Tietovisa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4.0,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white),
                  title: const Text('Aloita', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AloitusNakyma()),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.question_answer, color: Colors.white),
                  title: const Text('Tietovisa', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Provider.of<TriviaTarjoaja>(context, listen: false).nollaaPeli();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PeliNakyma(
                          kayttajaNimi: _nimiOhjain.text.isNotEmpty
                              ? _nimiOhjain.text
                              : 'Pelaaja',
                        ),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white),
                  title: const Text('Asetukset', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AsetuksetNakyma()),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.score, color: Colors.white),
                  title: const Text('Tulokset', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TuloksetNakyma(kayttajaNimi: 'Käyttäjä'),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.white),
                  title: const Text('Lopeta', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Lopeta sovellus'),
                        content: const Text('Haluatko varmasti sulkea sovelluksen?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Peruuta'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Kyllä'),
                          ),
                        ],
                      ),
                    ).then((lopeta) {
                      if (lopeta == true) {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          Navigator.of(context).pop();
                        });
                      }
                    });
                  },
                ),

                const SizedBox(height: 50),
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'Vesa Huhtaniska',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '&',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Sami Pyhtinen',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/aloitus_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Anna nimesi',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nimiOhjain,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Kirjoita nimesi',
                    hintStyle: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],   // Taustaväri
                    foregroundColor: Colors.white, // Tekstin väri
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Lisätyylit, esim. bold
                  ),
                  onPressed: () {
                    Provider.of<TriviaTarjoaja>(context, listen: false).nollaaPeli();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PeliNakyma(
                          kayttajaNimi: _nimiOhjain.text.isNotEmpty
                              ? _nimiOhjain.text
                              : 'Pelaaja',
                        ),
                      ),
                    );
                  },
                  child: const Text('Aloita Peli'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
