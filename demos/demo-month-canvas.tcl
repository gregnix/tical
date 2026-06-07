#!/usr/bin/env wish

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}

package require tical::config 1.0
package require tical::view::month 1.0
package require tical::render::canvas 1.0
package require tical::holidays::de 1.0

tical::config::set timezone Europe/Berlin

set currentYear 2025
set currentMonth 10

proc renderCalendar {} {
    global currentYear currentMonth
    set spec [tical::view::month::getData -year $currentYear -month $currentMonth -holidays DE]
    tical::render::canvas::draw .c $spec -interactive 1 -fontsize 12 -weekNumbers 1
    # multi-day selection: click toggles, Shift-click selects a range
    tical::render::canvas::setSelectMode .c multiple
    tical::render::canvas::setSelectionCommand .c showSelection
    wm title . "tical Calendar - [clock format [clock scan "$currentYear-$currentMonth-01"] -format "%B %Y"]"
}

proc showSelection {w sel} {
    if {[llength $sel] == 0} {
        .status configure -text "No days selected"
    } else {
        .status configure -text "[llength $sel] selected: [join $sel { }]"
    }
}

proc prevMonth {} { global currentYear currentMonth
    incr currentMonth -1
    if {$currentMonth < 1} { set currentMonth 12; incr currentYear -1 }
    renderCalendar
}
proc nextMonth {} { global currentYear currentMonth
    incr currentMonth
    if {$currentMonth > 12} { set currentMonth 1; incr currentYear }
    renderCalendar
}
proc today {} { global currentYear currentMonth
    scan [clock format [clock seconds] -format "%Y %m"] "%d %d" currentYear currentMonth
    renderCalendar
}

wm title . "tical Calendar Demo"
wm geometry . 420x380

frame .toolbar
pack .toolbar -side top -fill x -pady 5
button .toolbar.prev  -text "<< Prev" -command prevMonth
button .toolbar.today -text "Today"   -command today
button .toolbar.next  -text "Next >>" -command nextMonth
button .toolbar.clear -text "Clear"   -command {tical::render::canvas::clearSelection .c; showSelection .c {}}
pack .toolbar.prev .toolbar.today .toolbar.next .toolbar.clear -side left -padx 4

canvas .c -width 400 -height 300 -bg white -highlightthickness 0
pack .c -fill both -expand 1 -padx 5 -pady 5

label .status -text "Click days to select; Shift-click for a range" -anchor w
pack .status -side bottom -fill x -padx 5 -pady 3

renderCalendar

# headless self-test: skip the Tk event loop when DEMO_NOLOOP is set
if {[info exists ::env(DEMO_NOLOOP)]} { update idletasks; exit 0 }
