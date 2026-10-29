# tical - iCalendar Support

**Version:** 1.1.1  
**Stand:** 2026-10-28  
**RFC:** 5545 (Basis-Subset)

---

## Unterstuetzt (tical 1.1.1)

### Komponenten
- VCALENDAR (Container)
- VEVENT (Termine/Events)

### Properties
- UID (Pflicht; `makeEvent` erzeugt eine)
- DTSTAMP (Zeitpunkt des Exports)
- DTSTART (Start-Zeit, Pflicht); ganztaegig als `DTSTART;VALUE=DATE:YYYYMMDD`
- DTEND oder DURATION (optional); ganztaegig `DTEND;VALUE=DATE`, exklusiv
  (Tag nach dem letzten Tag)
- SUMMARY (Titel, Pflicht)
- DESCRIPTION (Beschreibung, optional)
- LOCATION (Ort, optional)
- STATUS (optional)
- CATEGORIES (optional, Liste)
- EXDATE (Ausnahmen, optional, Liste; je Datum eine Zeile)

### Wiederholungen (RRULE)
- FREQ=DAILY|WEEKLY|MONTHLY|YEARLY
- COUNT (Anzahl Wiederholungen)
- UNTIL (Enddatum; nicht zusammen mit COUNT)
- INTERVAL (Intervall, z.B. alle 2 Tage)
- BYDAY (Wochentage, z.B. MO,WE,FR)
- BYMONTH, BYMONTHDAY (Export: durchgereicht)
- WKST (Wochenstart)

### Richtung
- Export: `tical::io::ical` (`exportEvents`, `exportToFile`); jedes Event
  laeuft vorher durch `tical::event::normalize` (ISO-Datum, aeltere
  Feldnamen von `tical::model`/`tical::adapter::sqlite`).
- Import (optional): `tical::io::import` mit tclutils (`tclutils::tuical`
  liest; RRULE loest seit 1.1.1 `tical::event::expand` auf, das auch die
  Views benutzen). Gelesen werden UID, SUMMARY,
  DESCRIPTION, LOCATION, STATUS, CATEGORIES, DTSTART/DTEND (VALUE=DATE),
  DURATION, RRULE, EXDATE, RECURRENCE-ID. Ergebnis: Termine im Format von
  `tical::event`. RRULE-Teile, die tical nicht kennt (BYSETPOS,
  BYWEEKNO, BYYEARDAY, BYHOUR ...), sind ein Fehler `{TICAL IMPORT RRULE}`.

### Zeitzonen
- UTC (mit Z-Suffix, z.B. 20251014T090000Z), empfohlen
- Zeiten werden unveraendert geschrieben; ohne Z gelten sie als lokale
  ("floating") Zeit, eine Umrechnung findet nicht statt
- Import: `TZID` bleibt als Schluessel `tzid` erhalten, mit der Uhrzeit
  dieser Zone; `tical::event` und die Views rechnen sie in die
  Anzeigezone um. Serien werden in ihrer Zone aufgeloest (Sommerzeit).
  Verstanden werden IANA-Namen, Praefix-IDs (`/mozilla.org/.../Europe/Berlin`)
  und gaengige Windows-Namen (`W. Europe Standard Time`); eine unbekannte
  TZID (eigene VTIMEZONE) laesst die Zeit als lokale Zeit stehen.
- Export: lokale Zeiten mit `tzid` bekommen `TZID=` (IANA-Name, ohne
  VTIMEZONE-Komponente); `recurrence-id` wird `RECURRENCE-ID`, eine
  verschobene Instanz bleibt beim Wiedereinlesen eine Ausnahme der Serie

---

## NICHT unterstuetzt

### Komponenten
- VTODO (Aufgaben)
- VJOURNAL (Notizen)
- VALARM (Erinnerungen)
- VTIMEZONE (Zeitzone-Definitionen)

### Properties
- EXRULE (Ausnahme-Regeln)
- RDATE (Zusaetzliche Termine)
- ATTACH (Anhaenge)
- ATTENDEE (Teilnehmer)
- ORGANIZER (Organisator)

### Erweiterte RRULE
- BYHOUR/BYMINUTE/BYSECOND
- BYSETPOS (n-ter Termin)
- BYYEARDAY (bestimmte Jahrestage)
- BYWEEKNO (bestimmte Wochen)

