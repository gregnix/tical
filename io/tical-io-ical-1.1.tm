package provide tical::io::ical 1.1
package require Tcl 8.6-
package require tical::event 1.1

namespace eval tical::io::ical {
    variable prodid "-//tical//tical 1.1//EN"
    namespace export exportEvents exportToFile validate makeEvent
}

# Export events as an iCalendar string. Each event goes through
# tical::event::normalize first, so the older field names (tical::model,
# tical::adapter::sqlite) and ISO dates are accepted; all-day events
# (date values) are written with VALUE=DATE.
proc tical::io::ical::exportEvents {events} {
    ::set lines [list "BEGIN:VCALENDAR" "VERSION:2.0" \
                    "PRODID:${::tical::io::ical::prodid}" \
                    "CALSCALE:GREGORIAN" "METHOD:PUBLISH"]
    foreach event $events {
        lappend lines {*}[BuildVEVENT [::tical::event::normalize $event]]
    }
    lappend lines "END:VCALENDAR"
    return [join $lines "\r\n"]
}

# Exportiert Events in Datei
proc tical::io::ical::exportToFile {events filename} {
    ::set f [open $filename w]
    # exportEvents already joins with CRLF; write it unchanged
    fconfigure $f -encoding utf-8 -translation lf
    puts -nonewline $f [exportEvents $events]
    close $f
    return $filename
}

# Validate an event dict as it would be written: required fields, the value
# form of dtstart/dtend (YYYYMMDD all-day, YYYYMMDDTHHMMSS local or
# YYYYMMDDTHHMMSSZ UTC; both of the same kind, dtend not before dtstart),
# rrule as on export.
proc tical::io::ical::validate {event} {
    foreach field {uid dtstart summary} {
        if {![dict exists $event $field]} {
            return -code error -errorcode {TICAL ICAL FIELD} \
                "event missing required field: $field"
        }
    }
    foreach field {dtstart dtend} {
        if {![dict exists $event $field]} continue
        ::set v [dict get $event $field]
        if {![regexp {^\d{8}(T\d{6}Z?)?$} $v]} {
            return -code error -errorcode {TICAL ICAL FORMAT} \
                "$field format invalid: \"$v\" (expected YYYYMMDD, YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ)"
        }
    }
    if {[dict exists $event dtend]} {
        ::set s [dict get $event dtstart]; ::set e [dict get $event dtend]
        if {([string length $s] == 8) != ([string length $e] == 8)} {
            return -code error -errorcode {TICAL ICAL FORMAT} \
                "dtstart and dtend must both be dates (YYYYMMDD) or both date-times"
        }
        if {[string index $s end] eq [string index $e end] && $e < $s} {
            return -code error -errorcode {TICAL ICAL RANGE} \
                "dtend \"$e\" is before dtstart \"$s\""
        }
    }
    if {[dict exists $event rrule]} {
        BuildRRULE [::tical::event::rrule [dict get $event rrule]]
    }
    return 1
}

# Erstellt Event mit automatischer UID/DTSTAMP
proc tical::io::ical::makeEvent {args} {
    ::set event [dict create uid [GenerateUID] dtstamp [GetTimestamp]]
    foreach {key value} $args {
        dict set event [string trimleft $key -] $value
    }
    return $event
}

# Baut VEVENT-Block
proc tical::io::ical::BuildVEVENT {event} {
    ::set lines [list "BEGIN:VEVENT"]
    if {![dict exists $event uid] || [dict get $event uid] eq ""} {
        dict set event uid [GenerateUID]
    }
    lappend lines "UID:[dict get $event uid]"
    lappend lines "DTSTAMP:[GetTimestamp]"
    lappend lines [FormatProperty DTSTART [dict get $event dtstart]]
    
    if {[dict exists $event dtend]} {
        lappend lines [FormatProperty DTEND [dict get $event dtend]]
    } elseif {[dict exists $event duration]} {
        lappend lines "DURATION:[dict get $event duration]"
    }
    
    lappend lines [FormatProperty SUMMARY [dict get $event summary]]
    
    if {[dict exists $event description]} {
        lappend lines [FormatProperty DESCRIPTION [dict get $event description]]
    }
    if {[dict exists $event location]} {
        lappend lines [FormatProperty LOCATION [dict get $event location]]
    }
    if {[dict exists $event status]} {
        lappend lines "STATUS:[dict get $event status]"
    }
    if {[dict exists $event categories]} {
        lappend lines "CATEGORIES:[join [dict get $event categories] ,]"
    }
    if {[dict exists $event rrule]} {
        lappend lines "RRULE:[BuildRRULE [dict get $event rrule]]"
    }
    if {[dict exists $event exdate]} {
        foreach exdate [dict get $event exdate] {
            lappend lines [FormatProperty EXDATE $exdate]
        }
    }
    
    lappend lines "END:VEVENT"
    return $lines
}

