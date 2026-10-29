# tical::adapter::sqlite - SQLite Persistence Adapter
#
# Events in the format of tical::event (dtstart, dtend, summary ...). The
# table keeps its columns starts_at/ends_at. For one version (1.1) the
# fields starts_at/ends_at are still accepted by create/update and still
# present in what read/listRange/listAll return; they will be removed in 1.2.

package require Tcl 8.6-
package require tdbc::sqlite3
package require tical::event 1.1.1

namespace eval ::tical::adapter::sqlite {
    namespace export connect disconnect create read update delete listRange listAll exists migrate
}

proc ::tical::adapter::sqlite::connect {dbfile} {
    ::set db [tdbc::sqlite3::connection new $dbfile]
    migrate $db
    return $db
}

proc ::tical::adapter::sqlite::disconnect {db} {
    $db close
}

proc ::tical::adapter::sqlite::migrate {db} {
    $db allrows {
        CREATE TABLE IF NOT EXISTS events (
            uid TEXT PRIMARY KEY,
            starts_at TEXT NOT NULL,
            ends_at TEXT,
            summary TEXT NOT NULL,
            description TEXT,
            location TEXT,
            status TEXT,
            categories TEXT,
            rrule TEXT,
            exdate TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    }
    
    $db allrows {
        CREATE INDEX IF NOT EXISTS idx_events_start ON events(starts_at)
    }
    
    $db allrows {
        CREATE INDEX IF NOT EXISTS idx_events_end ON events(ends_at)
    }
    
    return 1
}

proc ::tical::adapter::sqlite::create {db event} {
    ::set event [_normalize $event]
    
    ::set now [_timestamp]
    
    ::set stmt [$db prepare {
        INSERT INTO events (
            uid, starts_at, ends_at, summary, description, location,
            status, categories, rrule, exdate, created_at, updated_at
        ) VALUES (
            :uid, :starts_at, :ends_at, :summary, :description, :location,
            :status, :categories, :rrule, :exdate, :created_at, :updated_at
        )
    }]
    
    ::set data [dict create \
        uid [_getOrGenerate $event uid] \
        starts_at [_dictGet $event dtstart ""] \
        ends_at [_dictGet $event dtend ""] \
        summary [_dictGet $event summary ""] \
        description [_dictGet $event description ""] \
        location [_dictGet $event location ""] \
        status [_dictGet $event status ""] \
        categories [_serializeList [_dictGet $event categories {}]] \
        rrule [_serializeDict [_dictGet $event rrule {}]] \
        exdate [_serializeList [_dictGet $event exdate {}]] \
        created_at $now \
        updated_at $now]
    
    $stmt execute $data
    $stmt close
    
    return [dict get $data uid]
}

proc ::tical::adapter::sqlite::read {db uid} {
    ::set stmt [$db prepare {
        SELECT * FROM events WHERE uid = :uid
    }]
    
    ::set rows [$stmt allrows [dict create uid $uid]]
    $stmt close
    
    if {[llength $rows] == 0} {
        return -code error -errorcode {TICAL SQLITE NOTFOUND} "event not found: $uid"
    }
    
    return [_deserializeEvent [lindex $rows 0]]
}

proc ::tical::adapter::sqlite::update {db uid event} {
    if {![exists $db $uid]} {
        return -code error -errorcode {TICAL SQLITE NOTFOUND} "event not found: $uid"
    }
    ::set event [_normalize $event]
    
    ::set now [_timestamp]
    
    ::set stmt [$db prepare {
        UPDATE events SET
            starts_at = :starts_at,
            ends_at = :ends_at,
            summary = :summary,
            description = :description,
            location = :location,
            status = :status,
            categories = :categories,
            rrule = :rrule,
            exdate = :exdate,
            updated_at = :updated_at
        WHERE uid = :uid
    }]
    
    ::set data [dict create \
        uid $uid \
        starts_at [_dictGet $event dtstart ""] \
        ends_at [_dictGet $event dtend ""] \
        summary [_dictGet $event summary ""] \
        description [_dictGet $event description ""] \
        location [_dictGet $event location ""] \
        status [_dictGet $event status ""] \
        categories [_serializeList [_dictGet $event categories {}]] \
        rrule [_serializeDict [_dictGet $event rrule {}]] \
        exdate [_serializeList [_dictGet $event exdate {}]] \
        updated_at $now]
    
    $stmt execute $data
    $stmt close
    
    return $uid
}

proc ::tical::adapter::sqlite::delete {db uid} {
    if {![exists $db $uid]} {
        return -code error -errorcode {TICAL SQLITE NOTFOUND} "event not found: $uid"
    }
    
    ::set stmt [$db prepare {DELETE FROM events WHERE uid = :uid}]
    $stmt execute [dict create uid $uid]
    $stmt close
    
    return 1
}

proc ::tical::adapter::sqlite::exists {db uid} {
    ::set stmt [$db prepare {SELECT COUNT(*) as count FROM events WHERE uid = :uid}]
    ::set rows [$stmt allrows [dict create uid $uid]]
    $stmt close
    
    ::set count [dict get [lindex $rows 0] count]
    return [expr {$count > 0}]
}

# Events starting in startDate..endDate. Bounds in any form tical::event
# accepts (2025-10-01, 20251001, 20251001T090000Z ...); a date as end bound
# includes that whole day. Dates and local times (bounds and stored values)
# are read in tz (default: tical::config timezone), UTC values as UTC, so
# local and UTC starts compare as points in time. A series (rrule) gives
# its occurrences that start in the range (each with recurrence-id; see
# tical::event::expand). Sorted by start.
proc ::tical::adapter::sqlite::listRange {db startDate endDate {tz {}}} {
    if {$tz eq {}} { ::set tz [::tical::event::_tz] }
    ::set startDate [::tical::event::normalizeValue $startDate startDate]
    ::set endDate [::tical::event::normalizeValue $endDate endDate]
    ::set from [::tical::event::_epoch $startDate $tz]
    if {[string length $endDate] == 8} {
        # whole end day: up to the start of the next day (exclusive)
        ::set to [expr {[clock add [::tical::event::_epoch $endDate $tz] 1 day -timezone $tz] - 1}]
    } else {
        ::set to [::tical::event::_epoch $endDate $tz]
    }
    # every stored value starts with YYYYMMDD: preselect by day with a
    # margin of one day for zone offsets, then compare epochs
    ::set lo [clock format [expr {$from - 86400}] -format %Y%m%d -gmt 1]
    ::set hi [clock format [expr {$to + 2 * 86400}] -format %Y%m%d -gmt 1]
    ::set stmt [$db prepare {
        SELECT * FROM events
        WHERE (rrule IS NULL OR rrule = '') AND starts_at >= :lo AND starts_at < :hi
    }]
    ::set rows [$stmt allrows [dict create lo $lo hi $hi]]
    $stmt close

    ::set keyed {}
    foreach row $rows {
        ::set e [::tical::event::_epoch [dict get $row starts_at] $tz]
        if {$e >= $from && $e <= $to} {
            lappend keyed [list $e [_deserializeEvent $row]]
        }
    }
    # series that began before the end of the range
    ::set stmt [$db prepare {
        SELECT * FROM events WHERE rrule <> '' AND starts_at < :hi
    }]
    ::set rows [$stmt allrows [dict create hi $hi]]
    $stmt close
    ::set d1 [clock format [expr {$from - 86400}] -format %Y-%m-%d -gmt 1]
    ::set d2 [clock format [expr {$to + 86400}] -format %Y-%m-%d -gmt 1]
    foreach row $rows {
        ::set ev [dict remove [_deserializeEvent $row] starts_at ends_at]
        foreach o [::tical::event::expand [list $ev] $d1 $d2 $tz] {
            ::set e [::tical::event::_epoch [dict get $o dtstart] $tz]
            if {$e >= $from && $e <= $to} { lappend keyed [list $e $o] }
        }
    }
    return [lmap p [lsort -integer -index 0 $keyed] {lindex $p 1}]
}

proc ::tical::adapter::sqlite::listAll {db} {
    ::set rows [$db allrows {SELECT * FROM events ORDER BY starts_at ASC}]
    
    ::set events {}
    foreach row $rows {
        lappend events [_deserializeEvent $row]
    }
    
    return $events
}

proc ::tical::adapter::sqlite::_validateEvent {event} {
    if {![dict exists $event dtstart] && ![dict exists $event starts_at]} {
        return -code error -errorcode {TICAL SQLITE ARGS} "event requires field: dtstart (or starts_at)"
    }
    
    if {![dict exists $event summary] && ![dict exists $event title]} {
        return -code error -errorcode {TICAL SQLITE ARGS} "event requires field: summary"
    }
    
    return 1
}

# required fields, then tical::event::normalize (accepts starts_at/ends_at)
proc ::tical::adapter::sqlite::_normalize {event} {
    _validateEvent $event
    return [::tical::event::normalize [dict remove $event created_at updated_at]]
}

proc ::tical::adapter::sqlite::_deserializeEvent {row} {
    ::set start [dict get $row starts_at]
    ::set event [dict create \
        uid [dict get $row uid] \
        dtstart $start \
        allday [expr {[string length $start] == 8}] \
        summary [dict get $row summary] \
        created_at [dict get $row created_at] \
        updated_at [dict get $row updated_at] \
        starts_at $start]
    
    if {[dict exists $row ends_at] && [dict get $row ends_at] ne ""} {
        dict set event dtend [dict get $row ends_at]
        dict set event ends_at [dict get $row ends_at]
    }
    
    if {[dict exists $row description] && [dict get $row description] ne ""} {
        dict set event description [dict get $row description]
    }
    
    if {[dict exists $row location] && [dict get $row location] ne ""} {
        dict set event location [dict get $row location]
    }
    
    if {[dict exists $row status] && [dict get $row status] ne ""} {
        dict set event status [dict get $row status]
    }
    
    if {[dict exists $row categories] && [dict get $row categories] ne ""} {
        dict set event categories [_deserializeList [dict get $row categories]]
    }
    
    if {[dict exists $row rrule] && [dict get $row rrule] ne ""} {
        dict set event rrule [_deserializeDict [dict get $row rrule]]
    }
    
    if {[dict exists $row exdate] && [dict get $row exdate] ne ""} {
        dict set event exdate [_deserializeList [dict get $row exdate]]
    }
    
    return $event
}

proc ::tical::adapter::sqlite::_dictGet {dict key default} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    }
    return $default
}

