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
package require tical::view::day 1.0
package require tical::holidays::de 1.0

tical::config::set timezone Europe/Berlin

puts "=== tical Day View Demo ==="
puts ""

puts "1. Today (Full 24 hours):"
set todayDate [clock format [clock seconds] -format "%Y-%m-%d"]
set spec [tical::view::day::getData -date $todayDate -holidays DE]
puts "   Date: [dict get $spec date]"
puts "   Day: [dict get $spec day].[dict get $spec month].[dict get $spec year]"
puts "   ISO Week: KW [dict get $spec week]"
puts "   Hours: [dict get $spec hours] slots"
puts ""
puts "   First 5 hours:"
foreach cell [lrange [dict get $spec cells] 0 4] {
    set time [dict get $cell time]
    set markers [dict get $cell markers]
    set markerStr ""
    if {"today" in $markers} { set markerStr " *" }
    if {"holiday" in $markers} { set markerStr " [HOLIDAY]" }
    puts "      $time$markerStr"
}
puts "      ..."

puts ""
puts "2. Work Hours Only (8-17):"
set spec [tical::view::day::getData -date $todayDate -hourStart 8 -hourEnd 17]
puts "   Hours: [dict get $spec hours] slots ([dict get $spec hourStart]:00 - [dict get $spec hourEnd]:00)"
puts "   Schedule:"
foreach cell [dict get $spec cells] {
    set time [dict get $cell time]
    puts "      $time"
}

puts ""
puts "3. German Unity Day (Holiday test):"
set spec [tical::view::day::getData -date 2025-10-03 -holidays DE]
set markers [dict get [lindex [dict get $spec cells] 0] markers]
if {"holiday" in $markers} {
    puts "   ✓ Tag der Deutschen Einheit correctly marked as holiday"
} else {
    puts "   ERROR: Holiday not detected!"
}

puts ""
puts "Done!"


