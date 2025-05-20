import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mallit/kysymys.dart';

class OpenAIPalvelu {
  final String _apiKey = 'Oma koodi';
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  final Set<String> _esitetytKysymykset = {};

  String _normalisoi(String kysymys) {
    return kysymys.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  Future<Kysymys?> generoiKysymys(String aihe, String vaikeustaso) async {
    final List<String> aiemmat = _esitetytKysymykset.map((k) => '"$k"').toList();
    final prompt = '''
Generoi trivia-kysymys aiheesta "$aihe" vaikeustasolla "$vaikeustaso".
Älä toista seuraavia kysymyksiä: ${aiemmat.join(', ')}.
Palauta vastaus seuraavassa JSON-muodossa:
{
  "kysymys": "...",
  "oikea_vastaus": "...",
  "vaarat_vastaukset": ["...", "...", "..."]
}
''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'Olet avulias tekoäly, joka generoi trivia-kysymyksiä JSON-muodossa.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        final messageContent = responseBody['choices'][0]['message']['content'];

        try {
          final Map<String, dynamic> data = jsonDecode(messageContent);
          final kysymysNorm = _normalisoi(data['kysymys']);

          if (_esitetytKysymykset.contains(kysymysNorm)) {
            print("⚠️ Duplikaatti havaittu, ohitetaan");
            return null;
          }

          _esitetytKysymykset.add(kysymysNorm);
          return Kysymys(
            kysymysTeksti: data['kysymys'],
            oikeaVastaus: data['oikea_vastaus'],
            vaaratVastaukset: List<String>.from(data['vaarat_vastaukset']),
          );
        } catch (e) {
          print('❌ JSON-virhe: $e\nSisältö: $messageContent');
          return null;
        }
      } else {
        print('❌ OpenAI API -virhe: ${response.statusCode}\nVastaus: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Verkkovirhe: $e');
      return null;
    }
  }
}
