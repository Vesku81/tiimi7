// mallit/kysymys.dart
import 'package:uuid/uuid.dart'; // Varmista, että tämä on lisätty pubspec.yaml

class Kysymys {
  final String id;
  final String? kategoria; // Esim. "Maantieto", "Historia", tai OpenAI:n käyttämä aihealue
  final String? tyyppi;     // Esim. "multiple" (monivalinta), "boolean" (tosi/epätosi) - API:sta
  final String? vaikeus;    // Esim. "easy", "medium", "hard"
  final String kysymysTeksti;
  final String oikeaVastaus;
  final List<String> vaaratVastaukset;
  final String lahde; // Esim. "openai_generoitu", "trivia_api_käännetty"
  final DateTime lisattyPvm;

  Kysymys({
    String? id, // Tehdään id:stä valinnainen, jotta se voidaan luoda myöhemmin tarvittaessa
    this.kategoria,
    this.tyyppi,
    this.vaikeus,
    required this.kysymysTeksti,
    required this.oikeaVastaus,
    required this.vaaratVastaukset,
    required this.lahde,
    DateTime? lisattyPvm, // Tehdään valinnaiseksi, oletusarvo asetetaan konstruktorissa
  }) : this.id = id ?? Uuid().v4(), // Jos id:tä ei anneta, luo uusi
        this.lisattyPvm = lisattyPvm ?? DateTime.now(); // Jos pvm ei anneta, käytä nykyhetkeä

  Map<String, dynamic> toJson() => {
    'id': id,
    'kategoria': kategoria,
    'tyyppi': tyyppi,
    'vaikeus': vaikeus,
    'kysymys': kysymysTeksti,
    'oikea_vastaus': oikeaVastaus,
    'vaarat_vastaukset': vaaratVastaukset,
    'lahde': lahde,
    'lisatty_pvm': lisattyPvm.toIso8601String(),
  };

  factory Kysymys.fromJson(Map<String, dynamic> json) {
    return Kysymys(
      id: json['id'] as String,
      kategoria: json['kategoria'] as String?,
      tyyppi: json['tyyppi'] as String?,
      vaikeus: json['vaikeus'] as String?,
      kysymysTeksti: json['kysymys'] as String,
      oikeaVastaus: json['oikea_vastaus'] as String,
      vaaratVastaukset: List<String>.from(json['vaarat_vastaukset'] as List<dynamic>),
      lahde: json['lahde'] as String? ?? 'tuntematon', // Oletusarvo vanhemmille datoille
      lisattyPvm: json['lisatty_pvm'] != null
          ? DateTime.parse(json['lisatty_pvm'] as String)
          : DateTime.now(), // Oletusarvo vanhemmille datoille
    );
  }

  String get normalisoituKysymysTeksti => kysymysTeksti.trim().toLowerCase();

  // Apumetodi kaikkien vastausvaihtoehtojen sekoittamiseen peliä varten
  List<String> get sekoitetutVastaukset {
    final kaikki = <String>[oikeaVastaus, ...vaaratVastaukset];
    kaikki.shuffle();
    return kaikki;
  }
}