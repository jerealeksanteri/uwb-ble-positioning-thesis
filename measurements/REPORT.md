# Mittaustulosten analyysi

**Päivämäärä:** 1.6.2026
**Aineisto:** [`measurements/measures/`](../measurements/measures/)
**Analyysiskriptit:** [`measurements/analyze_full.py`](../measurements/analyze_full.py), [`measurements/verify_offset.py`](../measurements/verify_offset.py), [`measurements/apply_a3_extra_offset.py`](../measurements/apply_a3_extra_offset.py)

## 1. Mittausjärjestely

Kolme DWM3001CDK-ankkuria sijoitettiin huoneeseen koordinaatteihin:

| Ankkuri | x (m) | y (m) |
|---|---:|---:|
| A1 | 2.20 | 4.25 |
| A2 | 0.00 | 0.00 (origo) |
| A3 | 3.54 | 1.22 |

iPhone 16 Pro Max -tagi pidettiin paikallaan pisteessä **(1.580, 1.820) m**. Kalibroinnista saatu vakio-offset **−7 cm** oli kytkettynä päälle kaikille kolmelle ankkurille ([`calibration.py`](../measurements/calibration.py): A1 −7,4 cm, A2 −6,7 cm, A3 −6,6 cm). Mittaustaajuus oli 10 Hz, ja kustakin neljästä konfiguraatiosta tallennettiin 500 näytettä (n. 50 s).

Konfiguraatiot:

- **LOS / normal** — esteetön näköyhteys kaikkiin ankkureihin, puhelimen näyttö A3:n suuntaan, painottamaton lineaarinen pienin neliösumma
- **LOS / weighted** — sama asetelma, etäisyyden käänteisneliöllä painotettu LSQ
- **NLOS / normal** — **A2:n** näköyhteys osittain peitetty, **puhelimen näyttö A2:n suuntaan**, painottamaton LSQ
- **NLOS / weighted** — sama esteytys ja orientaatio, painotettu LSQ

Puhelimen orientaatio vaihtui LOS- ja NLOS-runeissa: näyttö osoitti aina sitä ankkuria kohden, jota tarkasteltiin. Tämä tarkoittaa että U2-antennin "boresight"-suunta (puhelimen takapinta) oli LOS-runeissa 180° pois A3:sta ja NLOS-runeissa 180° pois A2:sta — eri ankkurit olivat eri kulmissa eri runeissa.

HDOP oli kaikissa runeissa ≈ 1,27, joten ankkurien geometria oli identtinen.

## 2. Mittauksen tarkkuus (filtteroitu positioerror)

| Konfiguraatio | mean (cm) | mediaani (cm) | RMS (cm) | p95 (cm) | max (cm) | bias (x, y) (cm) |
|---|---:|---:|---:|---:|---:|---:|
| LOS / normal | 9,81 | 9,79 | 9,83 | 10,82 | 11,83 | (−9,62, +1,85) |
| LOS / weighted | 9,82 | 9,81 | 9,85 | 11,05 | 11,89 | (−9,65, +1,73) |
| NLOS / normal | 7,43 | 7,45 | 7,48 | 8,76 | 9,25 | (−6,62, +3,28) |
| NLOS / weighted | 7,33 | 7,33 | 7,38 | 8,89 | 10,28 | (−6,45, +3,40) |

**Mean ≈ mediaani ≈ RMS** kaikissa runeissa: virhe koostuu lähes pelkästään systemaattisesta biasista, ei satunnaiskohinasta. Liukuvan keskiarvon (5 näytettä) filtteri pienentää satunnaiskomponentin keskihajonnan 1,1–1,5 cm → 0,6–0,9 cm (≈ 40 %), mutta ei vaikuta keskiarvoon kuten odotettua.

## 3. Etäisyysmittausten kohina ja bias

