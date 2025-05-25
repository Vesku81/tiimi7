## tietovisa

**Tekijät:** Vesa Huhtaniska & Sami Pyhtinen

---

## 🚀 Esittely

**Tietovisa** on Flutterilla toteutettu monivalintatriviapeli Androidille.  
Pelaaja vastaa satunnaisesti Open Trivia DB -API:sta tai OpenAI:n generoimista haettuihin kysymyksiin eri kategorioista.  
Oikeasta vastauksesta saa **+20 pistettä**, väärästä tai aikakatkosta **−5 pistettä**.  
Peli tallentaa tulokset paikallisesti ja näyttää parhaat suoritukset pistetaulukossa.

---

## 📋 Sisältö

- [Ominaisuudet]
- [Esivaatimukset]
- [Asennus ja käynnistys]
- [Kansiorakenne]
- [Tekniset yksityiskohdat]

---

## ⚙️ Ominaisuudet

- **Monivalintakysymykset**
   - Haetaan Open Trivia DB -API:sta tai — käyttäjän asetuksista riippuen — generaattorina OpenAI:n avulla.
- **Aikaraja**
   - Kysymykseen on 20 sekuntia aikaa, puheentunnistus käynnistyy automaattisesti puolessa välissä.
- **Pisteytys**
   - +20 pistettä oikein vastatusta, −5 pistettä väärin vastatusta tai ajan loppumisesta.
- **Ääniasetukset**
   - Taustamusiikki päälle/pois, äänenvoimakkuuden säädin.
   - Käännä kysymykset puheeksi (TTS) & vastaa puhumalla (STT).
- **Käännökset**
   - Peruskysymykset käännetään ML Kit -käännöksellä englannista suomeksi.
- **Tulosten hallinta**
   - Tulokset tallennetaan `SharedPreferences`iin; parhaat esitetään pistetaulukossa.
- **Asetukset-sivu**
   - Aihealueen ja vaikeustason valinta, OpenAI-kysymysten generoinnin päälle/pois, puheasetukset.
- **Navigaatio**
   - Drawerista pääsee aloittamaan pelin, selaamaan asetuksia ja tuloksia.
- **Responsiivinen UI**
   - Skaalaa eri näyttösuhteille, tummalle/vaalealle taustalle taustakuvineen.

---

## 🔧 Esivaatimukset

- [Flutter SDK](https://flutter.dev/) (viimeisin versio)
- Android Studio Ladybug tai uudempi
- Java 11 (Android SDK:n vaatimus)
- Git

---

## 📥 Asennus ja käynnistys

1. **Kloonaa repo**
   ```bash
   git clone https://github.com/Vesku81/tiimi7.git
   cd tiimi7

2. **Asenna riippuvuudet**
   ```flutter pub add provider
   ```flutter pub get
   
3. **Suorita sovellus**
   ```Liitä Android-laite tai käynnistä emulaattori
   ```Aja komento: flutter run

--- 

## 📁 Kansiorakenne

   ├── lib/
   │   ├── main.dart                 # Sovelluksen entrypoint ja provider-kokoonpano
   │   ├── mallikansiot/
   │   │   └── kysymys.dart          # Kysymys-malli JSON- ja oliomuunnoksilla
   │   ├── palvelut/
   │   │   ├── trivia_api_palvelu.dart  # OpenTDB-kysymysten haku + HTML-unescape
   │   │   ├── openai_palvelu.dart      # OpenAI-kysymysten generointi + duplikaattitarkistus
   │   │   └── puhepalvelu.dart         # STT & TTS kapselointi (speech_to_text, flutter_tts)
   │   ├── tarjoajat/
   │   │   ├── asetukset_tarjoaja.dart  # SharedPreferences-asetusten luku/kirjoitus
   │   │   └── trivia_tarjoaja.dart     # Pelilogiikka: kysymysten haku, pisteet, käännökset
   │   ├── utils/
   │   │   └── vakiot.dart              # API-perus-URL ja muut vakioarvot
   │   └── nakymat/
   │       ├── aloitus_nakyma.dart      # Käyttäjänimen syöttö + drawer-navigaatio
   │       ├── peli_nakyma.dart         # Pääpelinäkymä: kysymykset, ajastin, äänet, STT/TTS
   │       ├── asetukset_nakyma.dart    # Asetussivu UI-elementeillä ja Provider-kytkennöillä
   │       └── tulokset_nakyma.dart     # Tulosten ja historiapistetilaston näyttö
   ├── assets/
   │   ├── images/                      # Taustakuvat, drawer-kuvat
   │   └── sounds/                      # Taustamusiikki, voitto/häviöäänet
   ├── pubspec.yaml                     # Flutter-dependenssit ja assetit
   └── README.md                        # Tämä dokumentti

---

## 🛠️ Tekninen toteutus
State Management: Provider
HTTP & JSON: http, dart:convert, html_unescape
Persistence: shared_preferences

AI-rajapinnat:
Open Trivia DB (perinteinen API)
OpenAI Chat Completions (GPT-3.5-turbo)
ML Kit -käännökset: google_mlkit_translation

Puhe:
STT: speech_to_text
TTS: flutter_tts
Audio: audioplayers

---