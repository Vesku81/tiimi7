class Kysymys {
  final String kategoria;
  final String tyyppi;
  final String vaikeus;
  final String kysymysTeksti;
  final String oikeaVastaus;
  final List<String> vaaratVastaukset;

  Kysymys({
    required this.kategoria,
    required this.tyyppi,
    required this.vaikeus,
    required this.kysymysTeksti,
    required this.oikeaVastaus,
    required this.vaaratVastaukset,
  });

  // Metodi, joka luo Kysymys-objektin JSON-datasta
  factory Kysymys.fromJson(Map<String, dynamic> json) {
    return Kysymys(
      kategoria: json['kategoria'] as String,
      tyyppi: json['tyyppi'] as String,
      vaikeus: json['vaikeus'] as String,
      kysymysTeksti: json['kysymysTeksti'] as String,
      oikeaVastaus: json['oikeaVastaus'] as String,
      vaaratVastaukset: List<String>.from(json['vaaratVastaukset']),
    );
  }

  // Metodi, joka muuntaa Kysymys-objektin JSON-dataksi
  Map<String, dynamic> toJson() {
    return {
      'kategoria': kategoria,
      'tyyppi': tyyppi,
      'vaikeus': vaikeus,
      'kysymysTeksti': kysymysTeksti,
      'oikeaVastaus': oikeaVastaus,
      'vaaratVastaukset': vaaratVastaukset,
    };
  }
}