// palvelut/openai_palvelu.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mallit/kysymys.dart';

class OpenAIPalvelu {
  final String _apiKey = 'Oma koodi'; // TALLENNA TÄMÄ TURVALLISESTI!
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions'; // Tai muu päätepiste

  Future<Kysymys?> generoiKysymys(String aihe, String vaikeustaso) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // Tai muu malli
          'messages': [
            {
              'role': 'system',
              'content': 'Olet avulias tekoäly, joka generoi trivia-kysymyksiä JSON-muodossa.'
            },
            {
              'role': 'user',
              'content': '''
Generoi trivia-kysymys aiheesta "$aihe" vaikeustasolla "$vaikeustaso".
Anna kysymys, oikea vastaus ja kolme väärää vastausvaihtoehtoa.
Muotoile vastaus JSON-objektina, jossa on seuraavat avaimet: "kysymys", "oikea_vastaus", "vaarat_vastaukset" (lista merkkijonoja).
Esimerkki JSON-muodosta:
{
  "kysymys": "Mikä on Suomen pääkaupunki?",
  "oikea_vastaus": "Helsinki",
  "vaarat_vastaukset": ["Tukholma", "Oslo", "Tallinna"]
}
'''
            }
          ],
          'temperature': 0.7, // Säädä luovuutta tarvittaessa
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes)); // Käsittele UTF-8 oikein
        final messageContent = responseBody['choices'][0]['message']['content'];

        // Yritä purkaa JSON-merkkijono viestin sisällöstä
        try {
          final Map<String, dynamic> data = jsonDecode(messageContent);
          return Kysymys(
            kysymysTeksti: data['kysymys'],
            oikeaVastaus: data['oikea_vastaus'],
            vaaratVastaukset: List<String>.from(data['vaarat_vastaukset']),
            // Muut mahdolliset Kysymys-luokan kentät
          );
        } catch (e) {
          print('Virhe JSON-datan purkamisessa OpenAI-vastauksesta: $e');
          print('Vastaanotettu sisältö: $messageContent');
          return null;
        }
      } else {
        print('Virhe OpenAI API -kutsussa: ${response.statusCode}');
        print('Vastaus: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Virhe OpenAI-kysymyksen generoinnissa: $e');
      return null;
    }
  }
}