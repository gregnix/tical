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

tical::config::set today "2025-10-14"
tical::config::set weekstart "mon"

set year 2025
set cols 3  ;# 3 Monate pro Zeile

set monthNames {
    "" Januar Februar Maerz April Mai Juni
    Juli August September Oktober November Dezember
}

# Alle 12 Monate generieren
set allMonths {}
for {set m 1} {$m <= 12} {incr m} {
    set spec [tical::view::month::getData -year $year -month $m -holidays {de}]
    lappend allMonths [list $m $spec]
}

# Ausgabe: 4 Zeilen x 3 Spalten
for {set row 0} {$row < 4} {incr row} {
    # Header-Zeile mit Monatsnamen
    set headerLine ""
    for {set col 0} {$col < $cols} {incr col} {
        set idx [expr {$row * $cols + $col}]
        if {$idx < [llength $allMonths]} {
            set monthData [lindex $allMonths $idx]
            set m [lindex $monthData 0]
            set name [lindex $monthNames $m]
            set headerLine "$headerLine [format "%-22s" $name]  "
        }
    }
    puts $headerLine
    
    # Kalender nebeneinander
    set maxLines 9  ;# Maximale Zeilen pro Monat
    
    for {set line 0} {$line < $maxLines} {incr line} {
        set outputLine ""
        
        for {set col 0} {$col < $cols} {incr col} {
            set idx [expr {$row * $cols + $col}]
            if {$idx < [llength $allMonths]} {
                set monthData [lindex $allMonths $idx]
                set spec [lindex $monthData 1]
                
                # Monat rendern
                set rendered [tical::render::term::print $spec -color 0 -weekNumbers 1 -compact 1]
                set lines [split $rendered "\n"]
                
                if {$line < [llength $lines]} {
                    set l [lindex $lines $line]
                    set outputLine "$outputLine [format "%-22s" $l]  "
                } else {
                    set outputLine "$outputLine [format "%-22s" ""]  "
                }
            }
        }
        
        puts $outputLine
    }
    
    puts ""
}

puts "======================================================"
puts "Legende: * = Heute, H = Feiertag"
puts "======================================================\n"

