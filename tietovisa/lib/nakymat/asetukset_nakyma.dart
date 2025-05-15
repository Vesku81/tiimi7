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
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Consumer<AsetuksetTarjoaja>(
        builder: (context, tarjoaja, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Ääniasetukset',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Äänet käytössä', style: TextStyle(color: Colors.black)),
                value: tarjoaja.aanetKaytossa,
                onChanged: tarjoaja.muutaAanetKayttoon,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Vastaa puhumalla', style: TextStyle(color: Colors.black)),
                value: tarjoaja.kaytaSpeechToText,
                onChanged: (val) => tarjoaja.kaytaSpeechToText = val,
              ),
              const SizedBox(height: 20),
              const Text('Puhenopeus', style: TextStyle(color: Colors.black)),
              Slider(
                min: 0.1,
                max: 1.0,
                divisions: 9,
                value: tarjoaja.ttsRate,
                onChanged: (v) => tarjoaja.ttsRate = v,
                label: tarjoaja.ttsRate.toStringAsFixed(1),
              ),
              const SizedBox(height: 10),
              const Text('Puhepitch', style: TextStyle(color: Colors.black)),
              Slider(
                min: 0.5,
                max: 2.0,
                divisions: 15,
                value: tarjoaja.ttsPitch,
                onChanged: (v) => tarjoaja.ttsPitch = v,
                label: tarjoaja.ttsPitch.toStringAsFixed(1),
              ),
              const SizedBox(height: 20),
              // --- Käännösasetukset ---
              SwitchListTile(
                title: const Text(
                  'Käännökset käytössä',
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
                value: tarjoaja.kaytaKaannokset,
                onChanged: (val) => tarjoaja.kaytaKaannokset = val,
              ),
            ],
          );
        },
      ),
    );
  }
}
