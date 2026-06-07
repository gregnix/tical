# tical - Tcl Calendar Library

**Version:** 1.0  
**Status:** Stable  
**Requires:** Tcl 8.6+, Tk 8.6+ (for Canvas GUI), pdf4tcl (for PDF)

A modular calendar library for Tcl with support for multiple views, rendering targets, and iCalendar export.

---

## Features

### Implemented (Phase 1 + 2 + 3 + 4)

✅ **Modular Architecture** - Separate data, view, and rendering layers  
✅ **Month View** - 42-cell grid (6 rows × 7 columns) with adjacent days  
✅ **Week View** - 7-day week calendar with ISO week support  
✅ **Day View** - Single day with 24-hour grid (customizable)  
✅ **Terminal Renderer** - ASCII calendar with color support  
✅ **Canvas GUI Renderer** - Interactive graphical calendar with mouse events  
✅ **PDF Renderer** - Print-ready calendars with pdf4tcl (Month/Week/Day)  
✅ **Holidays System** - Pluggable plugins (DE implemented, AT/CH ready)  
✅ **Model Layer** - Appointment and Event management with CRUD  
✅ **ISO 8601 Week Numbers** - Correct week numbers (KW) in all renderers  
✅ **Timezone Support** - IANA timezone database (Europe/Berlin, etc.)  
✅ **Today Highlighting** - Current day marked in all views  
✅ **Interactive Features** - Hover effects, click events, navigation  
✅ **iCalendar Export** - RFC 5545 compliant (VEVENT, RRULE, EXDATE)  
✅ **SQLite Persistence** - CRUD operations with TDBC (create, read, update, delete)  
✅ **Tested** - 86 unit tests, 86 passing (100%) ✅  
✅ **Demos** - 16 demos (Terminal, Canvas, PDF, PNG, Data, iCal)

---

## Quick Start

### Installation

```bash
# Clone or download
git clone https://github.com/yourname/tical.git
cd tical

# Add to TCLLIBPATH
export TCLLIBPATH="/path/to/tical $TCLLIBPATH"
```

### Basic Usage (Terminal)

```tcl
#!/usr/bin/env tclsh
package require tical::view::month
package require tical::render::term

# Get calendar data for October 2025
set viewSpec [tical::view::month::getData -year 2025 -month 10]

# Render to terminal with week numbers
puts [tical::render::term::print $viewSpec -color 1 -weekNumbers 1]
```

**Output:**
```
 October 2025 
 KW Mo Tu We Th Fr Sa Su
 40 .. ..  1  2  3  4  5
 41  6  7  8  9 10 11 12
 42 13 14 15 16 17 18 19
 43 20 21 22 23 24 25 26
 44 27 28 29 30 31 .. ..
```
(*Today is marked with * in actual output)

### Canvas GUI (Interactive)

```tcl
#!/usr/bin/env wish
package require tical::view::month
package require tical::render::canvas

# Create canvas
canvas .c -width 400 -height 350 -bg white
pack .c -fill both -expand 1

# Render month with interaction and week numbers
set viewSpec [tical::view::month::getData -year 2025 -month 10]
tical::render::canvas::draw .c $viewSpec \
    -interactive 1 \
    -fontsize 12 \
    -weekNumbers 1

# Set callback for day clicks
tical::render::canvas::setCallback {w date} {
    puts "Clicked: $date"
}
```

**Features:**
- Mouse hover effects (blue outline)
- Click events on days
- Today highlighted (yellow background, red text)
- Weekends colored (light blue)
- Week numbers (KW 40-45)
- Adjacent month days (grayed out)

### Quarter View (3 months)

```tcl
# October, November, December
set specs [tical::view::month::getData -year 2025 -month 10 -count 3]
```

### Year View (12 months)

```tcl
# Full year calendar
set specs [tical::view::month::getData -year 2025 -month 1 -count 12]
```

---

## Architecture

```
CalendarData (tical::core)
    ↓
ViewSpec (tical::view::*)
    ↓
Rendering (tical::render::*)
```

### Data Flow

1. **tical::core** - Generates raw calendar data (dates, weeks, etc.)
2. **tical::view::*** - Transforms data into view-specific format (ViewSpec)
3. **tical::render::*** - Renders ViewSpec to target (terminal, canvas, PDF)

### Key Principle

> One ViewSpec = One Grid (e.g., 42 cells for a month)

Multiple months = List of ViewSpecs

---

## Configuration

```tcl
package require tical::config

# Set defaults
tical::config::set timezone :Europe/Berlin
tical::config::set locale de_DE
tical::config::set weekstart monday
tical::config::set theme dark

# Query settings
set tz [tical::config::get timezone]
```

---

## Modules

