// Kysymys luokka mallintaa yhden kysymyksen, joka sisältää kysymyksen tekstin, oikean ja väärät vastaukset sekä kysymykseen liittyviä tietoja, kuten kategorian ja vaikeustason.
class Kysymys {
  // Kategorian nimi, esim. "Tiede" tai "Historia"
  final String kategoria;

  // Tyyppi, esim. "multiple" (monivalinta)
  final String tyyppi;

  // Vaikeustaso, esim. "helppo/easy", "keskitaso/medium" tai "vaikea/hard"
  final String vaikeus;

  // Itse kysymyksen teksti, joka esitetään käyttäjälle
  final String kysymysTeksti;

  // Kysymyksen oikea vastaus
  final String oikeaVastaus;

  // Lista vääristä vastauksista
  final List<String> vaaratVastaukset;

  // Konstruktori, jolla luodaan uusi `Kysymys`-olio. Kaikki kentät ovat pakollisia (`required`)
  Kysymys({
    required this.kategoria,
    required this.tyyppi,
    required this.vaikeus,
    required this.kysymysTeksti,
    required this.oikeaVastaus,
    required this.vaaratVastaukset,
  });

  
  // Funktio, joka luo `Kysymys`-olion JSON-muotoisesta datasta, jota käytetään, kun haetaan kysymyksiä esimerkiksi API rajapinnan kautta
  factory Kysymys.malliJsonista(Map<String, dynamic> json) {
    return Kysymys(
      kategoria: json['category'], // Kategorian nimi JSON:sta
      tyyppi: json['type'], // Tyyppi JSON:sta
      vaikeus: json['difficulty'], // Vaikeustaso JSON:sta
      kysymysTeksti: json['question'], // Kysymysteksti JSON:sta
      oikeaVastaus: json['correct_answer'], // Oikea vastaus JSON:sta
      vaaratVastaukset: List<String>.from(json['incorrect_answers']), // Väärät vastaukset JSON:sta
    );
  }
}
