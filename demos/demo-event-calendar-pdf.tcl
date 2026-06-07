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
package require tical::io::ical
package require tical::locale
package require tical::render::pdf
package require pdf4tcl

# write all generated artifacts into demos/out/ (kept out of the lib release)
set outDir [file join [file dirname [file normalize [info script]]] out]
file mkdir $outDir
cd $outDir

puts "\n=== Event-Kalender PDF Demo ===\n"

tical::config::set today "2025-10-14"

set year 2025
set month 10

# Events/Termine definieren (Datum -> Titel)
set events {
    "2025-10-03" "Tag der Einheit"
    "2025-10-14" "Team Meeting 09:00"
    "2025-10-15" "Projekt Review"
    "2025-10-20" "Deadline Report"
    "2025-10-24" "Workshop TclTk"
    "2025-10-31" "Halloween"
}
set eventDates [dict keys $events]

# ViewSpec + localized month name
set spec [tical::view::month::getData -year $year -month $month -holidays {de}]
set monthName [::tical::locale::getMonthName $month]

# PDF
set pdf [pdf4tcl::new eventPdf -paper a4]
$pdf startPage

set pageW 595
set pageH 842
set margin 30

# Titel
$pdf setFont 20 Helvetica-Bold
$pdf setFillColor #000000
$pdf text "Terminkalender" \
    -x [expr {$pageW / 2.0}] -y [expr {$margin + 20}] -align center

# Kalendergitter ueber den gemeinsamen Renderer-Block zeichnen.
# events -> Termin-Tage werden eingefaerbt (Prioritaet: heute > Termin > Feiertag > Wochenende).
set startY [expr {$margin + 60}]
set calH   350
set blockW [expr {$pageW - 2 * $margin}]

set opts $::tical::render::pdf::defaultOptions
dict set opts weekNumbers 0
dict set opts fontsize 11
dict set opts events $eventDates
dict set opts colorEvent "#E8F5E9"

::tical::render::pdf::_drawMonthBlock $pdf $spec $margin $startY $blockW $calH $opts

# Termin-Liste unten
set listY [expr {$startY + $calH + 40}]

$pdf setFont 14 Helvetica-Bold
$pdf setFillColor #000000
$pdf text "Termine im $monthName $year:" -x $margin -y $listY -align left

$pdf setFont 10 Helvetica
set ly [expr {$listY + 25}]

foreach {date title} $events {
    set d [lindex [split $date "-"] 2]
    set displayDate "[scan $d %d]. $monthName"
    $pdf text "\u2022 $displayDate: $title" -x [expr {$margin + 10}] -y $ly -align left
    set ly [expr {$ly + 15}]
}

# Legende (Farben passend zu defaultOptions + colorEvent)
set legendY [expr {$pageH - 80}]
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "Legende:" -x $margin -y $legendY -align left

set legendItems {
    {"#FFFFCC" "Heute"}
    {"#E8F5E9" "Termin"}
    {"#FFEBEE" "Feiertag"}
    {"#E6F3FF" "Wochenende"}
}

set lx [expr {$margin + 10}]
set ly [expr {$legendY + 15}]

foreach item $legendItems {
    lassign $item color label
    $pdf setFillColor $color
    $pdf rectangle $lx $ly 12 12 -filled 1 -stroke 1
    $pdf setFillColor #000000
    $pdf text $label -x [expr {$lx + 18}] -y [expr {$ly + 9}] -align left
    set lx [expr {$lx + 100}]
}

$pdf endPage
$pdf write -file "calendar-events-2025-10.pdf"
$pdf destroy

puts "Event-Kalender erstellt: calendar-events-2025-10.pdf"
puts ""
