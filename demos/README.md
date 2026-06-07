# tical Demos

**16 vollständige Demo-Skripte** zeigen alle Features von tical v2.0.

---

## 📋 Terminal Demos (4)

### 1. demo-month-term.tcl
Monatskalender im Terminal mit Farben, KW, Heute-Marker.
```bash
tclsh demo-month-term.tcl
```

### 2. demo-week-term.tcl
Wochenkalender im Terminal (7 Tage).
```bash
tclsh demo-week-term.tcl
```

### 3. demo-day-term.tcl
Tageskalender im Terminal (24 Stunden).
```bash
tclsh demo-day-term.tcl
```

### 4. demo-year-term.tcl ⭐ NEU!
Kompletter Jahreskalender (12 Monate, 4x3 Grid) mit KW.
```bash
tclsh demo-year-term.tcl
```

---

## 🖼️ Canvas GUI Demos (4)

### 5. demo-month-canvas.tcl
Interaktiver Monatskalender (GUI) mit Hover, Click Events.
```bash
wish demo-month-canvas.tcl
```

### 6. demo-week-canvas.tcl
Interaktiver Wochenkalender (GUI).
```bash
wish demo-week-canvas.tcl
```

### 7. demo-day-canvas.tcl
Interaktiver Tageskalender (GUI).
```bash
wish demo-day-canvas.tcl
```

---

### 8. demo-tical-multiselect.tcl
Canvas-Kalender mit Mehrfach-Auswahl (mehrere Tage markieren).
```bash
wish demo-tical-multiselect.tcl
```

---

## 📄 PDF Demos (4)

### 9. demo-pdf.tcl
8 PDF-Variationen (Month/Week/Day, verschiedene Optionen).
```bash
tclsh demo-pdf.tcl
# Erstellt: calendar-*.pdf (8 Dateien)
```

### 10. demo-year-pdf.tcl ⭐ NEU!
Jahreskalender als PDF (A4 Landscape, 12 Monate mit KW).
```bash
tclsh demo-year-pdf.tcl
# Erstellt: calendar-year-2025.pdf
```

### 11. demo-quarter-pdf.tcl ⭐ NEU!
4 Quartalskalender als PDF (je 3 Monate mit KW).
```bash
tclsh demo-quarter-pdf.tcl
# Erstellt: calendar-2025-Q1..Q4.pdf (4 Dateien)
```

### 12. demo-event-calendar-pdf.tcl ⭐ NEU!
Monatskalender mit Termin-Liste und Legende.
```bash
tclsh demo-event-calendar-pdf.tcl
# Erstellt: calendar-events-2025-10.pdf
```

---

## 🖼️ PNG Demos (2) ⭐ NEU!

### 13. demo-year-png.tcl
Jahreskalender als PDF + PNG (3 Auflösungen: 72/144/288 DPI).
```bash
tclsh demo-year-png.tcl
# Erstellt:
#   - calendar-year-2025.pdf
#   - calendar-year-2025-72dpi.png (Screen)
#   - calendar-year-2025-144dpi.png (Web)
#   - calendar-year-2025-288dpi.png (Print)
```

Benötigt: `tclMuPDF` (für PDF → PNG Konvertierung)

### 14. demo-quarter-png.tcl
4 Quartalskalender als PDF + PNG (144 DPI).
```bash
tclsh demo-quarter-png.tcl
# Erstellt:
#   - calendar-2025-Q1.pdf + .png
#   - calendar-2025-Q2.pdf + .png
#   - calendar-2025-Q3.pdf + .png
#   - calendar-2025-Q4.pdf + .png
```

Benötigt: `tclMuPDF`

---

## 📦 Data & Model Demos (2)

### 15. demo-model.tcl
Model-Layer Demo (Appointments + Events CRUD).
```bash
tclsh demo-model.tcl
```

### 16. demo-sqlite.tcl
SQLite Persistence Demo (CRUD Operations).
```bash
tclsh demo-sqlite.tcl
# Erstellt: demo.db
```

---

## 📅 iCalendar Demo (1)

### 17. demo-export-ics.tcl
iCalendar Export Demo (VEVENT, RRULE, EXDATE).
```bash
tclsh demo-export-ics.tcl
# Erstellt: calendar.ics, recurring.ics
```

---

## 🌐 Locale Demo (1)

### 18. demo-locale.tcl
Locale-/Wochentagsnamen-Demo (Sprache & Wochenstart konfigurieren).
```bash
tclsh demo-locale.tcl
```

---

## 📊 Übersicht

| Kategorie | Anzahl | Dependencies |
|-----------|--------|--------------|
| **Terminal** | 4 | Tcl 8.6+ |
| **Canvas GUI** | 4 | Tk 8.6+ |
| **PDF** | 4 | pdf4tcl |
| **PNG** | 2 | pdf4tcl + tclMuPDF |
| **Data** | 2 | TDBC (built-in) |
| **iCalendar** | 1 | - |
| **Locale** | 1 | Tcl 8.6+ |
| **TOTAL** | **18** | |

---

## 🎯 Feature-Matrix

| Demo | KW | Farben | Interaktiv | Export |
|------|----|----|------------|--------|
| month-term | ✅ | ✅ | ❌ | - |
| week-term | ✅ | ✅ | ❌ | - |
| day-term | ✅ | ✅ | ❌ | - |
| year-term ⭐ | ✅ | ❌ | ❌ | - |
| month-canvas | ✅ | ✅ | ✅ | - |
| week-canvas | ✅ | ✅ | ✅ | - |
| day-canvas | ✅ | ✅ | ✅ | - |
| tical-multiselect | ✅ | ✅ | ✅ | - |
| pdf | ✅ | ✅ | ❌ | PDF |
| year-pdf ⭐ | ✅ | ✅ | ❌ | PDF |
| quarter-pdf ⭐ | ✅ | ✅ | ❌ | PDF |
| event-calendar ⭐ | ❌ | ✅ | ❌ | PDF |
| year-png ⭐ | ✅ | ✅ | ❌ | PNG |
| quarter-png ⭐ | ✅ | ✅ | ❌ | PNG |
| model | - | - | - | - |
| sqlite | - | - | - | SQLite |
| export-ics | - | - | - | iCalendar |
| locale | - | - | - | - |

---

## 🚀 Quick Start

```bash
# Alle Terminal-Demos
cd demos
for f in demo-*-term.tcl; do tclsh $f; done

# Alle PDFs generieren
tclsh demo-pdf.tcl
tclsh demo-year-pdf.tcl
tclsh demo-quarter-pdf.tcl

# PNGs (benötigt tclMuPDF)
tclsh demo-year-png.tcl
tclsh demo-quarter-png.tcl
```

---

## 📝 Notizen

- Alle Demos verwenden **Wochennummern (KW)** als Standard
- PNG-Demos benötigen `tclMuPDF` für PDF → PNG Konvertierung
- Canvas-Demos benötigen `wish` (Tk)
- PDF-Demos benötigen `pdf4tcl`
- Engine-Pfad wird automatisch gefunden; per Umgebungsvariable `TICAL_DIR` überschreibbar
- GUI-Demos lassen sich mit `DEMO_NOLOOP=1` headless testen (beenden statt Event-Loop)

---

**tical — 18 Demos zeigen alle Features!** 🎉

