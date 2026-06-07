# tical::io::ical - API Reference

**Quick Reference** für alle öffentlichen Funktionen.

---

## Export-Funktionen

### exportEvents

**Signatur:**
```tcl
::tical::io::ical::exportEvents events → string
```

**Beschreibung:**  
Exportiert eine Liste von Events zu iCalendar-String.

**Parameter:**
- `events` - Liste von Event-Dicts

**Returns:**  
iCalendar-String (mit CRLF line endings)

**Beispiel:**
```tcl
set events [list \
    [dict create uid "e1" dtstart "20251014T090000Z" summary "Meeting"] \
    [dict create uid "e2" dtstart "20251014T100000Z" summary "Call"]]

set ics [::tical::io::ical::exportEvents $events]
puts $ics
```

---

### exportToFile

**Signatur:**
```tcl
::tical::io::ical::exportToFile events filename → filename
```

**Beschreibung:**  
Exportiert Events direkt in Datei.

**Parameter:**
- `events` - Liste von Event-Dicts
- `filename` - Ziel-Datei (z.B. "calendar.ics")

**Returns:**  
Dateiname (zur Bestätigung)

**Beispiel:**
```tcl
set events [list ...]
::tical::io::ical::exportToFile $events "kalender.ics"
# → Datei erstellt
```

---

### validate

**Signatur:**
```tcl
::tical::io::ical::validate event → 1|error
```

**Beschreibung:**  
Validiert Event-Dict vor Export.

**Parameter:**
- `event` - Event-Dict

**Returns:**
- `1` bei Erfolg
- `error` bei ungültigem Event

**Prüft:**
- Pflicht-Felder: uid, dtstart, summary
- DateTime-Formate
- RRULE-Konsistenz

**Beispiel:**
```tcl
set event [dict create ...]
if {[catch {::tical::io::ical::validate $event} err]} {
    puts "Ungültig: $err"
} else {
    puts "Valid!"
}
```

---

## Convenience-Funktionen

### makeEvent

**Signatur:**
```tcl
::tical::io::ical::makeEvent ?-option value ...? → eventDict
```

**Beschreibung:**  
Erstellt Event-Dict mit automatischer UID und DTSTAMP.

**Optionen:**
- `-dtstart STRING` - Start-Zeit (required)
- `-dtend STRING` - End-Zeit (optional)
- `-summary STRING` - Titel (required)
- `-description STRING` - Beschreibung (optional)
- `-location STRING` - Ort (optional)
- `-status STRING` - Status: TENTATIVE|CONFIRMED|CANCELLED
- `-categories LIST` - Kategorien (optional)
- `-rrule DICT` - Wiederholungs-Regel (optional)

**Beispiel:**
```tcl
set event [::tical::io::ical::makeEvent \
    -dtstart "20251014T090000Z" \
    -dtend "20251014T100000Z" \
    -summary "Team Meeting" \
    -location "Raum A" \
    -status "CONFIRMED"]
```

---

### GenerateUID

**Signatur:**
```tcl
::tical::io::ical::GenerateUID → uid
```

**Beschreibung:**  
Generiert eindeutige UID.

**Format:**  
`timestamp-randomhex@tical`

**Beispiel:**
```tcl
set uid [::tical::io::ical::GenerateUID]
# → 1728907200-a3f8e2c1@tical
```

---

### GetTimestamp

**Signatur:**
```tcl
::tical::io::ical::GetTimestamp → timestamp
```

**Beschreibung:**  
Aktueller UTC-Timestamp für DTSTAMP.

**Format:**  
`YYYYMMDDTHHmmssZ`

**Beispiel:**
```tcl
set now [::tical::io::ical::GetTimestamp]
# → 20251014T093000Z
```

---

## DateTime-Konvertierung

### ISO8601ToICal

**Signatur:**
```tcl
::tical::io::ical::ISO8601ToICal isotime → icaltime
```

**Beschreibung:**  
Konvertiert ISO-8601 zu iCalendar Format.

**Beispiel:**
```tcl
set iso "2025-10-14T09:00:00Z"
set ical [::tical::io::ical::ISO8601ToICal $iso]
# → 20251014T090000Z
```

---

### ICalToISO8601

**Signatur:**
```tcl
::tical::io::ical::ICalToISO8601 icaltime → isotime
```

**Beschreibung:**  
Konvertiert iCalendar zu ISO-8601 Format.

**Beispiel:**
```tcl
set ical "20251014T090000Z"
set iso [::tical::io::ical::ICalToISO8601 $ical]
# → 2025-10-14T09:00:00Z
```

---

## String-Verarbeitung

### Escape

**Signatur:**
```tcl
::tical::io::ical::Escape text → escapedText
```

**Beschreibung:**  
Escaped Text für iCalendar (RFC 5545).

