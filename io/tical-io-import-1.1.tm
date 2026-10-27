# tical::io::import - read iCalendar files, expand recurrences
#
# OPTIONAL: requires tclutils (tclutils::tuical parses the file,
# tclutils::turrule expands RRULE). The rest of tical does not need it.
#
#   parse ICS                -> list of core events (tical::event format)
#   readFile FILE            -> same, from a file (UTF-8)
#   expand EVENTS FROM TO ?TZ? -> occurrences touching FROM..TO (days,
#                               inclusive); recurring events expanded,
#                               EXDATE and RECURRENCE-ID overrides honoured
#   eventsInRange ICS FROM TO ?TZ? -> expand [parse ICS] FROM TO
#
# Read from VEVENT: UID, SUMMARY, DESCRIPTION, LOCATION, STATUS, CATEGORIES,
# DTSTART/DTEND (VALUE=DATE -> all-day; TZID is kept as key tzid, the time
# itself is taken as local time), DURATION (when there is no DTEND), RRULE,
# EXDATE, RECURRENCE-ID. Errors: {TICAL IMPORT <REASON>}.

package require Tcl 8.6-
package require tical::event 1.1
package require tclutils::tuical 0.1
package require tclutils::turrule 0.2

package provide tical::io::import 1.1

namespace eval ::tical::io::import {
    namespace export parse readFile expand eventsInRange
}

# --- reading ---------------------------------------------------------------

proc ::tical::io::import::readFile {file} {
    set f [open $file r]
    fconfigure $f -encoding utf-8
    set ics [read $f]
    close $f
    return [parse $ics]
}

proc ::tical::io::import::parse {ics} {
    if {[catch {::tclutils::tuical::parse $ics} comps opt]} {
        return -code error -errorcode {TICAL IMPORT SYNTAX} "iCalendar syntax: $comps"
    }
    set out {}
    foreach ve [::tclutils::tuical::events $comps] {
        set ev [_event $ve]
        if {$ev ne ""} { lappend out $ev }
    }
    return $out
}

proc ::tical::io::import::_param {prop name} {
    dict for {k v} [dict get $prop params] {
        if {[string equal -nocase $k $name]} { return $v }
    }
    return ""
}

proc ::tical::io::import::_prop {ve name} {
    set ps [::tclutils::tuical::properties $ve $name]
    if {[llength $ps]} { return [lindex $ps 0] }
    return ""
}

proc ::tical::io::import::_text {ve name} {
    return [::tclutils::tuical::unescapeText [::tclutils::tuical::property $ve $name]]
}

# One VEVENT -> core event ("" when it has no DTSTART)
proc ::tical::io::import::_event {ve} {
    set ps [_prop $ve DTSTART]
    if {$ps eq "" || [dict get $ps value] eq ""} { return "" }
    set ev [dict create summary [_text $ve SUMMARY] dtstart [_value $ps]]
    set tzid [_param $ps TZID]
    if {$tzid ne ""} { dict set ev tzid $tzid }
    set pe [_prop $ve DTEND]
    if {$pe ne "" && [dict get $pe value] ne ""} {
        dict set ev dtend [_value $pe]
    } elseif {[set dur [::tclutils::tuical::property $ve DURATION]] ne ""} {
        dict set ev dtend [_addDuration [dict get $ev dtstart] $dur]
    }
    foreach {key prop} {uid UID status STATUS} {
        set v [::tclutils::tuical::property $ve $prop]
        if {$v ne ""} { dict set ev $key $v }
    }
    foreach {key prop} {description DESCRIPTION location LOCATION} {
        set v [_text $ve $prop]
        if {$v ne ""} { dict set ev $key $v }
    }
    set cats {}
    foreach p [::tclutils::tuical::properties $ve CATEGORIES] {
        foreach c [split [dict get $p value] ,] {
            lappend cats [::tclutils::tuical::unescapeText $c]
        }
    }
    if {[llength $cats]} { dict set ev categories $cats }
    set rr [::tclutils::tuical::property $ve RRULE]
    if {$rr ne ""} { dict set ev rrule [::tical::event::rrule $rr] }
    set ex {}
    foreach p [::tclutils::tuical::properties $ve EXDATE] {
        foreach v [split [dict get $p value] ,] {
            lappend ex [_normalize $v EXDATE]
        }
    }
    if {[llength $ex]} { dict set ev exdate $ex }
    set rid [_prop $ve RECURRENCE-ID]
    if {$rid ne ""} { dict set ev recurrence-id [_value $rid] }
    if {[catch {::tical::event::normalize $ev} nev opt]} {
        return -code error -errorcode [lreplace [dict get $opt -errorcode] 1 1 IMPORT] \
            "[_label $ev]: $nev"
    }
    return $nev
}

# "VEVENT uid" or, without UID, "VEVENT \"summary\"" for messages
proc ::tical::io::import::_label {ev} {
    if {[dict exists $ev uid] && [dict get $ev uid] ne ""} { return "VEVENT [dict get $ev uid]" }
    if {[dict exists $ev summary]} { return "VEVENT \"[dict get $ev summary]\"" }
    return VEVENT
}

proc ::tical::io::import::_value {prop} {
    set v [dict get $prop value]
    if {[string equal -nocase [_param $prop VALUE] DATE]} {
        set v [string range $v 0 7]
    }
    return [_normalize $v [dict get $prop name]]
}

proc ::tical::io::import::_normalize {v what} {
    if {[catch {::tical::event::normalizeValue $v $what} r]} {
        return -code error -errorcode {TICAL IMPORT FORMAT} $r
    }
    return $r
}