proc ::tical::adapter::sqlite::_getOrGenerate {dict key} {
    if {[dict exists $dict $key]} {
        return [dict get $dict $key]
    }
    return [_generateUID]
}

proc ::tical::adapter::sqlite::_generateUID {} {
    ::set ts [clock seconds]
    ::set rand [format %08x [expr {int(rand() * 0xFFFFFFFF)}]]
    return "tical-${ts}-${rand}"
}

proc ::tical::adapter::sqlite::_timestamp {} {
    return [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]
}

# Lists are stored comma-separated; a comma or backslash inside an element
# is escaped with a backslash ("Arbeit\, Büro,Privat"). Values written by
# 1.1 (no backslashes) read the same.
proc ::tical::adapter::sqlite::_serializeList {list} {
    if {[llength $list] == 0} {
        return ""
    }
    return [join [lmap e $list {string map {\\ \\\\ , \\,} $e}] ","]
}

proc ::tical::adapter::sqlite::_deserializeList {str} {
    if {$str eq ""} {
        return {}
    }
    ::set out {}
    ::set cur ""
    ::set n [string length $str]
    for {::set i 0} {$i < $n} {incr i} {
        ::set c [string index $str $i]
        if {$c eq "\\" && $i + 1 < $n} {
            append cur [string index $str [incr i]]
        } elseif {$c eq ","} {
            lappend out $cur
            ::set cur ""
        } else {
            append cur $c
        }
    }
    lappend out $cur
    return $out
}

proc ::tical::adapter::sqlite::_serializeDict {dict} {
    if {[dict size $dict] == 0} {
        return ""
    }
    ::set pairs {}
    dict for {key value} $dict {
        lappend pairs "$key=$value"
    }
    return [join $pairs ";"]
}

proc ::tical::adapter::sqlite::_deserializeDict {str} {
    if {$str eq ""} {
        return [dict create]
    }
    ::set dict [dict create]
    foreach pair [split $str ";"] {
        ::set parts [split $pair "="]
        if {[llength $parts] == 2} {
            dict set dict [lindex $parts 0] [lindex $parts 1]
        }
    }
    return $dict
}

package provide tical::adapter::sqlite 1.1.1

