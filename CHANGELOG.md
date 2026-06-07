# Changelog

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
- iCalendar I/O: `tical::io::ical` (export, and the import/parse path documented
  in `doc/ICALENDAR-API.md` / `doc/ICALENDAR-SUPPORT.md`).
- Model and persistence: `tical::model`; optional `tical::adapter::sqlite`
  (requires `tdbc::sqlite3`).
- Core layer: `tical::core`, `tical::util`, `tical::config`, `tical::locale`,
  `tical::term`, plus the `tical` umbrella package (engine without the optional
  Tk/PDF/SQLite dependencies).
- Locale/timezone aware via the Tcl `clock` command; ISO week numbering.
- Test suite: 88 tests across 14 files, dependency-tolerant runner
  (`tests/all.tcl`); green on Tcl 8.6 and 9.x (canvas/PDF/SQLite files skip
  when their optional package is absent).

### Notes

- Optional dependencies and the packages that need them: `pdf4tcl`
  (`tical::render::pdf`), `tdbc::sqlite3` (`tical::adapter::sqlite`), Tk
  (`tical::render::canvas`). The `tical` umbrella loads without any of them.
