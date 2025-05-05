# tietovisa

# Asennus

pub get

Tekijät: Vesa Huhtaniska & Sami Pyhtinen

# TriviaVisa

Kevyt Flutter-pohjainen triviapeli Androidille (ja muille alustoille), kehitetty Android Studio Ladybug -versiolla.

---

## 🚀 Esittely

TriviaVisa on monivalintatriviapeli, jossa pelaaja vastaa satunnaisesti haettuihin kysymyksiin eri kategorioista. Oikeasta vastauksesta saa +20 pistettä, väärästä tai aikakatkosta −5 pistettä. Peli kerää tulokset paikalliseen tallennukseen, ja parhaat tulokset näytetään aina pistetaulukossa.

---

## 🔧 Esivaatimukset

- [Flutter SDK](https://flutter.dev/) (viimeisin versio)
- Android Studio Ladybug (tai uudempi)
- Java 11 (Android SDK tarvitsee)
- (iOS-kehitykseen) Xcode 12+
- Git

---

## 📥 Asennus

1. Kloonaa repo
   ```bash
   git clone https://github.com/Vesku81/tiimi7.git
   cd tiimi7

2. Asenna Flutterin riippuvuudet
   flutter pub add provider
   flutter pub get

## ▶️ Sovelluksen käynnistäminen

1. Liitä Android-laite tai käynnistä emulaattori.

2. Rakenna ja suorita: flutter run

3. Sovellus käynnistyy laitteella/emulaattorissa.

## 📁 Kansiorakenne

├── lib/
│   ├── main.dart             # Sovelluksen entrypoint
│   ├── mallikansiot/
│   │   └── kysymys.dart      # Kysymys-malliluokka
│   ├── palvelut/
│   │   └── trivia_api_palvelu.dart
│   ├── tarjoajat/
│   │   ├── trivia_tarjoaja.dart
│   │   └── asetukset_tarjoaja.dart
│   ├── utils/
│   │   └── vakiot.dart
│   └── nakymat/
│       ├── aloitus_nakyma.dart
│       ├── asetukset_nakyma.dart
│       ├── peli_nakyma.dart
│       └── tulokset_nakyma.dart
├── assets/
│   ├── images/
│   └── sounds/
├── pubspec.yaml
└── README.md

## ⚙️ Ominaisuudet
- Monivalintakysymykset: satunnainen kysymyspaketti OpenTDB-API:sta
- Aikaraja: 10 sekuntia per kysymys
- Pisteytys: +20 / −5
- Ääniasetukset: voit ottaa äänet käyttöön/pois ja säätää äänenvoimakkuutta
- Tulosten tallennus: parhaat pisteet pysyvät muistissa SharedPreferencesissa
- Responsiivinen UI: skaalaa eri laitteille ja näyttösuhteille

## 🔄 Kehitys ja testaus
- Uusi versio Flutterista: flutter upgrade
- Yksikkötestit (jos lisäät testejä): flutter test

## 🤝 Contributing
- Forkkaa reposi
- Luo feature-haara (git checkout -b feature/UusiOminaisuus)
- Tee commit (git commit -am 'Lisää uusi ominaisuus')
- Pushaa haara (git push origin feature/UusiOminaisuus)
- Avaa Pull Request

## 