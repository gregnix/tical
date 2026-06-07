# tical - iCalendar Support

**Version:** 2.0  
**Stand:** 2025-10-14  
**RFC:** 5545 (Basis-Subset)

---

## Unterstuetzt (v2.0)

### Komponenten
- VCALENDAR (Container)
- VEVENT (Termine/Events)

### Properties
- DTSTART (Start-Zeit, UTC)
- DTEND (End-Zeit, UTC)
- SUMMARY (Titel)
- DESCRIPTION (Beschreibung, optional)
- LOCATION (Ort, optional)
- UID (Eindeutige ID, auto-generiert)

### Wiederholungen (RRULE)
- FREQ=DAILY (taeglich)
- FREQ=WEEKLY (woechentlich)
- FREQ=MONTHLY (monatlich)
- COUNT (Anzahl Wiederholungen)
- UNTIL (Enddatum)
- INTERVAL (Intervall, z.B. alle 2 Tage)

### Zeitzonen
- UTC (mit Z-Suffix, z.B. 20251014T090000Z)
- Alle Zeiten werden als UTC exportiert

---

## NICHT unterstuetzt

### Komponenten
- VTODO (Aufgaben)
- VJOURNAL (Notizen)
- VALARM (Erinnerungen)
- VTIMEZONE (Zeitzone-Definitionen)

### Properties
- EXDATE (Ausnahmen)
- EXRULE (Ausnahme-Regeln)
- RDATE (Zusaetzliche Termine)
- ATTACH (Anhaenge)
- ATTENDEE (Teilnehmer)
- ORGANIZER (Organisator)

### Erweiterte RRULE
- BYMONTH (bestimmte Monate)
- BYDAY (bestimmte Wochentage)
- BYMONTHDAY (bestimmte Monatstage)
- BYHOUR/BYMINUTE/BYSECOND
- BYSETPOS (n-ter Termin)
- BYYEARDAY (bestimmte Jahrestage)
- BYWEEKNO (bestimmte Wochen)
- WKST (Wochenstart)

### Zeitzonen
- VTIMEZONE Komponenten
- TZID Properties
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
    [dict create \
        start "2025-10-14T09:00:00Z" \
        end "2025-10-14T10:00:00Z" \
        title "Team-Standup" \
        description "Daily standup meeting" \
        location "Conference Room A"] \
    [dict create \
        start "2025-10-15T14:00:00Z" \
        end "2025-10-15T15:00:00Z" \
        title "Code Review"]]

tical::io::ical::export $events "calendar.ics"
```

### Export (Mit RRULE)

```tcl
set events [list \
    [dict create \
        start "2025-10-14T09:00:00Z" \
        end "2025-10-14T09:30:00Z" \
        title "Daily Standup" \
        rrule [dict create freq DAILY count 5]]]

tical::io::ical::export $events "recurring.ics"
```

**Ergebnis:**
```
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//tical//v2.0//DE
BEGIN:VEVENT
UID:tical-20251014-090000-abc123
DTSTART:20251014T090000Z
DTEND:20251014T093000Z
SUMMARY:Daily Standup
RRULE:FREQ=DAILY;COUNT=5
END:VEVENT
END:VCALENDAR
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

### v2.1 (geplant):
- VALARM (Erinnerungen)
- EXDATE (Ausnahmen)
- Import (Parser)

### v2.2 (moeglich):
- VTODO (Aufgaben)
- ATTENDEE (Teilnehmer)
- Erweiterte RRULE (BYDAY, BYMONTH)

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

