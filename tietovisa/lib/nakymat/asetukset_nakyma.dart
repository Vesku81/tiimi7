// nakymat/asetukset_nakyma.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../tarjoajat/asetukset_tarjoaja.dart';

class AsetuksetNakyma extends StatelessWidget {
  const AsetuksetNakyma({super.key});

  @override
  Widget build(BuildContext context) {
    final asetuksetTarjoaja = Provider.of<AsetuksetTarjoaja>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asetukset'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Kysymysten Asetukset ---
          const Text(
            'Kysymysten Asetukset',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Käytä OpenAI:ta kysymysten lähteenä', style: TextStyle(color: Colors.black87)),
            subtitle: const Text('Generoi kysymykset tekoälyn avulla. Vaatii internet-yhteyden.', style: TextStyle(color: Colors.black54)),
            value: asetuksetTarjoaja.kaytaOpenAIKysymyksia,
            onChanged: (bool value) => asetuksetTarjoaja.asetaKaytaOpenAI(value),
            activeColor: Colors.deepPurple,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Valitse aihealue',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            value: asetuksetTarjoaja.valittuAihealue,
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.deepPurple),
            isExpanded: true,
            items: asetuksetTarjoaja.aihealueet.map((aihe) {
              return DropdownMenuItem(
                value: aihe,
                child: Text(aihe[0].toUpperCase() + aihe.substring(1)),
              );
            }).toList(),
            onChanged: (uusi) => asetuksetTarjoaja.asetaValittuAihealue(uusi),
          ),
          const Divider(height: 30),

          // --- Vaikeustaso ---
          const Text(
            'Vaikeustaso',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Valitse vaikeustaso',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            value: asetuksetTarjoaja.valittuVaikeustaso,
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.deepPurple),
            isExpanded: true,
            items: asetuksetTarjoaja.vaikeustasot.map((taso) {
              return DropdownMenuItem(
                value: taso,
                child: Text(taso),
              );
            }).toList(),
            onChanged: (uusi) => asetuksetTarjoaja.asetaValittuVaikeustaso(uusi),
          ),
          const Divider(height: 30),

          // --- Ääniasetukset ---
          const Text(
            'Ääniasetukset',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Äänet käytössä', style: TextStyle(color: Colors.black87)),
            value: asetuksetTarjoaja.aanetKaytossa,
            onChanged: (val) => asetuksetTarjoaja.asetaAanetKaytossa(val),
            activeColor: Colors.deepPurple,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Vastaa puhumalla (Puheentunnistus)', style: TextStyle(color: Colors.black87)),
            value: asetuksetTarjoaja.kaytaSpeechToText,
            onChanged: (val) => asetuksetTarjoaja.asetaKaytaSpeechToText(val),
            activeColor: Colors.deepPurple,
          ),
          if (asetuksetTarjoaja.kaytaSpeechToText) ...[
            const SizedBox(height: 20),
            const Text('Puhenopeus (TTS)', style: TextStyle(color: Colors.black87)),
            Slider(
              min: 0.1,
              max: 1.0,
              divisions: 9,
              value: asetuksetTarjoaja.ttsRate,
              onChanged: (val) => asetuksetTarjoaja.asetaTtsRate(val),
              label: asetuksetTarjoaja.ttsRate.toStringAsFixed(1),
              activeColor: Colors.deepPurple,
            ),
            const SizedBox(height: 10),
            const Text('Puheen korkeus (TTS)', style: TextStyle(color: Colors.black87)),
            Slider(
              min: 0.5,
              max: 2.0,
              divisions: 15,
              value: asetuksetTarjoaja.ttsPitch,
              onChanged: (val) => asetuksetTarjoaja.asetaTtsPitch(val),
              label: asetuksetTarjoaja.ttsPitch.toStringAsFixed(1),
              activeColor: Colors.deepPurple,
            ),
          ],

          // --- Lue kysymykset ääneen ---
          SwitchListTile(
            title: const Text('Lue kysymykset ääneen', style: TextStyle(color: Colors.black87)),
            subtitle: const Text('Käyttää tekstistä puheeksi -toimintoa kysymyksille.', style: TextStyle(color: Colors.black54)),
            value: asetuksetTarjoaja.kaytaTts,
            onChanged: (val) => asetuksetTarjoaja.asetaKaytaTts(val),
            activeColor: Colors.deepPurple,
          ),

          const Divider(height: 30),

          // --- Käännösasetukset ---
          const Text(
            'Kieliasetukset',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Käännä kysymykset suomeksi', style: TextStyle(color: Colors.black87)),
            subtitle: const Text('Käytetään, jos kysymysten lähde on englanninkielinen API.', style: TextStyle(color: Colors.black54)),
            value: asetuksetTarjoaja.kaytaKaannokset,
            onChanged: (val) => asetuksetTarjoaja.asetaKaytaKaannokset(val),
            activeColor: Colors.deepPurple,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
