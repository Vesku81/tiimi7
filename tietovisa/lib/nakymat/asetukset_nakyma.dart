import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import '../tarjoajat/asetukset_tarjoaja.dart'; // Asetusten tarjoaja

// Asetuksetnakyma vastaa sovelluksen asetusten näyttämisestä ja muokkaamisesta
class AsetuksetNakyma extends StatelessWidget {
  const AsetuksetNakyma({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Keskittää otsikon AppBarissa
        title: const Text('Asetukset'), // Otsikko AppBarille
        backgroundColor: Colors.deepPurpleAccent, // AppBarin taustaväri
      ),
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'), // Sivun taustakuva
                fit: BoxFit.cover, // Skaalataan kuva koko näkymän kattavaksi
              ),
            ),
          ),
          // Pääsisältö, joka näyttää asetukset
          Padding(
            padding: const EdgeInsets.all(16.0), // Reunustila sisällölle
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Kohdistetaan sisältö vasemmalle
              children: [
                // Ääniasetusten otsikko
                const Text(
                  'Ääniasetukset', // Ääniasetusten otsikko
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10), // Etäisyys seuraavaan osaan
                // Switch kytkin äänten käytölle
                Consumer<AsetuksetTarjoaja>(
                  builder: (context, asetuksetTarjoaja, child) {
                    return SwitchListTile(
                      title: const Text(
                        'Äänet käytössä', // Teksti äänten käyttövalinnalle
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      value: asetuksetTarjoaja.aanetKaytossa, // Äänet (päällä/pois)
                      onChanged: (arvo) {
                        // Korjattu funktion nimi vastaamaan AsetuksetTarjoaja luokkaa
                        asetuksetTarjoaja.setAanetKaytossa(arvo); // Päivittää äänten tilan
                      },
                      // SwitchListTilen värit
                      activeColor: Colors.deepPurpleAccent,
                      activeTrackColor: Colors.deepPurple.shade200,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade200,
                    );
                  },
                ),
                const SizedBox(height: 20), // Etäisyys seuraavaan osaan
                // Äänenvoimakkuuden liukusäädin
                const Text(
                  'Äänenvoimakkuus', // Otsikko äänenvoimakkuuden säädölle
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Consumer<AsetuksetTarjoaja>(
                  builder: (context, asetuksetTarjoaja, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Kohdistetaan sisältö vasemmalle
                      children: [
                        Slider(
                          value: asetuksetTarjoaja.aanenVoimakkuus.toDouble(), // Nykyinen äänenvoimakkuus
                          min: 0, // Minimiarvo liukusäätimelle
                          max: 100, // Maksimiarvo liukusäätimelle
                          divisions: 10, // Liukusäätimen jako-osat
                          label: '${asetuksetTarjoaja.aanenVoimakkuus}%', // Näyttää liukusäätimen arvon prosentteina
                          onChanged: (arvo) {
                            // Korjattu funktion nimi vastaamaan AsetuksetTarjoaja luokkaa
                            asetuksetTarjoaja.setAanenVoimakkuus(arvo.toInt()); // Päivittää äänenvoimakkuuden
                          },
                          // Sliderin värit
                          activeColor: Colors.deepPurpleAccent,
                          inactiveColor: Colors.deepPurple.shade200,
                          thumbColor: Colors.white,
                        ),
                        // Näytetään äänenvoimakkuus prosentteina liukusäätimen alapuolella
                        Center(
                          child: Text(
                            '${asetuksetTarjoaja.aanenVoimakkuus}%', // Näyttää nykyisen äänenvoimakkuuden
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30), // Lisää tilaa seuraavalle osiolle
                // Kysymysten hakutavan otsikko
                const Text(
                  'Kysymysten lähde', // Otsikko kysymysten hakutavalle
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10), // Etäisyys seuraavaan osaan
                // Switch kytkin kysymysten hakutavalle
                Consumer<AsetuksetTarjoaja>(
                  builder: (context, asetuksetTarjoaja, child) {
                    return SwitchListTile(
                      title: const Text(
                        'Hae paikallisesti (jos saatavilla)', // Teksti hakutavan valinnalle
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      value: asetuksetTarjoaja.haePaikallisesti, // Nykyinen hakutapa (paikallinen/API)
                      onChanged: (arvo) {
                        asetuksetTarjoaja.setHaePaikallisesti(arvo); // Päivittää hakutavan
                      },
                      // SwitchListTilen värit
                      activeColor: Colors.deepPurpleAccent,
                      activeTrackColor: Colors.deepPurple.shade200,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade200,
                    );
                  },
                ),
                // Voit lisätä tähän myös painikkeen paikallisten kysymysten poistamiseksi, jos haluat
                // Esimerkki:
                // const SizedBox(height: 20),
                // ElevatedButton(
                //   onPressed: () {
                //     // Kutsu TriviaTarjoajan poistaPaikallisetKysymykset funktiota
                //     // Huom: Tarvitset pääsyn TriviaTarjoajaan tässä, esim. Provider.of<TriviaTarjoaja>(context, listen: false).poistaPaikallisetKysymykset(...)
                //     // Sinun täytyy tietää määrä, vaikeus ja kieli poistaaksesi oikeat kysymykset.
                //     // Tämä voi olla monimutkaisempaa riippuen siitä, miten haluat tämän toiminnon toteuttaa.
                //     print('Poista paikalliset kysymykset painettu');
                //   },
                //   child: const Text('Poista paikalliset kysymykset'),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}