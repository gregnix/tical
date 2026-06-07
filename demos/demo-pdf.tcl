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
package require tical::view::week
package require tical::view::day
package require tical::render::pdf

# write all generated artifacts into demos/out/ (kept out of the lib release)
set outDir [file join [file dirname [file normalize [info script]]] out]
file mkdir $outDir
cd $outDir

puts "\n=== PDF Calendar Demo ===\n"

set today "2025-10-14"
set holidays {"2025-10-03" "2025-12-25" "2025-12-26"}

tical::config::set today $today

puts "1. Month Calendar (October 2025)"
set spec [tical::view::month::getData -year 2025 -month 10 -holidays {de}]
set file1 [tical::render::pdf::create "calendar-month.pdf" $spec \
    -fontsize 10 -weekNumbers 1 -showGrid 1]
puts "   Created: $file1"

puts "\n2. Month Calendar without week numbers"
set spec [tical::view::month::getData -year 2025 -month 10]
set file2 [tical::render::pdf::create "calendar-month-no-weeks.pdf" $spec \
    -weekNumbers 0]
puts "   Created: $file2"

puts "\n3. Month Calendar landscape"
set spec [tical::view::month::getData -year 2025 -month 12 -holidays {de}]
set file3 [tical::render::pdf::create "calendar-month-landscape.pdf" $spec \
    -orientation landscape]
puts "   Created: $file3"

puts "\n4. Week Calendar (Week 42, 2025)"
set spec [tical::view::week::getData -year 2025 -week 42]
set file4 [tical::render::pdf::create "calendar-week.pdf" $spec]
puts "   Created: $file4"

puts "\n5. Day Calendar (2025-10-14)"
set spec [tical::view::day::getData -date $today]
set file5 [tical::render::pdf::create "calendar-day.pdf" $spec]
puts "   Created: $file5"

puts "\n6. Custom colors"
set spec [tical::view::month::getData -year 2025 -month 10 -holidays {de}]
set file6 [tical::render::pdf::create "calendar-colors.pdf" $spec \
    -colorToday "#FFCCCC" \
    -colorHoliday "#CCFFCC" \
    -colorWeekend "#CCCCFF"]
puts "   Created: $file6"

puts "\n7. Letter paper size"
set spec [tical::view::month::getData -year 2025 -month 10]
set file7 [tical::render::pdf::create "calendar-letter.pdf" $spec \
    -paper letter]
puts "   Created: $file7"

puts "\n8. Large font"
set spec [tical::view::month::getData -year 2025 -month 10]
set file8 [tical::render::pdf::create "calendar-large.pdf" $spec \
    -fontsize 14]
puts "   Created: $file8"

puts "\n=== All PDFs created successfully! ===\n"
puts "Files:"
puts "  - calendar-month.pdf"
puts "  - calendar-month-no-weeks.pdf"
puts "  - calendar-month-landscape.pdf"
puts "  - calendar-week.pdf"
puts "  - calendar-day.pdf"
puts "  - calendar-colors.pdf"
puts "  - calendar-letter.pdf"
puts "  - calendar-large.pdf"
puts ""

