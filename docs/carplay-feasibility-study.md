# CarPlay-Machbarkeitsstudie: Voxtral Memos

## Ziel

Minimale CarPlay-Integration: **Sprachmemo aufnehmen + automatisch transkribieren**.

Kein Playback, keine Zusammenfassungen, keine Template-Auswahl im Auto.
Der Use-Case ist: "Ich sitze im Auto, habe eine Idee, und will schnell eine Aufnahme machen."

---

## Warum passt das gut?

- Der Kern-Use-Case ("unterwegs schnell eine Idee festhalten") ist perfekt für CarPlay
- Minimale Interaktion = Apple-HIG-konform (geringe Ablenkung)
- `VoxtralCore` ist bereits als separates Swift Package aufgebaut – Recording, Transkription und SwiftData-Models sind UI-unabhängig und direkt wiederverwendbar
- Keine externen Dependencies nötig

---

## Scope: Was wird gebaut?

| Feature | Beschreibung |
|---|---|
| **CarPlay-Scene** | `CPTemplateApplicationSceneDelegate` mit einem einfachen `CPListTemplate` |
| **Aufnahme-Button** | Ein einzelner Listen-Eintrag: "Neue Aufnahme" → startet/stoppt Recording |
| **Status-Anzeige** | Aufnahmedauer als Untertitel im Listen-Eintrag (aktualisiert sich live) |
| **Auto-Transkription** | Nach Aufnahme-Ende wird automatisch die Transkription angestoßen (wie in der iPhone-App) |
| **Background Audio** | `AVAudioSession`-Konfiguration für Aufnahme im Hintergrund |

### Was wird NICHT gebaut

- Keine Memo-Liste / Wiedergabe in CarPlay
- Kein Text-to-Speech / Vorlesen von Transkripten
- Keine Template-Auswahl oder AI-Transformationen im Auto
- Keine Siri-Integration (kann später ergänzt werden)
- Kein `CPNowPlayingTemplate`

---

## Technische Umsetzung

### 1. Apple CarPlay Entitlement

**Voraussetzung:** CarPlay-Entitlement muss bei Apple beantragt werden.

- Formular: https://developer.apple.com/carplay/
- Kategorie: Am besten als **Audio-App** beantragen
- Wartezeit: Typisch 1–2 Wochen
- Ohne dieses Entitlement kann die App nicht auf CarPlay erscheinen

### 2. Neue Dateien

```
VoxtralMemos/
├── CarPlay/
│   └── CarPlaySceneDelegate.swift    # CPTemplateApplicationSceneDelegate
├── Info.plist                        # + CarPlay Scene-Konfiguration
├── VoxtralMemos.entitlements         # + com.apple.developer.carplay-audio
└── project.yml                       # + Background Modes, CarPlay-Scene
```

### 3. CarPlaySceneDelegate (Kernstück)

```swift
import CarPlay
import VoxtralCore

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let recorder = AudioRecorderService()
    private var isRecording = false
    private var recordingTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let template = buildListTemplate()
        interfaceController.setRootTemplate(template, animated: false)
    }

    private func buildListTemplate() -> CPListTemplate {
        let recordItem = CPListItem(
            text: "Neue Aufnahme",
            detailText: "Tippen zum Starten",
            image: UIImage(systemName: "mic.circle.fill")
        )
        recordItem.handler = { [weak self] _, completion in
            self?.toggleRecording(item: recordItem)
            completion()
        }

        let section = CPListSection(items: [recordItem])
        return CPListTemplate(title: "Voxtral Memos", sections: [section])
    }

    private func toggleRecording(item: CPListItem) {
        if isRecording {
            stopRecording(item: item)
        } else {
            startRecording(item: item)
        }
    }

    private func startRecording(item: CPListItem) {
        // AVAudioSession konfigurieren, Aufnahme starten
        // Timer für Live-Dauer-Anzeige
        // item.setText("Aufnahme läuft...")
        // item.setDetailText("00:00 – Tippen zum Stoppen")
    }

    private func stopRecording(item: CPListItem) {
        // Aufnahme stoppen
        // Memo in SwiftData speichern
        // Transkription automatisch anstoßen
        // item.setText("Neue Aufnahme")
        // item.setDetailText("Tippen zum Starten")
    }
}
```

### 4. Info.plist Ergänzungen

