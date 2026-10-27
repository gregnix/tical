# Changelog

## 1.1

- `tical::event` 1.1 (new): one event format for views, model, iCalendar
  and SQLite (`summary`, `dtstart`, `dtend`, `allday`, optional `uid`,
  `description`, `location`, `status`, `categories`, `rrule`, `exdate`);
  `normalize`, `validate`, `normalizeValue`, `toLocal`, `epochs`, `days`,
  `distribute`, `rrule`, `rruleString`. Accepts ISO input (`2025-10-14`,
  `2025-10-14T09:00`). Errors `{TICAL EVENT FIELD|FORMAT|RANGE|RRULE|ARGS}`.
- Views 1.1 (`month`, `week`, `day`): `-events LIST` fills the `events` of
  the cells (multi-day events in every touched cell; entry keys `part`
  `single|start|middle|end` and `time`); day view: key `events` for the
  whole day, hour cells hold the timed events. Unknown options and a
  missing value are an error `{TICAL VIEW OPTION}` (were ignored).
  `-weekStart` checked (`mon`, `sun`, also `monday`, `sunday`).
- `tical::view::month` 1.1: `-firstWeek iso|simple|us` takes effect (was
  accepted but ignored); keys `weekStart`, `firstWeek` in the ViewSpec.
- `tical::core` 1.1: `weekNumber`; `calendarData -firstWeek` takes effect.
- `tical::render::term` 1.1: columns four characters wide; today `[17]`
  (with `-color 1`), holiday `(18)`, today wins; days with events `17*`
  (`[17*`, `(18*` combined); was `+18`, `*17`. `-weekStart` accepted again
  as a check only: matching the view no effect, else error
  `{TICAL RENDER WEEKSTART}`.
- `tical::render::canvas` 1.1: events as dots (month), titles (week,
  day; tag `event`); options checked `{TICAL RENDER OPTION}`.
- `tical::render::pdf` 1.1: event titles from the cells (dot where there is
  no room); options checked `{TICAL RENDER OPTION}`, `paper` in any case
  (`Letter` was silently A4), `orientation` checked; option `events`
  (list of dates) still accepted, deprecated, removed in 1.2; month title
  black in quarter/year layouts.
