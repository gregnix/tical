# tical::io::import - read iCalendar files, expand recurrences
#
# OPTIONAL: requires tclutils (tclutils::tuical parses the file). Series
# are expanded by tical::event::expand (since 1.1.1, was tclutils::turrule).
#
#   parse ICS                -> list of core events (tical::event format)
#   readFile FILE            -> same, from a file (UTF-8)
#   expand EVENTS FROM TO ?TZ? -> occurrences touching FROM..TO (days,
#                               inclusive); recurring events expanded,
#                               EXDATE and RECURRENCE-ID overrides honoured
#   eventsInRange ICS FROM TO ?TZ? -> expand [parse ICS] FROM TO
#
# Read from VEVENT: UID, SUMMARY, DESCRIPTION, LOCATION, STATUS, CATEGORIES,
# DTSTART/DTEND (VALUE=DATE -> all-day; TZID is kept as key tzid: the time
# stays wall-clock time of that zone, tical::event and the views convert it
# to the display zone; a DTEND in another zone is converted to the zone of
# DTSTART), DURATION (when there is no DTEND), RRULE (expanded in the zone of
# DTSTART, so 18:00 stays 18:00 across daylight saving), EXDATE,
# RECURRENCE-ID (an override with STATUS:CANCELLED removes its
# occurrence in expand; EXDATE;VALUE=DATE removes the whole day of a timed
# series). A TZID Tcl does not know (custom VTIMEZONE) leaves the time
# as local time; tical::event::tzid tells which ones Tcl knows.
# Errors: {TICAL IMPORT <REASON>}.

package require Tcl 8.6-
package require tical::event 1.1.1
package require tclutils::tuical 0.1

package provide tical::io::import 1.1.1

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
        dict set ev dtend [_inZone [_value $pe] [_param $pe TZID] $tzid]
    } elseif {[set dur [::tclutils::tuical::property $ve DURATION]] ne ""} {
        dict set ev dtend [_addDuration [dict get $ev dtstart] $dur]
    }
    set v [_text $ve UID]
    if {$v ne ""} { dict set ev uid $v }
    set v [::tclutils::tuical::property $ve STATUS]
    if {$v ne ""} { dict set ev status [string toupper $v] }
    foreach {key prop} {description DESCRIPTION location LOCATION} {
        set v [_text $ve $prop]
        if {$v ne ""} { dict set ev $key $v }
    }
    set cats {}
    foreach p [::tclutils::tuical::properties $ve CATEGORIES] {
        foreach c [_splitList [dict get $p value]] {
            lappend cats [::tclutils::tuical::unescapeText $c]
        }
    }
    if {[llength $cats]} { dict set ev categories $cats }
    set rr [::tclutils::tuical::property $ve RRULE]
    if {$rr ne ""} { dict set ev rrule [::tical::event::rrule $rr] }
    set ex {}
    foreach p [::tclutils::tuical::properties $ve EXDATE] {
        foreach v [split [dict get $p value] ,] {
            lappend ex [_inZone [_normalize $v EXDATE] [_param $p TZID] $tzid]
        }
    }
    if {[llength $ex]} { dict set ev exdate $ex }
    set rid [_prop $ve RECURRENCE-ID]
    if {$rid ne ""} {
        dict set ev recurrence-id [_inZone [_value $rid] [_param $rid TZID] $tzid]
    }
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

# Split a list value at commas that are not escaped ("Arbeit\, Büro,Privat").
proc ::tical::io::import::_splitList {v} {
    set out {}
    set cur ""
    set n [string length $v]
    for {set i 0} {$i < $n} {incr i} {
        set c [string index $v $i]
        if {$c eq "\\" && $i + 1 < $n} {
            append cur $c [string index $v [incr i]]
        } elseif {$c eq ","} {
            lappend out $cur
            set cur ""
        } else {
            append cur $c
        }
    }
    lappend out $cur
    return $out
}

# A local value given in zone `from` as wall-clock time of zone `to` (both
# TZIDs); unchanged when they are equal or one of them is unknown.
proc ::tical::io::import::_inZone {v from to} {
    if {$from eq "" || $to eq "" || $from eq $to
            || [::tical::event::valueKind $v] ne "local"} {
        return $v
    }
    set zf [::tical::event::tzid $from]
    set zt [::tical::event::tzid $to]
    if {$zf eq "" || $zt eq ""} { return $v }
    set t [clock scan $v -format %Y%m%dT%H%M%S -timezone $zf]
    return [clock format $t -format %Y%m%dT%H%M%S -timezone $zt]
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
    return [::tical::event::_shift $start $secs]
}

# --- expanding -------------------------------------------------------------

# tical::event::expand, errors as {TICAL IMPORT <REASON>}
proc ::tical::io::import::expand {events from to {tz {}}} {
    if {[catch {::tical::event::expand $events $from $to $tz} r opt]} {
        set code [dict get $opt -errorcode]
        if {[lrange $code 0 1] eq {TICAL EVENT}} {
            set code [lreplace $code 1 1 IMPORT]
        }
        return -code error -errorcode $code $r
    }
    return $r
}

proc ::tical::io::import::eventsInRange {ics from to {tz {}}} {
    return [expand [parse $ics] $from $to $tz]
}