# Baut RRULE String
proc tical::io::ical::BuildRRULE {rruleDict} {
    if {![dict exists $rruleDict freq]} {
        return -code error -errorcode {TICAL ICAL RRULE} "RRULE requires FREQ"
    }
    ::set freq [dict get $rruleDict freq]
    if {$freq ni {DAILY WEEKLY MONTHLY YEARLY}} {
        return -code error -errorcode {TICAL ICAL RRULE} \
            "FREQ must be DAILY|WEEKLY|MONTHLY|YEARLY, got \"$freq\""
    }
    ::set parts [list "FREQ=$freq"]
    
    if {[dict exists $rruleDict count] && [dict exists $rruleDict until]} {
        return -code error -errorcode {TICAL ICAL RRULE} "RRULE cannot have both COUNT and UNTIL"
    }
    
    if {[dict exists $rruleDict count]} {
        lappend parts "COUNT=[dict get $rruleDict count]"
    } elseif {[dict exists $rruleDict until]} {
        lappend parts "UNTIL=[dict get $rruleDict until]"
    }
    
    if {[dict exists $rruleDict interval]} {
        ::set interval [dict get $rruleDict interval]
        if {$interval > 1} {
            lappend parts "INTERVAL=$interval"
        }
    }
    
    if {[dict exists $rruleDict byday]} {
        lappend parts "BYDAY=[join [dict get $rruleDict byday] ,]"
    }
    foreach k {bymonth bymonthday} {
        if {[dict exists $rruleDict $k]} {
            lappend parts "[string toupper $k]=[join [dict get $rruleDict $k] ,]"
        }
    }
    
    if {[dict exists $rruleDict wkst]} {
        lappend parts "WKST=[dict get $rruleDict wkst]"
    }
    
    return [join $parts ";"]
}

# Formatiert Property mit Escaping
proc tical::io::ical::FormatProperty {name value} {
    if {$name in {DTSTART DTEND EXDATE RDATE}} {
        if {[regexp {^\d{8}$} $value]} {
            return "${name};VALUE=DATE:${value}"
        }
        return "${name}:${value}"
    }
    ::set escaped [Escape $value]
    ::set line "${name}:${escaped}"
    return [FoldLine $line]
}

# Escaped Text für iCalendar (RFC 5545)
proc tical::io::ical::Escape {text} {
    ::set text [string map {\\ \\\\ \; \\\; \, \\\, \n \\n} $text]
    return $text
}

# Un-escapes Text
proc tical::io::ical::Unescape {text} {
    ::set text [string map {\\n \n \\\, \, \\\; \; \\\\ \\} $text]
    return $text
}

# Line Folding (RFC 5545 3.1): Zeilen > 75 Oktette (UTF-8) umbrechen,
# Folgezeilen beginnen mit einem Leerzeichen; Zeichen werden nie geteilt.
proc tical::io::ical::FoldLine {line} {
    if {[string length [encoding convertto utf-8 $line]] <= 75} {
        return $line
    }
    ::set result {}
    ::set cur ""
    ::set n 0
    ::set max 75
    foreach ch [split $line ""] {
        ::set b [string length [encoding convertto utf-8 $ch]]
        if {$n + $b > $max} {
            lappend result $cur
            ::set cur " "
            ::set n 1
        }
        append cur $ch
        incr n $b
    }
    lappend result $cur
    return [join $result "\r\n"]
}

# Generiert UID
proc tical::io::ical::GenerateUID {} {
    ::set ts [clock seconds]
    ::set rand [format %08x [expr {int(rand() * 0xFFFFFFFF)}]]
    return "${ts}-${rand}@tical"
}

# Aktueller Timestamp (UTC)
proc tical::io::ical::GetTimestamp {} {
    return [clock format [clock seconds] -format "%Y%m%dT%H%M%SZ" -gmt 1]
}

# Konvertiert ISO-8601 zu iCalendar Format
proc tical::io::ical::ISO8601ToICal {isotime} {
    ::set ical [string map {- "" : ""} $isotime]
    return $ical
}

# Konvertiert iCalendar zu ISO-8601
proc tical::io::ical::ICalToISO8601 {icaltime} {
    if {![regexp {^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$} $icaltime \
            -> year month day hour min sec tz]} {
        return -code error -errorcode {TICAL ICAL FORMAT} \
            "invalid iCalendar date-time: \"$icaltime\" (expected YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ)"
    }
    return "${year}-${month}-${day}T${hour}:${min}:${sec}${tz}"
}
