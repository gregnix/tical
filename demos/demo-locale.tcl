#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::config
package require tical::locale

puts "\n=== tical Locale Demo ===\n"

# Deutsch
puts "=== Deutsch (de_DE) ==="
tical::config::set locale de_DE

puts "Monate (lang):"
for {set m 1} {$m <= 12} {incr m} {
    puts "  $m: [tical::locale::getMonthName $m]"
}

puts "\nMonate (kurz):"
puts "  [tical::locale::getMonthNames short]"

puts "\nWochentage (lang):"
for {set dow 1} {$dow <= 7} {incr dow} {
    puts "  $dow: [tical::locale::getWeekdayName $dow]"
}

puts "\nWochentage (kurz):"
puts "  [tical::locale::getWeekdaysShort]"

puts ""

# English
puts "=== English (en_US) ==="
tical::config::set locale en_US

puts "Months (long):"
puts "  [tical::locale::getMonthNames long]"

puts "\nWeekdays (short):"
puts "  [tical::locale::getWeekdaysShort]"

puts ""

# Français
puts "=== Français (fr_FR) ==="
tical::config::set locale fr_FR

puts "Mois (long):"
for {set m 1} {$m <= 12} {incr m} {
    puts "  $m: [tical::locale::getMonthName $m]"
}

puts "\nJours (court):"
puts "  [tical::locale::getWeekdaysShort]"

puts ""

# Supported Locales
puts "=== Supported ==="
puts "Locales: [tical::locale::getSupportedLocales]"
puts "Languages: [tical::locale::getSupportedLanguages]"

puts "\n=== Ende ===\n"

