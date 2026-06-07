#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::io::ical

# write all generated artifacts into demos/out/ (kept out of the lib release)
set outDir [file join [file dirname [file normalize [info script]]] out]
file mkdir $outDir
cd $outDir

puts "=== tical::io::ical Demo ==="
puts ""

puts "Erstelle Events..."

::set events [list \
    [tical::io::ical::makeEvent \
        -dtstart "20251014T090000Z" \
        -dtend "20251014T100000Z" \
        -summary "Team-Standup" \
        -description "Daily standup meeting with the team" \
        -location "Conference Room A"] \
    [tical::io::ical::makeEvent \
        -dtstart "20251015T140000Z" \
        -dtend "20251015T150000Z" \
        -summary "Code Review" \
        -description "Review pull requests from last week" \
        -location "Meeting Room B"] \
    [tical::io::ical::makeEvent \
        -dtstart "20251016T100000Z" \
        -dtend "20251016T110000Z" \
        -summary "Weekly Planning" \
        -description "Sprint planning for next week" \
        -rrule [dict create freq WEEKLY count 4]]]

puts "Anzahl Events: [llength $events]"
puts ""

puts "Exportiere zu calendar.ics..."

::set filename [tical::io::ical::exportToFile $events "calendar.ics"]

puts "Datei erstellt: $filename"
puts ""

puts "Inhalt:"
puts "----------------------------------------"
::set f [open $filename r]
::set content [read $f]
close $f
puts $content
puts "----------------------------------------"
puts ""

puts "Beispiel mit RRULE:"
puts "----------------------------------------"

::set recurring [list \
    [tical::io::ical::makeEvent \
        -dtstart "20251014T090000Z" \
        -dtend "20251014T093000Z" \
        -summary "Daily Standup" \
        -description "Every day for 2 weeks" \
        -rrule [dict create freq DAILY count 10]]]

::set filename2 [tical::io::ical::exportToFile $recurring "recurring.ics"]

::set f [open $filename2 r]
::set content [read $f]
close $f
puts $content
puts "----------------------------------------"
puts ""

puts "=== Demo abgeschlossen ==="
puts "Dateien erstellt:"
puts "  - calendar.ics (3 Events)"
puts "  - recurring.ics (1 Event mit RRULE)"
puts ""
puts "Diese Dateien koennen in Google Calendar, Apple Calendar,"
puts "oder Thunderbird importiert werden!"