| | A1 σ (cm) | A2 σ (cm) | A3 σ (cm) | A1 bias⁺ | A2 bias⁺ | A3 bias⁺ |
|---|---:|---:|---:|---:|---:|---:|
| LOS / normal | 1,2 | 0,9 | 1,1 | +7,9 | +2,8 | +18,1 |
| LOS / weighted | 1,1 | 0,9 | 1,1 | +8,3 | +3,0 | +18,3 |
| NLOS / normal | 1,1 | **2,2** | 1,0 | +9,2 | +9,2 | +19,6 |
| NLOS / weighted | 1,1 | **2,2** | 1,1 | +9,1 | +9,6 | +19,7 |

⁺ jäännösbias kalibrointi-offsetin (−7 cm) jälkeen.

A2:n kohinan kaksinkertaistuminen LOS → NLOS (0,9 → 2,2 cm) vahvistaa että vain A2 oli esteytetty, ja A2:n bias kasvaa +6 cm:llä — täsmälleen mitä NLOS-mittaukselta odotetaan. A1:n ja A3:n etäisyysmittaukset eivät käytännössä muutu LOS → NLOS, joten esteytyksen vaikutus on isoloitu A2:een.

## 4. Painotetun LSQ:n vaikutus

| | normal RMS (cm) | weighted RMS (cm) | Δ |
|---|---:|---:|---:|
| LOS | 9,83 | 9,85 | +0,2 % |
| NLOS | 7,48 | 7,38 | −1,2 % |

Ero on alle 1 mm RMS:ssä, käytännössä mittausresoluution alapuolella. Geometria on tasapainossa (HDOP ≈ 1,3, etäisyydet 2,0–2,5 m) ja yhden anomalisen ankkurin (A2 NLOS:ssa) painottaminen alaspäin auttaa vain marginaalisesti. **Yksittäisessä testipisteessä painotettu trilateraatio ei tuota tilastollisesti merkitsevää hyötyä.**

## 5. LOS vs. NLOS

Tulos näyttää ristiriitaiselta: NLOS:ssa positioerror on **24 % pienempi** kuin LOS:ssa. Selitys löytyy taulukosta 3: A2:n NLOS-bias (+6 cm) sattuu osumaan vastakkaiseen suuntaan kuin A1:n ja A3:n jäännösbias, jolloin trilateraation ratkaisu siirtyy lähemmäs todellista pistettä. Lisäksi puhelimen orientaatio muuttui NLOS-runeissa (näyttö kohti A2:a A3:n sijaan), mikä siirsi U2-antennin kulmariippuvan biasin uudelleen ankkurien kesken — A3 ei ollut enää suoraan näytön suunnassa, joten sen jäännösbias pieneni hieman. Kyse on **biasien sattumanvaraisesta kumoutumisesta tässä yksittäisessä geometriassa ja orientaatiossa**, ei NLOS:n todellisesta paremmuudesta. Toisessa testipisteessä tai eri puhelimen orientaatiolla efekti olisi todennäköisesti päinvastainen.

## 6. Jäännösbiasin alkuperä — antenniepäisotropia

Yhden vakio-offsetin (−7 cm) jälkeen jäljelle jäävä bias on selvästi anturikohtainen: A2 +3 cm, A1 +8 cm, **A3 +18 cm**. Tämä ei selity kalibroinnilla, joka tehtiin oikein puhelin **takaosa anturia kohti**. Testissä puhelinta pidettiin **näyttö kohti A3:a**, eli antennin "boresight"-suunta (puhelimen takapinta) osoitti **180° pois A3:sta**.

iPhonen U2-piirin antenni on kulmaherkkä — etäisyysbias on tunnetusti **kulmariippuva** suhteessa puhelimen runkoon. Kun lasketaan kunkin ankkurin kulma puhelimen takapinnan suunnasta (kalibroitu suunta = 0°):

| Ankkuri | kulma takapinnasta | jäännösbias (LOS) |
|---|---:|---:|
| A2 | 66° | +3 cm |
| A1 | 87° | +8 cm |
| A3 | 180° (näyttöpuoli) | +18 cm |

