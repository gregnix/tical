#!/usr/bin/env tclsh
# demo-year-pdf.tcl -- full-year calendar (12 mini months) as one PDF page.
# Thin demo: the layout, grid, borders and localized names all live in
# tical::render::pdf::createYear now.

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::config
package require tical::holidays
package require tical::holidays::de
package require tical::view::month
package require tical::render::pdf
package require pdf4tcl

set outDir [file join $here out]
file mkdir $outDir

set year 2025
set specs {}
for {set m 1} {$m <= 12} {incr m} {
    lappend specs [tical::view::month::getData -year $year -month $m -holidays {de}]
}

set out [file join $outDir "calendar-year-$year.pdf"]
tical::render::pdf::createYear $out $specs -orientation landscape -weekNumbers 1
puts "Jahreskalender erstellt: $out"