### Core ✅ (Phase 1)
- `tical::core` - Calendar calculations (ISO weeks, leap years)
- `tical::util` - Helpers (mm2pt, defaults, markers)
- `tical::config` - Global settings (timezone, locale, theme)
- `tical::term` - VT100 terminal styling
- `tical::holidays` - Holiday plugin system

### Views ✅ (Phase 1 + 3)
- `tical::view::month` - Month grid (6×7 = 42 cells)
- `tical::view::week` - Week grid (1×7 = 7 days)
- `tical::view::day` - Day grid (24 hours, customizable)

### Renderers ✅ (Phase 1 + 2)
- `tical::render::term` - ASCII/Unicode terminal output
- `tical::render::canvas` - Tk Canvas GUI (interactive)

### Model ✅ (Phase 3)
- `tical::model` - Appointments and Events (CRUD operations)

### Holidays ✅ (Phase 3)
- `tical::holidays::de` - German holidays (9+ holidays, Easter calculation)

### Planned (Phase 4)
- `tical::holidays::at` - Austrian holidays
- `tical::holidays::ch` - Swiss holidays
- `tical::adapter::sqlite` - Database persistence (TDBC)
- `tical::io::ical` - iCalendar import/export (RFC 5545)
- `tical::render::pdf` - PDF output (pdf4tcl)

---

## API Examples

### View API (Consistent)

```tcl
# All view::* modules follow this pattern:
proc getData {args} { ... }      # Returns ViewSpec
proc validate {viewSpec} { ... }  # Validates ViewSpec

# Options:
#   -year INT
#   -month INT (1-12)
#   -tz STRING (IANA timezone)
#   -weekStart mon|sun
#   -count INT (for multi-month)
```

### Render API (Consistent)

```tcl
# Terminal:
tical::render::term::print $viewSpec \
    ?-color 0|1? \
    ?-weekNumbers 0|1?

# Canvas (Phase 2):
tical::render::canvas::draw .canvas $viewSpec \
    ?-interactive 0|1? \
    ?-fontsize INT? \
    ?-weekNumbers 0|1?

# PDF (Phase 4):
tical::render::pdf::create "file.pdf" $viewSpec \
    ?-paper A4|Letter? \
    ?-weekNumbers 0|1?
```

---

## Testing

```bash
cd tical/tests
tclsh all.tcl
```

**Current tests (5 tests, all passing):**
- `core.test` - Calendar calculations (2 tests)
- `view-month.test` - Month view generation (no tests yet)
- `render-term.test` - Terminal rendering (no tests yet)
- `render-canvas.test` - Canvas GUI rendering (3 tests)

**Test Coverage:**
- ✅ ISO week number calculation
- ✅ Leap year detection
- ✅ Canvas smoke tests (no crash)
- ✅ Interactive mode
- ✅ Week numbers display

---

## Demos

### 1. Month View (Terminal) ✅
```bash
cd tical
tclsh demos/demo-month-term.tcl
```
Shows October 2025 with week numbers in terminal.

### 2. Month View (Canvas GUI) ✅
```bash
cd tical
wish demos/demo-month-canvas.tcl
```
Interactive calendar with:
- Navigation buttons (Prev/Today/Next)
- Mouse hover effects
- Click events on days
- Week numbers (KW 40-45)
- Today highlighting
- Holiday markers (German holidays)

### 3. Week View (Terminal) ✅
```bash
cd tical
tclsh demos/demo-week-term.tcl
```
Shows:
- Current week (KW 42)
- ISO Week 1 (year boundary test)
- Holiday detection

### 4. Day View (Terminal) ✅
```bash
cd tical
tclsh demos/demo-day-term.tcl
```
Shows:
- Full day (24 hours)
- Work hours only (8:00-17:00)
- Holiday marker test

### 5. Model (CRUD Operations) ✅
```bash
cd tical
tclsh demos/demo-model.tcl
```
Demonstrates:
- Create appointments and events
- Read, Update, Delete operations
- Query by date
- List all items

### 6. PDF Calendar (Phase 4)
```bash
cd tical
tclsh demos/demo-year-pdf.tcl
```
(Planned)

---

## Data Schemas

See `schemas/` for detailed documentation:

- **CalendarData** - Raw data from tical::core
- **ViewSpec** - View-specific data structure

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the release history.

---

## Contributing

Contributions welcome! Please:
1. Follow existing code style
2. Add tests for new features
3. Update documentation

---

## License

MIT License - see [LICENSE](LICENSE). Copyright (c) 2026 Gregor Ebbing.

---

## Contact

Issues and pull requests: https://github.com/gregnix/tical

---

## See Also

- [iCalendar API](doc/ICALENDAR-API.md)
- [Schema Documentation](schemas/)
- [Changelog](CHANGELOG.md)