```xml
<!-- Neue CarPlay-Scene-Konfiguration -->
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <!-- Bestehende iPhone-Scene bleibt -->
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
            </dict>
        </array>
    </dict>
</dict>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 5. Entitlements

Ergänzung in `VoxtralMemos.entitlements`:

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```

### 6. project.yml Änderungen

```yaml
# Unter dem VoxtralMemos-Target:
settings:
  UIBackgroundModes: [audio]

entitlements:
  com.apple.developer.carplay-audio: true

# Neue Quell-Dateien einschließen:
sources:
  - path: VoxtralMemos
    includes:
      - "**/*.swift"  # Schließt CarPlay/ automatisch ein
```

### 7. Audio-Session-Anpassungen

`AudioRecorderService` muss erweitert werden, damit Recording auch funktioniert,
wenn die iPhone-App im Hintergrund ist (CarPlay ist ein separater Screen):

```swift
// In AudioRecorderService oder einer neuen CarPlay-spezifischen Konfiguration:
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```

Die bestehende `AudioRecorderService` nutzt bereits `.playAndRecord` – es muss
hauptsächlich sichergestellt werden, dass die Background-Audio-Capability aktiv ist.

### 8. SwiftData-Sharing zwischen Scenes

Beide Scenes (iPhone + CarPlay) laufen im selben Prozess und können denselben
`ModelContainer` nutzen. Der bestehende Container aus `VoxtralMemosApp.swift` muss
als Singleton zugänglich gemacht werden, z.B.:

```swift
// Shared ModelContainer für beide Scenes
@MainActor
enum SharedModelContainer {
    static let shared: ModelContainer = {
        // Bestehende Container-Konfiguration hierher verschieben
    }()
}
```

---

## Aufwandsschätzung

| Aufgabe | Aufwand |
|---|---|
| Apple CarPlay Entitlement beantragen | ~1–2 Wochen Wartezeit |
| `CarPlaySceneDelegate` implementieren | 1 Tag |
| Info.plist + Entitlements + project.yml | 0.5 Tage |
| Audio-Session für Background-Recording anpassen | 0.5 Tage |
| SwiftData-Container als Singleton teilen | 0.5 Tage |
| Auto-Transkription nach Aufnahme-Ende triggern | 0.5 Tage |
| Testen im CarPlay-Simulator | 0.5 Tage |
| Testen auf echtem CarPlay-Gerät | 0.5 Tage |
| **Gesamt Entwicklungszeit** | **~4 Tage** |

---

## Risiken

| Risiko | Wahrscheinlichkeit | Mitigation |
|---|---|---|
| Apple lehnt CarPlay-Entitlement ab | Mittel | Klarer Use-Case (Voice Recording) argumentieren; ggf. als "Communication"-App beantragen |
| Mikrofon-Zugriff über CarPlay eingeschränkt | Gering | iPhone-Mikrofon wird genutzt, nicht das Auto-Mikrofon; funktioniert standard |
| Netzwerk im Tunnel nicht verfügbar | Hoch | Aufnahme funktioniert offline; Transkription wird nachgeholt sobald Netz verfügbar |
| App Review lehnt CarPlay-Funktionalität ab | Gering | Minimaler Scope = wenig Ablenkung = HIG-konform |

---

## Mögliche spätere Erweiterungen

Falls die Basis-Integration erfolgreich ist, könnten folgende Features nachgezogen werden:

1. **Siri-Integration** – "Hey Siri, starte eine Voxtral-Aufnahme"
2. **Aufnahme-Liste** – Die letzten 5 Memos in CarPlay anzeigen (nur Titel + Datum)
3. **Wiedergabe** – Memos über das Auto-Audiosystem abspielen
4. **Transkript vorlesen** – Text-to-Speech über `AVSpeechSynthesizer`
5. **Live-Transkription** – Echtzeit-Anzeige kurzer Textfragmente während der Aufnahme

---

## Fazit

Die minimale CarPlay-Integration (nur Aufnahme + Auto-Transkription) ist ein **überschaubares Projekt von ca. 4 Entwicklertagen**. Die bestehende Architektur mit dem separaten `VoxtralCore`-Package macht es einfach, da `AudioRecorderService`, `TranscriptionService` und die SwiftData-Models direkt wiederverwendet werden können.

Der größte Unsicherheitsfaktor ist die **Apple-Genehmigung des CarPlay-Entitlements**, die 1–2 Wochen dauern kann und nicht garantiert ist.
