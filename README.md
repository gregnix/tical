# tical - Tcl Calendar Library

**Version:** 1.1.1  
**Status:** In Development  
**Requires:** Tcl 8.6+; optional Tk 8.6+ (Canvas GUI), pdf4tcl (PDF), tdbc::sqlite3 (SQLite), tclutils (iCalendar import)

A modular calendar library for Tcl with support for multiple views, rendering targets, events, and iCalendar export and import.

---

## Features

### Implemented 

✅ **Modular Architecture** - Separate data, view, and rendering layers  
✅ **Month View** - 42-cell grid (6 rows × 7 columns) with adjacent days  
✅ **Week View** - 7-day week calendar with ISO week support  
✅ **Day View** - Single day with 24-hour grid (customizable)  
✅ **Terminal Renderer** - ASCII calendar with color support  
✅ **Canvas GUI Renderer** - Interactive graphical calendar with mouse events  
✅ **PDF Renderer** - Print-ready calendars with pdf4tcl (Month/Week/Day)  
✅ **Holidays System** - Pluggable plugins (DE implemented; other regions via `tical::holidays::register`)  
✅ **Model Layer** - Appointment and Event management with CRUD  
✅ **ISO 8601 Week Numbers** - Correct week numbers (KW) in all renderers  
✅ **Timezone Support** - IANA timezone database (Europe/Berlin, etc.)  
✅ **Today Highlighting** - Current day marked in all views  
✅ **Interactive Features** - Hover effects, click events, navigation  
✅ **Events in the views** - `getData ... -events`, one event format (`tical::event`), multi-day and all-day events  
✅ **iCalendar Export** - RFC 5545 compliant (VEVENT, RRULE, EXDATE, all-day `VALUE=DATE`)  
✅ **iCalendar Import** - `tical::io::import` reads .ics and expands RRULE (optional, needs tclutils)  
✅ **SQLite Persistence** - CRUD operations with TDBC (create, read, update, delete)  
✅ **Tested** - 343 tests across 17 files (Linux: Tcl 8.6 and 9.0; without tdbc::sqlite3 309, see below) ✅  
✅ **Demos** - 19 demos (Terminal, Canvas, PDF, PNG, Data, iCal)

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

package require tical::holidays::de

# Events (tical::event format; a date without time is all-day, dtend exclusive)
set events {
    {summary "Team Meeting" dtstart 2025-10-14T09:00 dtend 2025-10-14T10:00}
    {summary Messe dtstart 2025-10-20 dtend 2025-10-23}
}

# Calendar data for October 2025 with holidays and events
set viewSpec [tical::view::month::getData -year 2025 -month 10 \
    -holidays DE -events $events]

# Render to terminal with week numbers
puts [tical::render::term::print $viewSpec -weekNumbers 1]
```

**Output** (default locale `de_DE`):
```
 Oktober 2025
 KW  Mo  Di  Mi  Do  Fr  Sa  So
 40  ..  ..   1   2  (3)  4   5
 41   6   7   8   9  10  11  12
 42  13  14* 15  16  17  18  19
 43  20* 21* 22* 23  24  25  26
 44  27  28  29  30  31  ..  ..
 45  ..  ..  ..  ..  ..  ..  ..
