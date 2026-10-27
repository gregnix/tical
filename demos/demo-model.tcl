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

# fields as in tical::event: -summary, -dtstart, -dtend (ISO or iCalendar form)
set id1 [tical::model::createAppointment \
    -summary "Team Meeting" \
    -dtstart 2025-10-14T10:00 \
    -dtend 2025-10-14T11:30 \
    -location "Conference Room A" \
    -description "Weekly team sync"]
puts "   Created appointment: $id1"

set id2 [tical::model::createAppointment \
    -summary "Lunch with Client" \
    -dtstart 2025-10-14T12:00 \
    -dtend 2025-10-14T13:00 \
    -location "Restaurant"]
puts "   Created appointment: $id2"

set id3 [tical::model::createAppointment \
    -summary "Code Review" \
    -dtstart 2025-10-15T14:00 \
    -dtend 2025-10-15T15:00]
puts "   Created appointment: $id3"

# a date without time is an all-day event
set evt1 [tical::model::createEvent \
    -summary "Project Deadline" \
    -dtstart 2025-10-31 \
    -categories "work" \
    -color "red"]
puts "   Created event: $evt1"

set evt2 [tical::model::createEvent \
    -summary "Birthday Party" \
    -dtstart 2025-11-15 \
    -categories "personal" \
    -color "green"]
puts "   Created event: $evt2"

puts ""
puts "2. READ - Getting appointment details:"
set appt [tical::model::getAppointment $id1]
puts "   ID: [dict get $appt id]"
puts "   Summary: [dict get $appt summary]"
puts "   Start: [dict get $appt dtstart]"
puts "   End: [dict get $appt dtend]"
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
    puts "      - [dict get $appt summary] ([dict get $appt dtstart]-[dict get $appt dtend])"
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
    puts "      - [dict get $evt summary] ([dict get $evt dtstart])"
}

puts ""
puts "7. DELETE - Removing an appointment:"
puts "   Deleting: $id3"
tical::model::deleteAppointment $id3
set remaining [tical::model::listAppointments]
puts "   Remaining: [expr {[llength $remaining] / 2}] appointments"

puts ""
puts "8. VIEW - appointments and events in the month view:"
package require tical::view::month
package require tical::render::term
set spec [tical::view::month::getData -year 2025 -month 10 -events [tical::model::toEvents]]
puts [tical::render::term::print $spec]
puts "   * = day with appointments or events"

puts ""
puts "Done! Model CRUD operations working perfectly."


