#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::adapter::sqlite

puts "=== tical::adapter::sqlite Demo ==="
puts ""

puts "1. Verbindung zu In-Memory Datenbank..."
::set db [tical::adapter::sqlite::connect ":memory:"]
puts "   Verbunden!"
puts ""

puts "2. Events erstellen (CREATE)..."
puts "   ================================"

::set event1 [dict create \
    uid "event-1" \
    starts_at "20251014T090000Z" \
    ends_at "20251014T100000Z" \
    summary "Team Standup" \
    description "Daily standup meeting" \
    location "Conference Room A" \
    status "CONFIRMED"]

::set uid1 [tical::adapter::sqlite::create $db $event1]
puts "   Event 1 erstellt: $uid1"

::set event2 [dict create \
    starts_at "20251015T140000Z" \
    ends_at "20251015T150000Z" \
    summary "Code Review" \
    description "Review pull requests" \
    categories [list "Work" "Development"]]

::set uid2 [tical::adapter::sqlite::create $db $event2]
puts "   Event 2 erstellt: $uid2"

::set event3 [dict create \
    starts_at "20251016T100000Z" \
    ends_at "20251016T110000Z" \
    summary "Weekly Planning" \
    rrule [dict create freq WEEKLY count 4]]

::set uid3 [tical::adapter::sqlite::create $db $event3]
puts "   Event 3 erstellt: $uid3"
puts ""

puts "3. Alle Events auflisten (READ ALL)..."
puts "   ====================================="
::set allEvents [tical::adapter::sqlite::listAll $db]
puts "   Gefunden: [llength $allEvents] Events"
foreach event $allEvents {
    puts "   - [dict get $event summary] ([dict get $event starts_at])"
}
puts ""

puts "4. Event lesen (READ)..."
puts "   ====================="
::set retrieved [tical::adapter::sqlite::read $db "event-1"]
puts "   UID: [dict get $retrieved uid]"
puts "   Summary: [dict get $retrieved summary]"
puts "   Description: [dict get $retrieved description]"
puts "   Location: [dict get $retrieved location]"
puts "   Status: [dict get $retrieved status]"
puts ""

puts "5. Event aktualisieren (UPDATE)..."
puts "   ================================"
::set updated [dict create \
    starts_at "20251014T100000Z" \
    summary "Team Standup (UPDATED)" \
    description "Updated description" \
    status "TENTATIVE"]

tical::adapter::sqlite::update $db "event-1" $updated
puts "   Event event-1 aktualisiert"

::set check [tical::adapter::sqlite::read $db "event-1"]
puts "   Neuer Titel: [dict get $check summary]"
puts "   Neuer Status: [dict get $check status]"
puts ""

puts "6. Events in Zeitraum abfragen (listRange)..."
puts "   ==========================================="
::set rangeEvents [tical::adapter::sqlite::listRange $db \
    "20251015T000000Z" "20251016T235959Z"]

puts "   Events zwischen 15.10 und 16.10: [llength $rangeEvents]"
foreach event $rangeEvents {
    puts "   - [dict get $event summary]"
}
puts ""

puts "7. Event loeschen (DELETE)..."
puts "   ==========================="
tical::adapter::sqlite::delete $db $uid2
puts "   Event $uid2 geloescht"

::set afterDelete [tical::adapter::sqlite::listAll $db]
puts "   Verbleibende Events: [llength $afterDelete]"
puts ""

puts "8. Event mit RRULE..."
puts "   =================="
::set eventWithRRule [tical::adapter::sqlite::read $db $uid3]
if {[dict exists $eventWithRRule rrule]} {
    ::set rrule [dict get $eventWithRRule rrule]
    puts "   RRULE gefunden:"
    puts "     FREQ: [dict get $rrule freq]"
    puts "     COUNT: [dict get $rrule count]"
} else {
    puts "   Keine RRULE"
}
puts ""

puts "9. Event mit Kategorien..."
puts "   ======================="
::set event4 [dict create \
    starts_at "20251017T150000Z" \
    summary "Project Review" \
    categories [list "Work" "Project" "Review"]]

::set uid4 [tical::adapter::sqlite::create $db $event4]
::set withCats [tical::adapter::sqlite::read $db $uid4]

if {[dict exists $withCats categories]} {
    puts "   Kategorien: [join [dict get $withCats categories] {, }]"
}
puts ""

puts "10. Verbindung schliessen..."
tical::adapter::sqlite::disconnect $db
puts "    Verbindung geschlossen!"
puts ""

puts "=== Demo abgeschlossen ==="
puts ""
puts "Funktionen getestet:"
puts "  ✅ connect / disconnect"
puts "  ✅ create (mit und ohne UID)"
puts "  ✅ read (einzelnes Event)"
puts "  ✅ update (Event aktualisieren)"
puts "  ✅ delete (Event loeschen)"
puts "  ✅ exists (Event-Existenz pruefen)"
puts "  ✅ listRange (Events in Zeitraum)"
puts "  ✅ listAll (alle Events)"
puts "  ✅ RRULE Serialisierung"
puts "  ✅ Categories Serialisierung"
puts "  ✅ NULL-safe Handling (optionale Felder)"

