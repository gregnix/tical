#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::core
package require tical::config
package require tical::util
package require tical::holidays
package require tical::holidays::de
package require tical::view::month
package require tical::render::term

puts "\n======================================================"
puts "        JAHRESKALENDER 2025 (Terminal)"
puts "======================================================\n"

tical::config::set weekstart "mon"

set year 2025
set cols 3  ;# 3 Monate pro Zeile
set width 32 ;# Breite eines Monats mit Wochennummern (8 Spalten zu 4 Zeichen)

# Alle 12 Monate generieren und rendern (render::term liefert Monatsname,
# Wochentage und sechs Wochenzeilen; Feiertage aus der View als (3))
set allMonths {}
for {set m 1} {$m <= 12} {incr m} {
    set spec [tical::view::month::getData -year $year -month $m -holidays DE]
    lappend allMonths [split [tical::render::term::print $spec -color 1 -weekNumbers 1] \n]
}

# Ausgabe: 4 Zeilen x 3 Spalten
for {set row 0} {$row < 4} {incr row} {
    set block [lrange $allMonths [expr {$row * $cols}] [expr {$row * $cols + $cols - 1}]]
    for {set line 0} {$line < 8} {incr line} {
        set outputLine ""
        foreach lines $block {
            append outputLine [format "%-*s  " $width [lindex $lines $line]]
        }
        puts [string trimright $outputLine]
    }
    puts ""
}

puts "======================================================"
puts "Legende: \[ \] = heute, ( ) = Feiertag (DE)"
puts "======================================================\n"
