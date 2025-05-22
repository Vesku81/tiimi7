// Flutterin peruswidgetit ja tyylit
import 'package:flutter/material.dart';
// Provider‐kirjasto tilanhallintaan (esim. TriviaTarjoaja, AsetuksetTarjoaja)
import 'package:provider/provider.dart';

// Trivia-pelin logiikka sekä eri näkymät
import '../tarjoajat/trivia_tarjoaja.dart';   // Pelin tila ja kysymyshaku
import 'peli_nakyma.dart';                    // Peli‐näkymä, jossa esitetään trivia-kysymykset
import 'asetukset_nakyma.dart';               // Asetukset‐näkymä, jossa käyttäjä muokkaa peliasetuksia
import 'tulokset_nakyma.dart';                // Tulokset‐näkymä, jossa näytetään pistetilasto

/// AloitusNakyma toimii sovelluksen aloitusnäyttönä, johon käyttäjä syöttää nimensä
class AloitusNakyma extends StatefulWidget {
  const AloitusNakyma({super.key});

  @override
  State<AloitusNakyma> createState() => AloitusNakymaTila();
}

/// AloitusNakymaTila hallitsee tekstikentän tilaa ja navigoinnin eri näkymiin
class AloitusNakymaTila extends State<AloitusNakyma> {
  // Tekstikentän ohjain nimi-inputille
  final TextEditingController _nimiOhjain = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sovelluksen ylätunniste
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tervetuloa Tietovisaan'),
        backgroundColor: Colors.grey[800],       // Tummanharmaa tausta
        foregroundColor: Colors.white,          // AppBarin tekstit ja ikonit valkoisiksi
        titleTextStyle: const TextStyle(
          color: Colors.white,                  // Title-otsikko valkoiseksi
          fontWeight: FontWeight.bold,          // Boldattu fontti
          fontSize: 24,                         // Fonttikoko 24
        ),
      ),
      // Sivupaneeli (Drawer) navigointiin peliin, asetuksiin, tuloksiin jne.
      drawer: Drawer(
        child: Stack(
          children: [
            // Taustakuva navigaatiopaneelissa
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
                // DrawerHeader, tyhjä child mutta taustakuva näkyy
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/drawer_header_background.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const SizedBox.shrink(),
                ),

                // Sovelluksen nimi Drawerissa
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

                // "Aloita"-valinta vie takaisin aloitusnäkymään
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

                // "Tietovisa"-valinta aloittaa pelin
                ListTile(
                  leading: const Icon(Icons.question_answer, color: Colors.white),
                  title: const Text('Tietovisa', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context); // Sulje drawer
                    // Nollaa pelin tila ja siirry PeliNakyma-sivulle
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

                // "Asetukset"-valinta vie asetuksiin
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

                // "Tulokset"-valinta vie tulosnäkymään
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

                // "Lopeta"-valinta kysyy varmistuksen ja sulkee sovelluksen
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

                // Tekijät nimilista Drawerin alaosassa
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

      // Sovelluksen pääbody, jossa taustakuva ja lomake nimen syöttämiseen
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/aloitus_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Keskitetty lomake nimen syöttämiseen
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
                    backgroundColor: Colors.grey[800],   // Painikkeen taustaväri
                    foregroundColor: Colors.white,         // Painikkeen tekstin väri
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    // Nollataan pelin tila ja siirrytään peli-näkymään
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
