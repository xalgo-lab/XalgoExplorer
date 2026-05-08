# XalgoExplorer

XalgoExplorer ist ein nativer macOS-Dateimanager fuer Nutzerinnen und Nutzer, die von Windows zu macOS wechseln.

Das Ziel ist ein vertrauter, direkter Arbeitsfluss fuer Dateien, kombiniert mit einer nativen macOS-Oberflaeche.

## Funktionen

- Mehrfenster-Arbeitsbereich zum gleichzeitigen Durchsuchen mehrerer Ordner.
- Bekannte Aktionen: Zurueck, Vorwaerts, Nach oben, Aktualisieren, Neuer Ordner, Neue Datei, Ausschneiden, Kopieren und Einfuegen.
- Drag-and-drop nach Finder-Logik: Verschieben auf demselben Laufwerk, Kopieren zwischen Laufwerken.
- Kompakte Seitenleiste fuer Home-Ordner, eigene Kurzbefehle, gemountete Laufwerke und Netzwerkorte.
- Tastaturnavigation, Mausklick-Auswahl und Bereichsauswahl.
- Mehrsprachige Beschriftungen und Tooltips.
- DMG-Paket fuer macOS.

## Kandidatenversion

`v0.1.1-candidate` richtet sich an Apple Silicon macOS 14 oder neuer.

Lade die DMG-Datei aus GitHub Releases herunter und ziehe `xAlgo Explorer.app` in `Applications`.

## Versionshinweise

### v0.1.1-candidate

- Behebt alte interne Drag-Payloads, damit ein abgebrochener Drag spaeter keine falsche Datei verschiebt.
- Validiert Umbenennungen und lehnt unsichere Eingaben wie `../file` oder `a/b` ab.
- Ausschneiden und Einfuegen in denselben Ordner ist jetzt ein no-op und erzeugt keine Duplikate.
- Ergaenzt Finder-kompatibles Kopieren und Einfuegen von Datei-URLs ueber die Systemzwischenablage.
- Fuegt eine sichtbare Schliessen-Schaltflaeche fuer die Suche und Escape-Unterstuetzung hinzu, damit Pfeiltasten wieder die Dateiliste steuern.
- Entfernt das hartcodierte falsche Netzwerkgeraet und zeigt bis zur echten Erkennung einen leeren Netzwerkzustand.
- Aktualisiert Kandidaten-Metadaten, DMG-Namen, README-Hinweise und Regressionstests.

### v0.1.0-candidate

Erste oeffentliche Kandidatenversion mit nativer macOS-Dateimanager-Oberflaeche, Mehrfenster-Navigation, Drag-and-drop-Dateioperationen, Tastaturnavigation, mehrsprachigen Tooltips und signiertem Apple-Silicon-DMG.

## Lizenz

MIT License.