- Week numbers of a row: week of the middle cell (`tical::util::rowWeek`);
  changes the label of Sunday grids with ISO weeks (was the Sunday's week).
- `tical::util` 1.1: `options`, `weekStartDow`, `rowWeek`.
- `tical::io::ical` 1.1: all-day events written as `DTSTART;VALUE=DATE`
  (DTEND exclusive, EXDATE likewise); `validate` accepts `YYYYMMDD`,
  checks date/date-time mix and order (`{TICAL ICAL RANGE}`);
  `exportEvents` normalizes each event (older field names, ISO dates,
  missing UID generated); RRULE `bymonth`, `bymonthday`; PRODID 1.1.
- `tical::io::import` 1.1 (new, optional, needs `tclutils::tuical` and
  `tclutils::turrule`): `parse`, `readFile`, `expand`, `eventsInRange`;
  VALUE=DATE, DURATION, EXDATE, RECURRENCE-ID; errors `{TICAL IMPORT ...}`.
- `tical::model` 1.1: records in the event format; options `-summary`,
  `-dtstart`, `-dtend`, `-allday`, `-categories`; `toEvents`. Deprecated,
  accepted in 1.1, removed in 1.2: options `-title`, `-date`, `-startTime`,
  `-endTime`, `-allDay`, `-category` and the record fields of the same
  names. Values are validated (`{TICAL EVENT ...}`).
- `tical::adapter::sqlite` 1.1: `create`/`update` take `dtstart`/`dtend`;
  `read`/`listRange`/`listAll` return `dtstart`, `dtend`, `allday`.
  Deprecated, accepted in 1.1, removed in 1.2: `starts_at`/`ends_at` (also
  still returned). `listRange` takes ISO bounds; a date as end bound
  includes that day. Table unchanged.
- `tical` umbrella 1.1 (loads `tical::event`).
- Demos: `demo-events-import.tcl` and `data/termine.ics` (new);
  `demo-month-term`, `demo-year-term` (markers, legend), `demo-model`,
  `demo-sqlite`, `demo-event-calendar-pdf` use the event format.
- Tests: 270 (Tcl 9.0, all optional packages); Tcl 8.6 without
  `tdbc::sqlite3`: 242.

## 1.0.1

- `tical::view::month` 1.0.1: `-count N` (N > 1) returns a list of N
  consecutive month ViewSpecs; `-count 1` unchanged; `-count` < 1 is an error.
- `tical::holidays` 1.0.1: region keys case-insensitive (`de` = `DE`).
- `tical::render::term` 1.0.1: month and weekday names from `tical::locale`
  (follows `tical::config` locale, default `de_DE`); holidays marked `+`,
  today `*` (with `-color 1`, was never shown); column order from the view
  cells; option `-weekStart` removed (turned only the header), unknown
  options are an error.
- `tical::render::canvas` 1.0.1: month, weekday and week labels from
  `tical::locale`; column order from the view cells; no error on empty
  cells (`-showAdjacentDays 0`).
- `tical::render::pdf` 1.0.1: week labels from `tical::locale`; column order
  from the view cells.
- `tical::locale` 1.0.1: `getWeekdaysShort`/`getWeekdaysLong`/
  `getWeekdayNames` take an optional start day; `getWeekLabel`.
- `tical::util` 1.0.1: `gridStartDow`.
- `tical::view::week` 1.0.1: `-date` uses the ISO year (2024-12-30 is week 1
  of 2025); holidays of all months in the week, also across the year end;
  dates computed in `-tz`.
- Error messages English with errorcode `{TICAL <MODULE> <REASON>}`:
  `core`, `config`, `util`, `locale`, views, renderers, `model`, `io::ical`,
  `adapter::sqlite` (all 1.0.1).
- `tical::io::ical` 1.0.1: `exportToFile` writes CRLF instead of CR CR LF;
  PRODID `-//tical//tical 1.0//EN`; `validate` names the allowed time
  formats and checks `rrule`; lines folded after 75 octets (UTF-8), not
  75 characters.
- `tical` umbrella 1.0.1.
- README: `setCallback` example (one command prefix), real `render::term`
  output, `-count`, test counts.
- `doc/ICALENDAR-SUPPORT.md`: version 1.0, supported properties match the code
  (EXDATE, BYDAY, WKST, YEARLY), usage via `makeEvent`/`exportToFile`.
- `demos/README.md`: 18 demos, version.
- `demos/demo-year-term.tcl`: month name once, holidays marked, no unknown
  option.
- README: errors, renderer labels, holiday regions; `doc/ICALENDAR-API.md`: `validate`.
- Tests: 176 (Tcl 9.0, all optional packages); Tcl 8.6 without
  `tdbc::sqlite3`: 153.

## 1.0

Initial public release.

- Modular calendar/iCalendar engine for Tcl. Tk-free core; the Tk canvas and
  PDF renderers and the SQLite adapter are optional add-ons. Runs on Tcl 8.6
  and Tcl 9.x.
- Views: `tical::view::month`, `tical::view::week`, `tical::view::day` produce
  a render-agnostic view spec (CalendarData / ViewSpec, see `schemas/`).
- Renderers: `tical::render::term` (ASCII/terminal), `tical::render::canvas`
  (interactive Tk canvas: week numbers, today/weekend/holiday states, single
  and multiple day selection), `tical::render::pdf` (optional, requires
  `pdf4tcl`).
- Holidays: `tical::holidays` with a pluggable region backend; `tical::holidays::de`
  ships German federal/state holidays.
- iCalendar export: `tical::io::ical` (`exportEvents`, `exportToFile`,
  `makeEvent`, `validate`; no import/parser), see `doc/ICALENDAR-API.md` /
  `doc/ICALENDAR-SUPPORT.md`.
- Model and persistence: `tical::model`; optional `tical::adapter::sqlite`
  (requires `tdbc::sqlite3`).
- Core layer: `tical::core`, `tical::util`, `tical::config`, `tical::locale`,
  `tical::term`, plus the `tical` umbrella package (engine without the optional
  Tk/PDF/SQLite dependencies).
- Locale/timezone aware via the Tcl `clock` command; ISO week numbering.
- Test suite: 122 tests across 14 files, dependency-tolerant runner
  (`tests/all.tcl`); green on Tcl 8.6 and 9.x (canvas/PDF/SQLite files skip
  when their optional package is absent; Tcl 8.6 without `tdbc::sqlite3`:
  100).

### Notes

- Optional dependencies and the packages that need them: `pdf4tcl`
  (`tical::render::pdf`), `tdbc::sqlite3` (`tical::adapter::sqlite`), Tk
  (`tical::render::canvas`). The `tical` umbrella loads without any of them.
