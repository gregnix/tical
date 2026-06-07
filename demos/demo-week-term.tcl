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
package require tical::view::week 1.0
package require tical::holidays::de 1.0

tical::config::set timezone Europe/Berlin

puts "=== tical Week View Demo ==="
puts ""

puts "1. Current Week (by date):"
set spec [tical::view::week::getData -date 2025-10-14 -holidays DE]
puts "   Year: [dict get $spec year]"
puts "   Week: KW [dict get $spec week]"
puts "   Days:"
foreach cell [dict get $spec cells] {
    set date [dict get $cell date]
    set dow [dict get $cell dow]
    set markers [dict get $cell markers]
    set markerStr ""
    if {"today" in $markers} {
        set markerStr " *TODAY*"
    }
    if {"holiday" in $markers} {
        set markerStr " [HOLIDAY]"
    }
    set dowNames {- Mo Tu We Th Fr Sa Su}
    set dowName [lindex $dowNames $dow]
    puts "      $dowName $date$markerStr"
}

puts ""
puts "2. Week 42 of 2025:"
set spec [tical::view::week::getData -year 2025 -week 42 -holidays DE]
puts "   Dates:"
foreach cell [dict get $spec cells] {
    set date [dict get $cell date]
    set dow [dict get $cell dow]
    set dowNames {- Mo Tu We Th Fr Sa Su}
    puts "      [lindex $dowNames $dow] $date"
}

puts ""
puts "3. Week 1 of 2025 (year boundary test):"
set spec [tical::view::week::getData -year 2025 -week 1]
puts "   Note: ISO Week 1 can start in previous year!"
foreach cell [dict get $spec cells] {
    set date [dict get $cell date]
    set dow [dict get $cell dow]
    set dowNames {- Mo Tu We Th Fr Sa Su}
    puts "      [lindex $dowNames $dow] $date"
}

puts ""
puts "Done!"


