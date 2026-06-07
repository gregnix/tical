package provide tical::io::ical 1.0
package require Tcl 8.6-

namespace eval tical::io::ical {
    variable prodid "-//tical//tical v2.0//EN"
    namespace export exportEvents exportToFile validate makeEvent
}

# Exportiert Events zu iCalendar String
proc tical::io::ical::exportEvents {events} {
    ::set lines [list "BEGIN:VCALENDAR" "VERSION:2.0" \
                    "PRODID:${::tical::io::ical::prodid}" \
                    "CALSCALE:GREGORIAN" "METHOD:PUBLISH"]
    foreach event $events {
        lappend lines {*}[BuildVEVENT $event]
    }
    lappend lines "END:VCALENDAR"
    return [join $lines "\r\n"]
}

# Exportiert Events in Datei
proc tical::io::ical::exportToFile {events filename} {
    ::set f [open $filename w]
    fconfigure $f -encoding utf-8 -translation crlf
    puts -nonewline $f [exportEvents $events]
    close $f
    return $filename
}

# Validiert Event-Dict
proc tical::io::ical::validate {event} {
    foreach field {uid dtstart summary} {
        if {![dict exists $event $field]} {
            error "Event missing required field: $field"
        }
    }
    ::set dtstart [dict get $event dtstart]
    if {![regexp {^\d{8}T\d{6}Z?$} $dtstart]} {
        error "dtstart format invalid: $dtstart (expected: YYYYMMDDTHHmmssZ)"
    }
    if {[dict exists $event dtend]} {
        ::set dtend [dict get $event dtend]
        if {![regexp {^\d{8}T\d{6}Z?$} $dtend]} {
            error "dtend format invalid: $dtend"
        }
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
        error "RRULE requires FREQ"
    }
    ::set freq [dict get $rruleDict freq]
    if {$freq ni {DAILY WEEKLY MONTHLY YEARLY}} {
        error "FREQ must be DAILY|WEEKLY|MONTHLY|YEARLY"
    }
    ::set parts [list "FREQ=$freq"]
    
    if {[dict exists $rruleDict count] && [dict exists $rruleDict until]} {
        error "RRULE cannot have both COUNT and UNTIL"
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
    
    if {[dict exists $rruleDict wkst]} {
        lappend parts "WKST=[dict get $rruleDict wkst]"
    }
    
    return [join $parts ";"]
}

# Formatiert Property mit Escaping
proc tical::io::ical::FormatProperty {name value} {
    if {$name in {DTSTART DTEND EXDATE RDATE}} {
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

# Line Folding: Zeilen > 75 Zeichen umbrechen
proc tical::io::ical::FoldLine {line} {
    if {[string length $line] <= 75} {
        return $line
    }
    ::set result [list [string range $line 0 74]]
    ::set pos 75
    ::set len [string length $line]
    while {$pos < $len} {
        lappend result " [string range $line $pos [expr {$pos + 73}]]"
        incr pos 74
    }
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
        error "Ungültiges iCal DateTime Format: $icaltime"
    }
    return "${year}-${month}-${day}T${hour}:${min}:${sec}${tz}"
}
