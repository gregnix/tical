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

# Daten → ViewSpec → Render
set spec [tical::view::month::getData -year 2025 -month 10]
puts [tical::render::term::print $spec -color 1 -weekNumbers 1]
