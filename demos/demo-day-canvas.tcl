#!/usr/bin/env wish

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}

package require tical::config 1.0
package require tical::view::day 1.0
package require tical::render::canvas 1.0
package require tical::holidays::de 1.0

tical::config::set timezone Europe/Berlin

set currentDate [clock format [clock seconds] -format "%Y-%m-%d"]

proc renderCalendar {} {
    global currentDate
    
    set spec [tical::view::day::getData -date $currentDate -holidays DE -hourStart 6 -hourEnd 22]
    tical::render::canvas::draw .c $spec -interactive 0 -fontsize 14
    
    wm title . "tical Day Calendar - $currentDate"
}

proc prevDay {} {
    global currentDate
    set ts [clock scan $currentDate -format "%Y-%m-%d"]
    set ts [clock add $ts -1 days]
    set currentDate [clock format $ts -format "%Y-%m-%d"]
    renderCalendar
}

proc nextDay {} {
    global currentDate
    set ts [clock scan $currentDate -format "%Y-%m-%d"]
    set ts [clock add $ts 1 days]
    set currentDate [clock format $ts -format "%Y-%m-%d"]
    renderCalendar
}

proc today {} {
    global currentDate
    set currentDate [clock format [clock seconds] -format "%Y-%m-%d"]
    renderCalendar
}

wm title . "tical Day Calendar Demo"
wm geometry . 350x550

frame .toolbar
pack .toolbar -side top -fill x -pady 5

button .toolbar.prev -text "<< Prev Day" -command prevDay
button .toolbar.today -text "Today" -command today
button .toolbar.next -text "Next Day >>" -command nextDay

pack .toolbar.prev -side left -padx 5
pack .toolbar.today -side left -padx 5
pack .toolbar.next -side left -padx 5

label .toolbar.info -text "Hours: 06:00 - 22:00" -fg gray
pack .toolbar.info -side left -padx 10

canvas .c -width 330 -height 500 -bg white -highlightthickness 0 -yscrollcommand ".sb set"
scrollbar .sb -command ".c yview"

pack .sb -side right -fill y
pack .c -side left -fill both -expand 1 -padx 5 -pady 5

renderCalendar


# headless self-test: skip the Tk event loop when DEMO_NOLOOP is set
if {[info exists ::env(DEMO_NOLOOP)]} { update idletasks; exit 0 }