# DTSTART + DURATION (P1D, PT1H30M, P1W ...) -> DTEND, same value kind
proc ::tical::io::import::_addDuration {start dur} {
    if {![regexp {^\+?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$} \
            $dur -> w d h m s]} {
        return -code error -errorcode {TICAL IMPORT FORMAT} "unsupported DURATION: \"$dur\""
    }
    foreach x {w d h m s} { if {[set $x] eq ""} { set $x 0 } }
    set secs [expr {(($w * 7 + $d) * 24 + $h) * 3600 + $m * 60 + $s}]
    return [_shift $start $secs]
}

# Shift a basic-form value by secs (calendar arithmetic in UTC, so local
# and date values keep their wall-clock meaning).
proc ::tical::io::import::_shift {v secs} {
    switch -- [::tical::event::valueKind $v] {
        date {
            set t [clock scan $v -format %Y%m%d -gmt 1]
            return [clock format [expr {$t + $secs}] -format %Y%m%d -gmt 1]
        }
        utc {
            set t [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1]
            return [clock format [expr {$t + $secs}] -format %Y%m%dT%H%M%SZ -gmt 1]
        }
        local {
            set t [clock scan $v -format %Y%m%dT%H%M%S -gmt 1]
            return [clock format [expr {$t + $secs}] -format %Y%m%dT%H%M%S -gmt 1]
        }
    }
}

proc ::tical::io::import::_secs {v} {
    switch -- [::tical::event::valueKind $v] {
        date  { return [clock scan $v -format %Y%m%d -gmt 1] }
        utc   { return [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1] }
        local { return [clock scan $v -format %Y%m%dT%H%M%S -gmt 1] }
    }
}

# --- expanding -------------------------------------------------------------

proc ::tical::io::import::_iso {d} {
    set d [::tical::event::normalizeValue $d]
    if {[string length $d] != 8} {
        return -code error -errorcode {TICAL IMPORT RANGE} \
            "range bounds must be dates (YYYY-MM-DD), got \"$d\""
    }
    return "[string range $d 0 3]-[string range $d 4 5]-[string range $d 6 7]"
}

proc ::tical::io::import::_touches {ev from to tz} {
    set ds [::tical::event::days $ev $tz]
    return [expr {[lindex $ds end] >= $from && [lindex $ds 0] <= $to}]
}

proc ::tical::io::import::_isoDay {iso n} {
    set t [clock scan $iso -format %Y-%m-%d -gmt 1]
    return [clock format [clock add $t $n days -gmt 1] -format %Y-%m-%d -gmt 1]
}

proc ::tical::io::import::expand {events from to {tz {}}} {
    if {$tz eq {}} { set tz [::tical::event::_tz] }
    set from [_iso $from]
    set to   [_iso $to]
    if {$to < $from} {
        return -code error -errorcode {TICAL IMPORT RANGE} \
            "range end $to is before start $from"
    }
    set events [lmap ev $events {::tical::event::normalize $ev}]
    # RECURRENCE-ID overrides replace the occurrence of their master
    set overridden [dict create]
    foreach ev $events {
        if {[dict exists $ev recurrence-id] && [dict exists $ev uid]} {
            dict lappend overridden [dict get $ev uid] [dict get $ev recurrence-id]
        }
    }
    set out {}
    foreach ev $events {
        if {![dict exists $ev rrule] || [dict exists $ev recurrence-id]} {
            if {[_touches $ev $from $to $tz]} { lappend out $ev }
            continue
        }
        set start [dict get $ev dtstart]
        set kind  [::tical::event::valueKind $start]
        set dur 0
        if {[dict exists $ev dtend]} {
            set dur [expr {[_secs [dict get $ev dtend]] - [_secs $start]}]
        }
        set skip {}
        if {[dict exists $ev exdate]} { set skip [dict get $ev exdate] }
        if {[dict exists $ev uid] && [dict exists $overridden [dict get $ev uid]]} {
            lappend skip {*}[dict get $overridden [dict get $ev uid]]
        }
        # widen the window by the duration and a day for UTC/local shifts;
        # _touches filters exactly afterwards
        set back [expr {$dur / 86400 + 2}]
        set occs [_occurrences $ev [_isoDay $from -$back] "[_isoDay $to 2]T23:59:59"]
        set base [dict remove $ev rrule exdate]
        foreach occ $occs {
            set v [_normalize $occ occurrence]
            if {$kind eq "utc"} { append v Z }
            if {$v in $skip} continue
            set o [dict replace $base dtstart $v recurrence-id $v]
            if {[dict exists $ev dtend]} { dict set o dtend [_shift $v $dur] }
            if {[_touches $o $from $to $tz]} { lappend out $o }
        }
    }
    # sorted by start
    set keyed [lmap ev $out {list [lindex [::tical::event::epochs $ev $tz] 0] $ev}]
    return [lmap p [lsort -integer -index 0 $keyed] {lindex $p 1}]
}

proc ::tical::io::import::_occurrences {ev from to} {
    set start [dict get $ev dtstart]
    if {[::tical::event::valueKind $start] eq "utc"} { set start [string range $start 0 end-1] }
    set rule [::tical::event::rruleString [dict get $ev rrule]]
    # turrule works on date/date-time values without zone
    set rule [regsub {(UNTIL=\d{8}T\d{6})Z} $rule {\1}]
    if {[catch {::tclutils::turrule::occurrences -dtstart $start -rule $rule \
            -from $from -to $to} occs opt]} {
        return -code error -errorcode {TICAL IMPORT RRULE} \
            "[_label $ev]: RRULE $rule: $occs"
    }
    return $occs
}

proc ::tical::io::import::eventsInRange {ics from to {tz {}}} {
    return [expand [parse $ics] $from $to $tz]
}
