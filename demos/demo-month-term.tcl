#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::config 1.0
package require tical::view::month 1.0
package require tical::render::term 1.0

# Konfiguration
tical::config::set timezone Europe/Berlin

package require tical::holidays::de 1.0

# Termine im Format von tical::event (summary, dtstart, dtend; ISO oder
# iCalendar-Form; ein Datum ohne Uhrzeit ist ganztaegig, dtend exklusiv)
set events {
    {summary "Team Meeting" dtstart 2025-10-14T09:00 dtend 2025-10-14T10:00}
    {summary "Messe" dtstart 2025-10-20 dtend 2025-10-23}
    {summary "Workshop" dtstart 2025-10-03T10:00}
}

# Daten → ViewSpec → Render
set spec [tical::view::month::getData -year 2025 -month 10 -holidays DE -events $events]
puts [tical::render::term::print $spec -color 1 -weekNumbers 1]
puts "Legende: \[ \] heute, ( ) Feiertag, * Tag mit Termin (z. B. (3* = Feiertag mit Termin)"
