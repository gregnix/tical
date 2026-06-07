#!/usr/bin/env wish

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}

package require tical::config 1.0
package require tical::view::week 1.0
package require tical::render::canvas 1.0
package require tical::holidays::de 1.0

tical::config::set timezone Europe/Berlin

scan [clock format [clock seconds] -format "%Y %V"] "%d %d" currentYear currentWeek

proc renderCalendar {} {
    global currentYear currentWeek
    
    set spec [tical::view::week::getData -year $currentYear -week $currentWeek -holidays DE]
    tical::render::canvas::draw .c $spec -interactive 1 -fontsize 16
    
    wm title . "tical Week Calendar - KW $currentWeek, $currentYear"
}

proc onDayClick {w date} {
    puts "Clicked on: $date"
    tk_messageBox -message "Selected Date:\n$date" -title "Day Selected"
}

proc prevWeek {} {
    global currentYear currentWeek
    incr currentWeek -1
    if {$currentWeek < 1} {
        set currentWeek 52
        incr currentYear -1
    }
    renderCalendar
}

proc nextWeek {} {
    global currentYear currentWeek
    incr currentWeek
    if {$currentWeek > 52} {
        set currentWeek 1
        incr currentYear
    }
    renderCalendar
}

proc today {} {
    global currentYear currentWeek
    scan [clock format [clock seconds] -format "%Y %V"] "%d %d" currentYear currentWeek
    renderCalendar
}

wm title . "tical Week Calendar Demo"
wm geometry . 600x250

frame .toolbar
pack .toolbar -side top -fill x -pady 5

button .toolbar.prev -text "<< Prev Week" -command prevWeek
button .toolbar.today -text "This Week" -command today
button .toolbar.next -text "Next Week >>" -command nextWeek

pack .toolbar.prev -side left -padx 5
pack .toolbar.today -side left -padx 5
pack .toolbar.next -side left -padx 5

canvas .c -width 580 -height 180 -bg white -highlightthickness 0
pack .c -fill both -expand 1 -padx 5 -pady 5

tical::render::canvas::setCallback onDayClick

renderCalendar


# headless self-test: skip the Tk event loop when DEMO_NOLOOP is set
if {[info exists ::env(DEMO_NOLOOP)]} { update idletasks; exit 0 }