```
Month and weekday names follow `tical::config::set locale` (`de_DE`,
`en_US`, `fr_FR`). Every column is four characters wide. Holidays of the
view (`-holidays DE`) appear as `(3)`, today as `[17]` (only with
`-color 1`; today wins over holiday), days with events as `14*` (`[14*`,
`(3*` when combined). The column order follows the view:
`getData ... -weekStart sun` gives `So Mo ... Sa`.

Week and day views print as lists (since 1.1.1):
```tcl
puts [tical::render::term::print [tical::view::week::getData -date 2025-10-14 -events $events]]
```
```
 KW 42 2025
 Mo 13 Okt
 Di 14 Okt   09:00 Team Meeting
 Mi 15 Okt
 ...
```
Holiday `(Fr 03 Okt)`, today `[Di 14 Okt]` (with `-color 1`); all-day
events without time, `.. summary` where an event continues from an earlier
day. The day view prints one line per hour (`09:00 | 09:15 Call`), all-day
events under the title.

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

# Set callback for day clicks (one argument: a command prefix,
# called as: cmd $canvas $date)
tical::render::canvas::setCallback [list apply {{w date} {
    puts "Clicked: $date"
}}]
# only for this canvas (since 1.1.1; wins over the global callback)
tical::render::canvas::setCallback .c [list apply {{w date} {puts "$w: $date"}}]
```

**Features:**
- Mouse hover effects (blue outline)
- Click events on days
- Today highlighted (yellow background, red text)
- Weekends colored (light blue)
- Week numbers (KW 40-45)
- Adjacent month days (grayed out)

### Events

One event format for views, model, iCalendar and SQLite (`tical::event`):

| Key | Meaning |
|---|---|
| `summary` | title (required) |
| `dtstart` | start (required): `YYYYMMDD` all-day, `YYYYMMDDTHHMMSS` local, `YYYYMMDDTHHMMSSZ` UTC; ISO input (`2025-10-14`, `2025-10-14T09:00`) is accepted |
| `dtend` | end (optional), same kind; all-day: exclusive (day after the last day) |
| `allday` | `0`/`1`, follows `dtstart` |
| `uid`, `description`, `location`, `status`, `categories`, `rrule`, `exdate` | optional |
| `tzid` | optional zone of local times (`Europe/Berlin`, also `/mozilla.org/.../Europe/Berlin` and Windows names such as `W. Europe Standard Time`); converted to the display zone; `tical::model` takes `-tzid`, `tical::adapter::sqlite` stores it |

`tical::event::normalize` converts and checks (errors `{TICAL EVENT ...}`);
for 1.1 it also takes the older names `title`/`date`/`startTime`/`endTime`
(`tical::model`) and `starts_at`/`ends_at` (`tical::adapter::sqlite`).

`getData ... -events LIST` (month, week, day) puts the events into the
`events` of the cells; an event over several days appears in every cell it
touches. A series (`rrule`) appears on every occurrence (since 1.1.1; was
only its first day): `tical::event::expand EVENTS FROM TO ?TZ?` resolves
it in the core, without tclutils (FREQ DAILY/WEEKLY/MONTHLY/YEARLY,
INTERVAL, COUNT, UNTIL, BYDAY with ordinals, BYMONTH, BYMONTHDAY, WKST;
EXDATE and overrides with RECURRENCE-ID honoured). Each entry is the event plus `part` (`single`, `start`, `middle`,
`end`) and `time` (local start `HH:MM` on the start day, else empty).
The day view also has a key `events` for the whole day; its hour cells hold
the timed events. `tical::model::toEvents` and the results of
`tical::adapter::sqlite::listRange` can be passed directly.

### iCalendar Import (optional, needs tclutils)

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tical::io::import

set events [tical::io::import::readFile termine.ics]       ;# tical::event dicts
set oct    [tical::io::import::expand $events 2025-10-01 2025-10-31]
set spec   [tical::view::month::getData -year 2025 -month 10 -events $oct]
```
`expand` (= `tical::event::expand`) resolves RRULE, honours EXDATE and
RECURRENCE-ID and returns the occurrences that touch the range, sorted.
An override with `STATUS:CANCELLED` (one occurrence deleted in Google or
Outlook) removes its occurrence; `EXDATE;VALUE=DATE` removes the whole
day of a timed series.
`DTSTART;VALUE=DATE` gives all-day events. `TZID` is kept as key `tzid`
with the wall-clock time; `tical::event` and the views convert it to the
display zone (`-tz`, `tical::config` timezone), and a series is expanded
in its own zone (18:00 in New York stays 18:00 there across daylight
saving). A TZID Tcl does not know (a custom `VTIMEZONE`) leaves the time as
local time; `tical::event::tzid NAME` returns `""` then. The export writes
`DTSTART;TZID=...` again (no `VTIMEZONE`).

### Quarter View (3 months)

```tcl
# October, November, December: -count N (N > 1) returns a list of N ViewSpecs
package require tical::render::pdf   ;# needs pdf4tcl
set specs [tical::view::month::getData -year 2025 -month 10 -count 3]
tical::render::pdf::createQuarter q4.pdf $specs
```

### Year View (12 months)

```tcl
# Full year calendar (list of 12 ViewSpecs)
set specs [tical::view::month::getData -year 2025 -month 1 -count 12]
tical::render::pdf::createYear 2025.pdf $specs
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
tical::config::set weekstart mon        ;# mon|sun (monday|sunday accepted)
tical::config::set firstweek iso        ;# iso|simple|us
tical::config::set theme dark           ;# default|dark
tical::config::set today 2025-10-14     ;# date marked as today ("" = real date)

# Query settings
set tz [tical::config::get timezone]
```
Keys and values are checked (since 1.0.2): an unknown key is an error
`{TICAL CONFIG KEY}`, a bad value (zone Tcl does not know, locale of
another language than de/en/fr, `weekstart sonntag` ...) an error
`{TICAL CONFIG VALUE}`; the setting keeps its old value.

---

## Modules

### Core ✅ 
- `tical::core` - Calendar calculations (week numbers iso/simple/us, leap years)
- `tical::util` - Helpers (mm2pt, defaults, markers, option checking)
- `tical::event` - Event format: normalize, validate, place on days
- `tical::config` - Global settings (timezone, locale, theme)
- `tical::term` - placeholder, deprecated, removed in 1.2
- `tical::holidays` - Holiday plugin system

### Views ✅ 
- `tical::view::month` - Month grid (6×7 = 42 cells)
- `tical::view::week` - Week grid (1×7 = 7 days)
- `tical::view::day` - Day grid (24 hours, customizable)

### Renderers ✅ 
- `tical::render::term` - plain-text output (month grid, week and day lists)
- `tical::render::canvas` - Tk Canvas GUI (interactive)
- `tical::render::pdf` - PDF (needs pdf4tcl)

### Model, IO ✅ 
- `tical::model` - Appointments and Events (CRUD operations)
- `tical::io::ical` - iCalendar export
- `tical::io::import` - iCalendar import, RRULE expansion (needs tclutils)
- `tical::adapter::sqlite` - SQLite persistence (needs tdbc::sqlite3)

### Holidays ✅ 
- `tical::holidays::de` - German holidays: the nine nationwide ones;
  `getHolidays -sundays 1 YEAR` adds Ostersonntag and Pfingstsonntag (the
  list of `tclutils::tuholiday`). For the views:
  `tical::holidays::register DE {::tical::holidays::de::getHolidays -sundays 1}`



---

## API Examples

### View API (Consistent)

```tcl
# All view::* modules follow this pattern:
proc getData {args} { ... }      # Returns ViewSpec
proc validate {viewSpec} { ... }  # Validates ViewSpec

# Options (unknown options are an error {TICAL VIEW OPTION}):
#   -year INT
#   -month INT (1-12)
#   -tz STRING (IANA timezone)
#   -date YYYY-MM-DD or YYYYMMDD (week, day)
#   -week 1..52/53 (week; ISO weeks of -year)
#   -weekStart mon|sun (month only; week view is always Monday-Sunday)
#   -firstWeek iso|simple|us (month only; iso: ISO 8601, simple: week 1 =
#              January 1-7, us: Sunday weeks, week 1 contains January 1)
#   -count INT (month only; 1 = one ViewSpec, N > 1 = list of N ViewSpecs)
#   -holidays REGION (e.g. DE; case-insensitive)
#   -events LIST (event dicts, see Events)
```

### Render API (Consistent)

```tcl
# Terminal (month-grid, week-grid, day-grid):
tical::render::term::print $viewSpec \
    ?-color 0|1? \
    ?-weekNumbers 0|1? \         ;# month only
    ?-weekStart mon|sun?        ;# check only, must match the view

# Canvas:
tical::render::canvas::draw .canvas $viewSpec \
    ?-interactive 0|1? \
    ?-fontsize INT? \
    ?-weekNumbers 0|1?

# PDF (needs pdf4tcl):
tical::render::pdf::create "file.pdf" $viewSpec \
    ?-paper a4|a3|a5|letter? \
    ?-orientation portrait|landscape? \
    ?-weekNumbers 0|1? ?-showGrid 0|1? ?-fontsize N? ?-margin N? \
    ?-colorToday C? ?-colorHoliday C? ?-colorWeekend C? \
    ?-colorEvent C? ?-colorEventText C?
```

Unknown renderer options are an error `{TICAL RENDER OPTION}`. Events of
the cells: `term` marks the day (`*`), `canvas` draws dots (month) or
titles (week, day), `pdf` titles where there is room, else a dot. The PDF
option `events` (list of dates) of 1.0.1 is still accepted in 1.1.

All renderers take month, weekday and week labels from `tical::locale`
(following `tical::config::set locale`) and the column order from the
cells of the view; the week start is an option of the view, not of the
renderer.

### Errors

Messages are English; every error raised by tical carries an errorcode
`{TICAL <MODULE> <REASON>}`, e.g. `{TICAL VIEW ARGS}`, `{TICAL ICAL FORMAT}`,
`{TICAL RENDER OPTION}`:

```tcl
try {
    tical::view::month::getData -year 2025
} trap {TICAL VIEW} {msg} {
    puts $msg   ;# view::month::getData: -year and -month are required
}
```

---

## Testing

```bash
cd tical/tests
tclsh all.tcl
```

**Test files (17 files, 343 tests):**
- `core.test` (8), `util.test` (11), `locale.test` (20), `holidays.test` (15), `event.test` (35) — engine basics
- `view-day.test` (16), `view-week.test` (18), `view-month.test` (19) — view generation
- `render-term.test` (26), `render-canvas.test` (31), `render-pdf.test` (19) — renderers
- `io-ical.test` (37) — iCalendar export and `validate`
- `io-import.test` (23) — iCalendar import, RRULE expansion
- `model.test` (21), `adapter-sqlite.test` (34) — event model + SQLite (TDBC) persistence
- `roundtrip.test` (7) — sample files: import, export, import again, expand series
- `umbrella.test` (3) — umbrella package load

GUI/PDF/DB/import tests need `Tk` / `pdf4tcl` / `tdbc::sqlite3` / tclutils;
they skip cleanly when those packages are absent (run Tk tests under
`xvfb-run`). tclutils is found via `TCLUTILS_TM` (its `lib/tm`; empty: none)
or a sibling checkout `../tclutils/lib/tm`. Measured on Linux: with all packages 343 passed
(Tcl 9.0.4); without `tdbc::sqlite3` 309 passed (Tcl 8.6.14, also with a
Latin-1 system encoding). Which Tcl version has the SQLite driver depends
on the installation; the counts depend only on the packages found. Windows and macOS: not run
for this version. `tests/all.tcl` starts each file with
`-encoding utf-8`; only a missing optional package (Tk, pdf4tcl, tdbc,
tclutils) skips a file.

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

Developed with the help of AI tools; the code is reviewed and tested by the author.

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
