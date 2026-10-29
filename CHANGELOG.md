# Changelog

## 1.1.1

- `tical::event` 1.1.1: key `tzid` (zone of local times): `epochs`, `days`,
  `distribute` and the views convert such times to the display zone;
  `tzid NAME` (new) maps IANA names, prefixed ids
  (`/mozilla.org/.../Europe/Berlin`) and common Windows names to a Tcl zone,
  `""` when unknown (the time then stays local as before); `toLocal` takes
  an optional zone of the value; rrule values checked (`interval`,
  `count` >= 1, `until`, `byday`, `bymonth`, `bymonthday`, `wkst`), error
  `{TICAL EVENT RRULE}` (were accepted and failed later or were exported);
  `expand` (new): series resolved in the core without tclutils (DAILY,
  WEEKLY, MONTHLY, YEARLY, INTERVAL, COUNT, UNTIL, BYDAY with ordinals,
  BYMONTH, BYMONTHDAY, WKST), with EXDATE and overrides; `distribute`
  and so the views show every occurrence of a series (was only the first
  day);
  `dtstart` in UTC and `dtend` local (or the other way round) are
  compared as points in time (`dtend` before `dtstart` was accepted).
- `tical::io::import` 1.1.1: needs only `tclutils::tuical`; `expand` is
  `tical::event::expand` (was `tclutils::turrule`, same occurrences);
  `TZID` is converted (was read as local time);
  series expand in their own zone; DTEND, EXDATE and RECURRENCE-ID in
  another zone are converted to the zone of DTSTART. `UNTIL`, `EXDATE`
  and `RECURRENCE-ID` in UTC end or skip the right occurrence of a local
  series (were compared as wall-clock time). Escaped commas in
  `CATEGORIES` no longer split a category. An override with
  `STATUS:CANCELLED` removes its occurrence (was shown);
  `EXDATE;VALUE=DATE` removes the day of a timed series (was ignored);
  `UID` unescaped, `STATUS` upper case.
- `tical::io::ical` 1.1.1: local times with `tzid` are written with
  `TZID=` (IANA name, no VTIMEZONE), `UNTIL` then in UTC as RFC 5545
  requires; commas and semicolons in categories and `UID` escaped;
  `STATUS` checked (`TENTATIVE`, `CONFIRMED`, `CANCELLED`, error
  `{TICAL ICAL STATUS}`) and written upper case; `recurrence-id` written as
  `RECURRENCE-ID` (a moved occurrence came back as a second event);
  the last line ends with CRLF too; PRODID 1.1.1.
- New `tests/roundtrip.test` with files in `tests/data/roundtrip`: import,
  export, import again, expand series. Alarms, attendees, organizer, X-
  properties and to-dos are not part of the tical model and not exported.
- `tical::config` 1.0.2: keys and values checked (`{TICAL CONFIG KEY}`,
  `{TICAL CONFIG VALUE}`; an unknown locale fell back to English, a
  typo created a new key); key `today` takes effect (was set but not
  read): core and views mark that date; `tical::config::today`.
- `tical::core` 1.1.1: today from `tical::config::today`; `week` of the
  days is a number (was two digits, `01`), as in the week view and the
  schema; month view 1.1.1 likewise.
- `tical::render::canvas` 1.1.1: `setCallback ?w? cmd`: a callback for one
  canvas (wins over the global one, removed with the canvas); a first
  argument that is no widget path is an error `{TICAL RENDER ARGS}`.
  Week numbers still drawn with two digits.
- `tical::render::pdf` 1.1.1: week numbers still drawn with two digits.
- `tical::term` deprecated (placeholder, unused), removed in 1.2.
- `tical::locale` 1.0.2: month 1..12, weekday 1..7 and format `long` /
  `short` checked, errors `{TICAL LOCALE MONTH|DOW|FORMAT}` (returned ""
  or the long names).
- `tical::holidays` 1.0.2: month 1..12 checked, error
  `{TICAL HOLIDAYS MONTH}` (returned an empty dict).
- `tical::util` 1.1.1: `expandSelection` rejects dates that do not exist.
- `tical::model` 1.1.1: unknown options and a missing value are an error
  `{TICAL MODEL OPTION}` in `create…` and `updateAppointment` (were
  ignored); `updateAppointment` sets `status`, `categories`, `allday`;
  option `-tzid` in `create…` and `updateAppointment` (was an unknown
  option); `date`/`startTime` follow the zone.
- `tical::adapter::sqlite` 1.1.1: `tzid` stored in its own column
  (was dropped); `migrate` adds it to tables from 1.1; `listRange` reads
  a local start in its `tzid`. Categories and exdate with commas
  stored escaped (older rows read the same); `listRange db from to ?tz?`
  compares starts as points in time (local and UTC values were compared
  as text) and returns the occurrences of stored series (was the series
  only when it began in the range).
- Views 1.1.1: `-month` outside 1..12, `-week` outside the ISO weeks of
  the year (was moved into the next year), `-year` not four digits, an
  invalid `-date` and `-hourStart` after `-hourEnd` are errors
  `{TICAL VIEW OPTION}` (were `CLOCK …` errors or accepted); `-date` also
  as `YYYYMMDD`; week view key `week` as a number (`08` -> `8`).
- `tical::render::term` 1.1.1: week and day views as lists (were an error
  `{TICAL RENDER TYPE}`); `-weekStart` checked for week views too.
- `tical::holidays::de` 1.0.1: `getHolidays ?-sundays 0|1? year`;
  `-sundays 1` adds Ostersonntag and Pfingstsonntag, the same list as
  `tclutils::tuholiday`; result sorted; errors `{TICAL HOLIDAYS OPTION}`,
  `{TICAL HOLIDAYS YEAR}`.
- `tical` umbrella 1.1.1.
- Removed leftover files `io/tical-io-ical-1.0.1.tm`,
  `render/tical-render-term-1.0.1.tm`, `views/tical-view-month-1.0.1.tm`.
- Demos: `demo-week-term`, `demo-day-term` print with `render::term`.
- `pkgIndex.tcl` loads every file with `source -encoding utf-8`: under
  Tcl 8.6 with another system encoding (cp1252 on Windows) month names,
  holiday names and glyphs were mojibake (`MÃ¤rz`).
- `tical::io::ical` 1.1.1: `exportToFile` builds the text first and
  writes through a temporary file (an invalid event left an empty file
  and an open channel).
- `tests/all.tcl`: test files with `-encoding utf-8`; a missing tical
  package is a failure, only optional packages skip a file.
- Tests: 343 in 17 files (Linux, all optional packages); without
  `tdbc::sqlite3`: 309, also with a Latin-1 system encoding.

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
