#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::model 1.0

puts "=== tical Model Demo (CRUD Operations) ==="
puts ""

# Clear any existing data
tical::model::clearAll

puts "1. CREATE - Adding appointments and events:"
puts ""

set id1 [tical::model::createAppointment \
    -title "Team Meeting" \
    -date 2025-10-14 \
    -startTime "10:00" \
    -endTime "11:30" \
    -location "Conference Room A" \
    -description "Weekly team sync"]
puts "   Created appointment: $id1"

set id2 [tical::model::createAppointment \
    -title "Lunch with Client" \
    -date 2025-10-14 \
    -startTime "12:00" \
    -endTime "13:00" \
    -location "Restaurant"]
puts "   Created appointment: $id2"

set id3 [tical::model::createAppointment \
    -title "Code Review" \
    -date 2025-10-15 \
    -startTime "14:00" \
    -endTime "15:00"]
puts "   Created appointment: $id3"

set evt1 [tical::model::createEvent \
    -title "Project Deadline" \
    -date 2025-10-31 \
    -category "work" \
    -color "red"]
puts "   Created event: $evt1"

set evt2 [tical::model::createEvent \
    -title "Birthday Party" \
    -date 2025-11-15 \
    -category "personal" \
    -color "green"]
puts "   Created event: $evt2"

puts ""
puts "2. READ - Getting appointment details:"
set appt [tical::model::getAppointment $id1]
puts "   ID: [dict get $appt id]"
puts "   Title: [dict get $appt title]"
puts "   Date: [dict get $appt date]"
puts "   Time: [dict get $appt startTime] - [dict get $appt endTime]"
puts "   Location: [dict get $appt location]"

puts ""
puts "3. UPDATE - Changing appointment:"
puts "   Before: [dict get [tical::model::getAppointment $id2] location]"
tical::model::updateAppointment $id2 -location "City Center Restaurant"
puts "   After: [dict get [tical::model::getAppointment $id2] location]"

puts ""
puts "4. QUERY - Appointments on 2025-10-14:"
set dayAppts [tical::model::getAppointmentsByDate 2025-10-14]
puts "   Found [expr {[llength $dayAppts] / 2}] appointments:"
dict for {id appt} $dayAppts {
    puts "      - [dict get $appt title] ([dict get $appt startTime]-[dict get $appt endTime])"
}

puts ""
puts "5. LIST - All appointments:"
set allAppts [tical::model::listAppointments]
puts "   Total: [expr {[llength $allAppts] / 2}] appointments"

puts ""
puts "6. LIST - All events:"
set allEvents [tical::model::listEvents]
puts "   Total: [expr {[llength $allEvents] / 2}] events"
dict for {id evt} $allEvents {
    puts "      - [dict get $evt title] ([dict get $evt date])"
}

puts ""
puts "7. DELETE - Removing an appointment:"
puts "   Deleting: $id3"
tical::model::deleteAppointment $id3
set remaining [tical::model::listAppointments]
puts "   Remaining: [expr {[llength $remaining] / 2}] appointments"

puts ""
puts "Done! Model CRUD operations working perfectly."


