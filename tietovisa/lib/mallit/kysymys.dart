// mallit/kysymys.dart

// Kysymys luokka mallintaa yhden kysymyksen, joka sisältää kysymyksen tekstin, oikean ja väärät vastaukset sekä kysymykseen liittyviä tietoja, kuten kategorian ja vaikeustason.
class Kysymys {
  // Kategorian nimi, esim. "Tiede" tai "Historia". Tehdään valinnaiseksi.
  final String? kategoria;

  // Tyyppi, esim. "multiple" (monivalinta). Tehdään valinnaiseksi.
  final String? tyyppi;

  // Vaikeustaso, esim. "helppo/easy", "keskitaso/medium" tai "vaikea/hard". Tehdään valinnaiseksi.
  final String? vaikeus;

  // Itse kysymyksen teksti, joka esitetään käyttäjälle
  final String kysymysTeksti;

  // Kysymyksen oikea vastaus
  final String oikeaVastaus;

  // Lista vääristä vastauksista
  final List<String> vaaratVastaukset;

  // Konstruktori, jolla luodaan uusi `Kysymys`-olio.
  // Kategoria, tyyppi ja vaikeus ovat nyt valinnaisia.
  Kysymys({
    this.kategoria, // Ei enää 'required'
    this.tyyppi,    // Ei enää 'required'
    this.vaikeus,   // Ei enää 'required'
    required this.kysymysTeksti,
    required this.oikeaVastaus,
    required this.vaaratVastaukset,
  });

  // Funktio, joka luo `Kysymys`-olion perinteisen API:n JSON-muotoisesta datasta
  factory Kysymys.malliApiJsonista(Map<String, dynamic> json) {
    return Kysymys(
      kategoria: json['category'] as String?, // Varmistetaan tyyppi ja null-turvallisuus
      tyyppi: json['type'] as String?,
      vaikeus: json['difficulty'] as String?,
      kysymysTeksti: json['question'] as String, // Oletetaan, että nämä ovat aina olemassa API-vastauksessa
      oikeaVastaus: json['correct_answer'] as String,
      vaaratVastaukset: List<String>.from(json['incorrect_answers'] as List<dynamic>),
    );
  }

  // Uusi factory-konstruktori OpenAI:n generoimalle JSON-datalle
  // Olettaen, että OpenAI-promptisi pyytää JSON-objektia, jossa on avaimet:
  // "kysymys", "oikea_vastaus", "vaarat_vastaukset"
  // Ja mahdollisesti "kategoria", "tyyppi", "vaikeus", jos olet pyytänyt niitä.
  factory Kysymys.malliOpenAIJsonista(Map<String, dynamic> json) {
    return Kysymys(
      // Jos OpenAI ei palauta näitä, ne ovat null, mikä on nyt sallittua.
      // Voit myös antaa oletusarvoja, jos haluat.
      kategoria: json['kategoria'] as String?, // Olettaen, että promptisi käyttää tätä avainta
      tyyppi: json['tyyppi'] as String?,       // Olettaen, että promptisi käyttää tätä avainta
      vaikeus: json['vaikeus'] as String?,     // Olettaen, että promptisi käyttää tätä avainta
      kysymysTeksti: json['kysymys'] as String, // Oletetaan, että nämä ovat aina olemassa OpenAI-vastauksessa
      oikeaVastaus: json['oikea_vastaus'] as String,
      vaaratVastaukset: List<String>.from(json['vaarat_vastaukset'] as List<dynamic>),
    );
  }
}