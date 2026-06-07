#!/usr/bin/env tclsh
# demo-quarter-pdf.tcl -- four quarterly calendars (3 months each) as PDFs.
# Thin demo: layout, grid, borders and localized names live in
# tical::render::pdf::createQuarter now.

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
for {set q 1} {$q <= 4} {incr q} {
    set specs {}
    for {set i 0} {$i < 3} {incr i} {
        set m [expr {($q - 1) * 3 + $i + 1}]
        lappend specs [tical::view::month::getData -year $year -month $m -holidays {de}]
    }
    set out [file join $outDir "calendar-$year-Q$q.pdf"]
    tical::render::pdf::createQuarter $out $specs -orientation landscape -weekNumbers 1
    puts "Quartalskalender Q$q erstellt: $out"
}
