// nakymat/asetukset_nakyma.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../tarjoajat/asetukset_tarjoaja.dart';

class AsetuksetNakyma extends StatelessWidget {
  const AsetuksetNakyma({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asetukset'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/asetukset_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Asetukset-sisältö
          Consumer<AsetuksetTarjoaja>(
            builder: (context, tarjoaja, child) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Kysymysten Asetukset ---
                  const Text(
                    'Kysymysten Asetukset',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text(
                      'Käytä OpenAI:ta kysymysten lähteenä',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Generoi kysymykset tekoälyn avulla. Vaatii internet-yhteyden.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: tarjoaja.kaytaOpenAIKysymyksia,
                    onChanged: (val) => tarjoaja.asetaKaytaOpenAI(val),
                    activeColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Valitse aihealue',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.white, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                    dropdownColor: Colors.deepPurple,
                    value: tarjoaja.valittuAihealue,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    isExpanded: true,
                    items: tarjoaja.aihealueet.map((aihe) {
                      return DropdownMenuItem(
                        value: aihe,
                        child: Text(
                          aihe[0].toUpperCase() + aihe.substring(1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (uusi) => tarjoaja.asetaValittuAihealue(uusi),
                  ),
                  const Divider(height: 30, color: Colors.white54),

                  // --- Vaikeustaso ---
                  const Text(
                    'Vaikeustaso',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Valitse vaikeustaso',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.white, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                    dropdownColor: Colors.deepPurple,
                    value: tarjoaja.valittuVaikeustaso ?? tarjoaja.kaikkiVaikeustasot.first,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    isExpanded: true,
                    items: tarjoaja.kaikkiVaikeustasot.map((taso) {
                      return DropdownMenuItem(
                        value: taso,
                        child: Text(taso, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (uusi) => tarjoaja.asetaValittuVaikeustaso(uusi),
                  ),
                  const Divider(height: 30, color: Colors.white54),

                  // --- Ääniasetukset ---
                  const Text(
                    'Ääniasetukset',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Äänet käytössä', style: TextStyle(color: Colors.white)),
                    value: tarjoaja.aanetKaytossa,
                    onChanged: (val) => tarjoaja.asetaAanetKaytossa(val),
                    activeColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Vastaa puhumalla (STT)', style: TextStyle(color: Colors.white)),
                    value: tarjoaja.kaytaSpeechToText,
                    onChanged: (val) => tarjoaja.asetaKaytaSpeechToText(val),
                    activeColor: Colors.deepPurple,
                  ),
                  if (tarjoaja.kaytaSpeechToText) ...[
                    const SizedBox(height: 20),
                    const Text('Puhenopeus (TTS)', style: TextStyle(color: Colors.white)),
                    Slider(
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      value: tarjoaja.ttsRate,
                      onChanged: (val) => tarjoaja.asetaTtsRate(val),
                      label: tarjoaja.ttsRate.toStringAsFixed(1),
                      activeColor: Colors.deepPurple,
                    ),
                    const SizedBox(height: 10),
                    const Text('Puheen korkeus (TTS)', style: TextStyle(color: Colors.white)),
                    Slider(
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      value: tarjoaja.ttsPitch,
                      onChanged: (val) => tarjoaja.asetaTtsPitch(val),
                      label: tarjoaja.ttsPitch.toStringAsFixed(1),
                      activeColor: Colors.deepPurple,
                    ),
                  ],

                  // --- Lue kysymykset ääneen ---
                  SwitchListTile(
                    title: const Text('Lue kysymykset ääneen', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Käyttää tekstistä puheeksi -toimintoa kysymyksille.', style: TextStyle(color: Colors.white70)),
                    value: tarjoaja.kaytaTts,
                    onChanged: (val) => tarjoaja.asetaKaytaTts(val),
                    activeColor: Colors.deepPurple,
                  ),

                  const Divider(height: 30, color: Colors.white54),

                  // --- Käännösasetukset ---
                  const Text(
                    'Kieliasetukset',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Käännä kysymykset suomeksi', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Käytetään, jos kysymysten lähde on englanninkielinen API.', style: TextStyle(color: Colors.white70)),
                    value: tarjoaja.kaytaKaannokset,
                    onChanged: (val) => tarjoaja.asetaKaytaKaannokset(val),
                    activeColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