### Zeitzonen
- VTIMEZONE Komponenten
- VTIMEZONE beim Export; eigene VTIMEZONE-Regeln beim Import
- Zeitzone-Regeln
- DST (Sommerzeit/Winterzeit)

---

## Grund fuer Einschraenkungen

**Philosophie:** Qualitaet vor Feature-Vollstaendigkeit

- Fokus auf stabile Basis-Features
- Keine halbfertigen Implementierungen
- Zeitzonen richtig oder gar nicht (UTC ist korrekt!)
- RFC 5545 ist RIESIG (174 Seiten) - wir brauchen nur 10%

**Ergebnis:**
- Kleine, wartbare Implementation
- 100% korrekt was implementiert ist
- Klare Limitierungen dokumentiert

---

## Verwendung

### Export (Basis-Events)

```tcl
package require tical::io::ical

set events [list \
    [tical::io::ical::makeEvent \
        -dtstart 20251014T090000Z \
        -dtend 20251014T100000Z \
        -summary "Team-Standup" \
        -description "Daily standup meeting" \
        -location "Conference Room A"] \
    [tical::io::ical::makeEvent \
        -dtstart 20251015T140000Z \
        -dtend 20251015T150000Z \
        -summary "Code Review"]]

tical::io::ical::exportToFile $events "calendar.ics"
```

### Export (Mit RRULE und EXDATE)

```tcl
set events [list \
    [tical::io::ical::makeEvent \
        -uid standup-1@example.org \
        -dtstart 20251014T090000Z \
        -dtend 20251014T093000Z \
        -summary "Daily Standup" \
        -rrule [dict create freq DAILY count 5] \
        -exdate {20251016T090000Z}]]

tical::io::ical::exportToFile $events "recurring.ics"
```

**Ergebnis** (ohne die Zeile DTSTAMP):
```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//tical//tical 1.1.1//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
BEGIN:VEVENT
UID:standup-1@example.org
DTSTART:20251014T090000Z
DTEND:20251014T093000Z
SUMMARY:Daily Standup
RRULE:FREQ=DAILY;COUNT=5
EXDATE:20251016T090000Z
END:VEVENT
END:VCALENDAR
```

### Export (ganztaegig)

```tcl
set ev [tical::io::ical::makeEvent -uid messe-1@example.org \
    -summary Messe -dtstart 2025-10-20 -dtend 2025-10-23]
tical::io::ical::exportEvents [list $ev]
```

Der VEVENT (ohne DTSTAMP), Messe vom 20. bis 22. Oktober:
```
BEGIN:VEVENT
UID:messe-1@example.org
DTSTART;VALUE=DATE:20251020
DTEND;VALUE=DATE:20251023
SUMMARY:Messe
END:VEVENT
```

### Import und Wiederholungen

```tcl
package require tical::io::import   ;# braucht tclutils
set events [tical::io::import::readFile termine.ics]
set oct    [tical::io::import::expand $events 2025-10-01 2025-10-31]
```

---

## Kompatibilitaet

### Getestet mit:
- Google Calendar (Import)
- Apple Calendar (Import)
- Thunderbird (Import)

### Format-Garantien:
- CRLF Line-Endings (Windows-kompatibel)
- UTF-8 Encoding
- RFC 5545 konformes Escaping
- Line-Folding bei > 75 Zeichen

---

## Erweiterungen (Zukunft)

### Geplant:
- VALARM (Erinnerungen)

### Moeglich:
- VTODO (Aufgaben)
- ATTENDEE (Teilnehmer)

### NICHT geplant:
- VTIMEZONE (zu komplex, UTC reicht)
- Volle RFC 5545 Implementierung

---

## Siehe auch

- [README.md](../README.md) - tical Hauptdokumentation
- RFC 5545: https://tools.ietf.org/html/rfc5545

---

**Wichtigster Punkt:** 

> Wir exportieren nur was wir **korrekt** implementieren koennen.  
> UTC statt kaputte Zeitzonen.  
> Basis-RRULE statt buggy komplexe Regeln.

**Ehrlichkeit gegenueber Nutzern = Vertrauen.**

