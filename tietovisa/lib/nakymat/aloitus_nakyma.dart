import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import '../tarjoajat/trivia_tarjoaja.dart'; // Trivia-pelin tila
import 'peli_nakyma.dart'; // Peli-näkymä
import 'asetukset_nakyma.dart'; // Asetukset-näkymä
import 'tulokset_nakyma.dart'; // Tulokset-näkymä

// Aloitusnakyma toimii sovelluksen aloitusnäyttönä
class AloitusNakyma extends StatefulWidget {
  const AloitusNakyma({super.key});

  @override
  State<AloitusNakyma> createState() => AloitusNakymaTila();
}

// Hallitsee näkymän tilaa, kuten käyttäjän syöttämää nimeä
class AloitusNakymaTila extends State<AloitusNakyma> {
  final TextEditingController _nimiOhjain = TextEditingController(); // Tekstikentän hallinta

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Keskittää AppBarin otsikon
        title: const Text('Tervetuloa TriviaVisaan'), // AppBarin otsikko
        backgroundColor: Colors.deepPurpleAccent, // AppBarin taustaväri
      ),
      drawer: Drawer(
        child: Stack(
          children: [
            // Drawer-valikon taustakuva
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                      'assets/images/nav_menu.jpg'), // Drawerin taustakuva
                  fit: BoxFit.cover, // Skaalataan kuva koko näkymän kattavaksi
                ),
              ),
            ),
            // Drawer-valikon sisältö
            ListView(
              padding: EdgeInsets.zero,
              children: [
                // Drawer-header
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'assets/images/drawer_header_background.jpg'), // Headerin taustakuva
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TriviaVisa', // Sovelluksen nimi
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
                        ),
                        SizedBox(height: 10), // Tekstien välinen etäisyys
                        Text(
                          'Vesa Huhtaniska & Sami Pyhtinen', // Tekijöiden nimet
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2.0,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Drawer-valikon linkit
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white), // Ikoni
                  title: const Text(
                    'Aloita',
                    style: TextStyle(color: Colors.white), // Teksti
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AloitusNakyma()), // Uudelleenlataa aloitusnäkymän
                    );
                  },
                ),
                ListTile(
                  leading:
                  const Icon(Icons.question_answer, color: Colors.white), // Ikoni
                  title: const Text(
                    'Trivia',
                    style: TextStyle(color: Colors.white), // Teksti
                  ),
                  onTap: () {
                    Navigator.pop(context); // Sulkee Drawer-valikon
                    Provider.of<TriviaTarjoaja>(context, listen: false)
                        .nollaaPeli(); // Nollaa pelitilan
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PeliNakyma(
                          kayttajaNimi: _nimiOhjain.text.isNotEmpty
                              ? _nimiOhjain.text
                              : 'Pelaaja', // Käytetään "Pelaaja" nimeä oletuksena, jos pelaaja ei ole syöttänyt nimeä nimikenttään
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white), // Ikoni
                  title: const Text(
                    'Asetukset',
                    style: TextStyle(color: Colors.white), // Teksti
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                          const AsetuksetNakyma()), // Navigoi asetuksiin
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.score, color: Colors.white), // Ikoni
                  title: const Text(
                    'Tulokset',
                    style: TextStyle(color: Colors.white), // Teksti
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TuloksetNakyma(
                          kayttajaNimi: "Käyttäjä", // Oletusnimi tuloksissa
                          //  pisteet: 0, // Alustetaan tulokset
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.white), // Ikoni
                  title: const Text(
                    'Lopeta',
                    style: TextStyle(color: Colors.white), // Teksti
                  ),
                  onTap: () {
                    Navigator.pop(context); // Sulkee Drawer-valikon
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Lopeta sovellus'),
                        content:
                        const Text('Haluatko varmasti sulkea sovelluksen?'), // Vahvistetaan, että haluaako käyttäjä sulkea sovelluksen
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(), // Peruuta sovelluksen sulkeminen
                            child: const Text('Peruuta'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true), // Vahvista sovelluksen sulkeminen
                            child: const Text('Kyllä'),
                          ),
                        ],
                      ),
                    ).then((lopeta) {
                      if (lopeta == true) {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          Navigator.pop(context); // Sulkee sovelluksen
                        });
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      // Aloitusnäytön sisältö
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'), // Taustakuva
                fit: BoxFit.cover, // Skaalataan kuva koko näkymän kattavaksi
              ),
            ),
          ),
          // Näytön sisältö
          Padding(
            padding: const EdgeInsets.all(100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Anna nimesi', // Otsikko
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Tekstikenttä nimen syöttöön
                TextField(
                  controller: _nimiOhjain, // Hallitsee käyttäjän syöttämää tekstiä
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(), // Tekstikentän reunus
                    hintText: 'Kirjoita nimesi', // Vihjeteksti nimensyöttö kentässä
                    hintStyle: TextStyle(
                      color: Colors.white, // Vihjetekstin väri
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white, // Käyttäjän kirjoittaman tekstin väri
                  ),
                ),
                const SizedBox(height: 20),
                // Aloita-painike
                ElevatedButton(
                  onPressed: () {
                    Provider.of<TriviaTarjoaja>(context, listen: false)
                        .nollaaPeli(); // Nollaa pelitilan
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PeliNakyma(
                          kayttajaNimi: _nimiOhjain.text.isNotEmpty
                              ? _nimiOhjain.text
                              : 'Pelaaja', // Käytetään oletusnimeä, jos nimeä ei ole syötetty
                        ),
                      ),
                    );
                  },
                  child: const Text('Aloita Peli'), // Painikkeen teksti
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
