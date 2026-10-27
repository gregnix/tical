#!/usr/bin/env tclsh
# Termine aus einer iCalendar-Datei lesen, Wiederholungen fuer Oktober 2025
# aufloesen und im Monatskalender zeigen (Terminal, mit pdf4tcl auch PDF).
# Braucht tclutils (tuical, turrule) fuer tical::io::import.

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
# tclutils: TCLUTILS_TM (its lib/tm) or a sibling checkout ../tclutils/lib/tm
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} elseif {[file isdirectory [file join $here .. .. tclutils lib tm]]} {
    tcl::tm::path add [file normalize [file join $here .. .. tclutils lib tm]]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::config 1.0
package require tical::holidays::de 1.0
package require tical::view::month 1.1
package require tical::render::term 1.1
if {[catch {package require tical::io::import 1.1} err]} {
    puts "tical::io::import braucht tclutils (tuical, turrule): $err"
    puts "TCLUTILS_TM auf das Verzeichnis tclutils/lib/tm setzen."
    exit 0
}

tical::config::set timezone Europe/Berlin

# 1. Datei lesen: Liste von Terminen im Format von tical::event
set events [tical::io::import::readFile [file join $here data termine.ics]]
puts "Gelesen: [llength $events] VEVENTs\n"

# 2. Wiederholungen fuer den Monat aufloesen (EXDATE, RECURRENCE-ID beachtet)
set oct [tical::io::import::expand $events 2025-10-01 2025-10-31]

# 3. In die View, ausgeben
set spec [tical::view::month::getData -year 2025 -month 10 -holidays DE -events $oct]
puts [tical::render::term::print $spec -weekNumbers 1]
puts "Legende: ( ) Feiertag, * Tag mit Termin\n"

foreach ev $oct {
    lassign [tical::event::toLocal [dict get $ev dtstart]] date time
    set what [dict get $ev summary]
    if {[dict get $ev allday] && [dict exists $ev dtend]} {
        set last [lindex [tical::event::days $ev] end]
        if {$last ne $date} { append what " (bis $last)" }
    }
    puts [format "  %s %-5s %s" $date $time $what]
}

# 4. Optional: PDF mit den Titeln in den Tageszellen
if {![catch {package require tical::render::pdf 1.1}]} {
    set outDir [file join $here out]
    file mkdir $outDir
    set f [tical::render::pdf::create [file join $outDir termine-2025-10.pdf] $spec \
        -orientation landscape]
    puts "\nPDF: [file tail $f]"
}