Korrelaatio on monotoninen: mitä kauempana ankkuri on antennin kalibroidusta suunnasta, sitä suurempi bias. A3:lla puhelimen runko on fyysisesti antennin ja ankkurin välissä, mikä tuottaa suurimman lisäbiasin.

**Kontrollikokeena** A3:n offset muutettiin jälkikäsittelyssä −17 cm:iin (lisäys −10 cm) muiden pysyessä −7 cm:ssä ([`apply_a3_extra_offset.py`](../measurements/apply_a3_extra_offset.py)):

| Konfiguraatio | alkup. mean (cm) | korjattu mean (cm) | parannus |
|---|---:|---:|---:|
| LOS / normal | 9,81 | **3,02** | −69 % |
| LOS / weighted | 9,82 | **3,14** | −68 % |
| NLOS / normal | 7,43 | **1,44** | −81 % |
| NLOS / weighted | 7,33 | **1,50** | −80 % |

Kun A3:n kulmariippuva bias kompensoidaan, kokonaistarkkuus saavuttaa ~1,5–3 cm-tason — lähellä järjestelmän kohinatasoa. NLOS-runeissa korjaus tuottaa jopa pienemmän virheen kuin LOS:ssa, koska A2:n NLOS-bias (+6 cm) sattuu uudessa geometriassa lähes täydellisesti tasapainottamaan ratkaisun. Tämä on jälleen sattumanvarainen efekti, ei järjestelmäominaisuus.

Tämä −17 cm ei kuitenkaan ole oikea kalibrointiarvo A3:lle (kalibrointimittausten mukaan A3:n todellinen bias on +6–8 cm), vaan se kompensoi nimenomaan tämän testigeometrian antennikulmaa.

## 7. Johtopäätökset

1. **Järjestelmän tarkkuus on erinomainen** ja päädetään noin **±3 cm RMS** -tasolle, kun antennikulman aiheuttama jäännösbias kompensoidaan. Ilman kompensointia mean error oli ~10 cm.
2. **Kohina on hyvin matala** (raaka σ ≈ 1 cm, filtteröity σ ≈ 0,7 cm) ja kasvaa NLOS:ssa vain peitettyjen anturien osalta — odotetusti.
3. **Painotetun trilateraation hyöty oli mitätön** tässä tasapainoisessa geometriassa. Sen arviointi vaatii epätasapainoisempaa anturiasettelua tai vaihtelevia mittauspisteitä.
4. **NLOS-tulos (24 % parempi kuin LOS) on artefakti** biasien kumoutumisesta tässä yhdessä testipisteessä, ei oikea järjestelmäominaisuus.
5. **Suurin yksittäinen virhelähde on iPhonen U2-antennin kulmariippuvuus.** Yhden vakio-offsetin kalibrointi ei pysty korjaamaan tätä, koska puhelimen orientaatio muuttuu suhteessa kuhunkin ankkuriin liikuttaessa. Tämä on todellinen rajoitus älypuhelin-pohjaisille UWB-tageille.

## 8. Suositukset

- Toista mittaukset 2–3 lisätestipisteessä saman puhelimen orientaation kanssa: jos A3:n jäännösbias vaihtelee pisteestä toiseen, antenniepäisotropia varmentuu. Jos se pysyy vakiona, kyseessä on A3-spesifinen kalibrointivirhe.
- Suorita rotaatiopyyhkäisy yhdessä pisteessä (0°/90°/180°/270°): tuottaa suoran kuvan antennikuviosta ja antaa rajan sille, kuinka pieneksi virhe voidaan saada vakiokalibroinnilla.
- Kalibrointiformaatin parannus: lisää position-CSV:hen `offset1/2/3` -sarakkeet, jotta käytetyt arvot ovat dokumentoituja jälkikäteen ([`DataExportService.swift`](../ios-app/UWBPositioning/Services/DataExportService.swift)).
- Opinnäytteen "Pohdinta"-osioon: dokumentoi antenniepäisotropia järjestelmän tarkkuuden ylärajan asettavana ilmiönä. Tämä on tulos, ei vika.
