# tical::adapter::sqlite - SQLite Persistence Adapter

package require Tcl 8.6-
package require tdbc::sqlite3

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
    _validateEvent $event
    
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
        starts_at [_dictGet $event starts_at ""] \
        ends_at [_dictGet $event ends_at ""] \
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
        error "Event not found: $uid"
    }
    
    return [_deserializeEvent [lindex $rows 0]]
}

proc ::tical::adapter::sqlite::update {db uid event} {
    if {![exists $db $uid]} {
        error "Event not found: $uid"
    }
    
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
        starts_at [_dictGet $event starts_at ""] \
        ends_at [_dictGet $event ends_at ""] \
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
        error "Event not found: $uid"
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

proc ::tical::adapter::sqlite::listRange {db startDate endDate} {
    ::set stmt [$db prepare {
        SELECT * FROM events 
        WHERE starts_at >= :start AND starts_at <= :end
        ORDER BY starts_at ASC
    }]
    
    ::set rows [$stmt allrows [dict create start $startDate end $endDate]]
    $stmt close
    
    ::set events {}
    foreach row $rows {
        lappend events [_deserializeEvent $row]
    }
    
    return $events
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
    if {![dict exists $event starts_at]} {
        error "Event requires starts_at field"
    }
    
    if {![dict exists $event summary]} {
        error "Event requires summary field"
    }
    
    return 1
}

proc ::tical::adapter::sqlite::_deserializeEvent {row} {
    ::set event [dict create \
        uid [dict get $row uid] \
        starts_at [dict get $row starts_at] \
        summary [dict get $row summary] \
        created_at [dict get $row created_at] \
        updated_at [dict get $row updated_at]]
    
    if {[dict exists $row ends_at] && [dict get $row ends_at] ne ""} {
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

proc ::tical::adapter::sqlite::_serializeList {list} {
    if {[llength $list] == 0} {
        return ""
    }
    return [join $list ","]
}

proc ::tical::adapter::sqlite::_deserializeList {str} {
    if {$str eq ""} {
        return {}
    }
    return [split $str ","]
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

package provide tical::adapter::sqlite 1.0