**Escaped:**
- `\` → `\\`
- `;` → `\;`
- `,` → `\,`
- Newline → `\n`

**Beispiel:**
```tcl
set text "Text mit ; und \\ und\nNewline"
set escaped [::tical::io::ical::Escape $text]
# → Text mit \; und \\ und\nNewline
```

---

### Unescape

**Signatur:**
```tcl
::tical::io::ical::Unescape text → unescapedText
```

**Beschreibung:**  
Rückkonvertierung von escaped Text.

**Beispiel:**
```tcl
set escaped {Text mit \; und \\ und\nNewline}
set text [::tical::io::ical::Unescape $escaped]
# → Text mit ; und \ und
#   Newline
```

---

## RRULE (Wiederholungen)

### BuildRRULE

**Signatur:**
```tcl
::tical::io::ical::BuildRRULE rruleDict → rruleString
```

**Beschreibung:**  
Baut RRULE-String aus Dict.

**Dict-Felder:**
- `freq` - DAILY|WEEKLY|MONTHLY|YEARLY (required)
- `count` - Anzahl Wiederholungen (optional)
- `until` - End-Datum (optional, exklusiv zu count)
- `interval` - Intervall (default: 1)
- `byday` - Liste: MO,TU,WE,TH,FR,SA,SU (optional)
- `wkst` - Week start: MO|SU (optional)

**Beispiele:**
```tcl
# Täglich, 10x
set rrule [dict create freq DAILY count 10]
::tical::io::ical::BuildRRULE $rrule
# → FREQ=DAILY;COUNT=10

# Wöchentlich Mo/Mi/Fr, 6 Wochen
set rrule [dict create freq WEEKLY byday {MO WE FR} count 18]
::tical::io::ical::BuildRRULE $rrule
# → FREQ=WEEKLY;COUNT=18;BYDAY=MO,WE,FR

# Monatlich bis Ende Jahr
set rrule [dict create freq MONTHLY until "20251231T235959Z"]
::tical::io::ical::BuildRRULE $rrule
# → FREQ=MONTHLY;UNTIL=20251231T235959Z
```

---

## Event-Dict Struktur

### Minimales Event

```tcl
dict create \
    uid "unique-id@tical" \
    dtstart "20251014T090000Z" \
    summary "Titel"
```

### Vollständiges Event

```tcl
dict create \
    uid "event-123@tical" \
    dtstamp "20251014T080000Z" \
    dtstart "20251014T090000Z" \
    dtend "20251014T100000Z" \
    summary "Team Meeting" \
    description "Wöchentliche Besprechung\nMit Agenda" \
    location "Konferenzraum A" \
    status "CONFIRMED" \
    categories [list "Arbeit" "Meeting"] \
    rrule [dict create freq WEEKLY count 10]
```

### Event mit Wiederholung

```tcl
dict create \
    uid "standup@tical" \
    dtstart "20251014T140000Z" \
    dtend "20251014T143000Z" \
    summary "Daily Standup" \
    rrule [dict create \
        freq DAILY \
        count 30 \
        byday {MO TU WE TH FR} \
        wkst MO]
```

---

## Fehlerbehandlung

### Alle Funktionen werfen Errors bei:

- Ungültige Parameter
- Fehlende Pflicht-Felder
- Falsche DateTime-Formate
- Inkonsistente RRULE (COUNT + UNTIL)

**Best Practice:**
```tcl
if {[catch {
    set ics [::tical::io::ical::exportEvents $events]
} err]} {
    puts stderr "Export fehlgeschlagen: $err"
    return
}

puts "Export erfolgreich!"
puts $ics
```

---

## Beispiel-Workflow

### 1. Events erstellen

```tcl
set events [list]

# Event 1: Einfach
lappend events [::tical::io::ical::makeEvent \
    -dtstart "20251014T090000Z" \
    -dtend "20251014T100000Z" \
    -summary "Kickoff Meeting"]

# Event 2: Mit RRULE
lappend events [::tical::io::ical::makeEvent \
    -dtstart "20251014T140000Z" \
    -summary "Daily Standup" \
    -rrule [dict create freq DAILY count 30]]

# Event 3: Vollständig
lappend events [::tical::io::ical::makeEvent \
    -dtstart "20251015T100000Z" \
    -dtend "20251015T120000Z" \
    -summary "Projekt-Review" \
    -description "Q4 Review mit Team" \
    -location "Hauptsitz, Raum 302" \
    -status "CONFIRMED" \
    -categories [list "Arbeit" "Projekt"]]
```

### 2. Validieren (optional)

```tcl
foreach event $events {
    if {[catch {::tical::io::ical::validate $event} err]} {
        puts "FEHLER in Event: $err"
        return
    }
}
```

### 3. Exportieren

```tcl
# Als String
set ics [::tical::io::ical::exportEvents $events]
puts $ics

# Oder in Datei
::tical::io::ical::exportToFile $events "kalender.ics"
```

---

## Performance

**Benchmark (1000 Events):**
- Export: ~50ms
- Validation: ~20ms
- File Write: ~5ms

**→ Sehr schnell für normale Anwendungsfälle!**

---

## Siehe auch

- [Limitierungen](ICALENDAR-SUPPORT.md)
- [Demo-Skript](../demos/demo-ical-export.tcl)
- [Tests](../tests/ical.test)
- [RFC 5545](https://tools.ietf.org/html/rfc5545)

---

**Version:** 1.0  
**Package:** tical::io::ical  
**Requires:** Tcl 8.6+
