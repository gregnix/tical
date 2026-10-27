# tical::event - one event format for views, model, io and adapters
#
# Core event dict (keys follow iCalendar, lower case):
#   summary      title (required, may be empty)
#   dtstart      start (required): YYYYMMDD (all-day), YYYYMMDDTHHMMSS (local)
#                or YYYYMMDDTHHMMSSZ (UTC)
#   dtend        end (optional), same kind as dtstart; for all-day events
#                exclusive (the day after the last day, as in iCalendar)
#   allday       0|1, follows dtstart (a date value means all-day)
#   uid, description, location, status, categories, rrule, exdate
#                optional; rrule is a dict {freq WEEKLY count 5 byday {MO}}
# Other keys are kept unchanged.
#
# normalize also accepts ISO input (2025-10-14, 2025-10-14T09:00, 2025-10-14
# 09:00:00Z) and, for one version, the older field names:
#   title -> summary, date + startTime/endTime -> dtstart/dtend (tical::model),
#   starts_at/ends_at -> dtstart/dtend (tical::adapter::sqlite),
#   allDay -> allday, category -> categories, id -> uid.

package require Tcl 8.6-
package require tical::util 1.0

package provide tical::event 1.1

namespace eval ::tical::event {
    namespace export normalize validate normalizeValue valueKind \
        toLocal epochs days distribute rrule rruleString
    variable legacy {title date startTime endTime starts_at ends_at allDay category id}
}

# --- values -------------------------------------------------------------

# Normalize one date or date-time value to the iCalendar basic form:
# YYYYMMDD, YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ. Error {TICAL EVENT FORMAT}.
proc ::tical::event::normalizeValue {v {field value}} {
    set v [string trim $v]
    set Y ""; set S 00; set Z ""
    if {[regexp {^(\d{4})(\d{2})(\d{2})$} $v -> Y M D]
     || [regexp {^(\d{4})-(\d{2})-(\d{2})$} $v -> Y M D]} {
        set out $Y$M$D
        set H ""
    } elseif {[regexp {^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$} $v -> Y M D H Mi S Z]
           || [regexp {^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?(Z?)$} $v -> Y M D H Mi S Z]} {
        if {$S eq ""} { set S 00 }
        set out $Y$M${D}T$H$Mi$S$Z
    } else {
        return -code error -errorcode {TICAL EVENT FORMAT} \
            "$field format invalid: \"$v\" (expected YYYYMMDD, YYYYMMDDTHHMMSS,\
            YYYYMMDDTHHMMSSZ or ISO 8601 such as 2025-10-14 or 2025-10-14T09:00)"
    }
    # real calendar date and time?
    set ok [expr {![catch {clock scan $Y$M$D -format %Y%m%d -gmt 1} t]
        && [clock format $t -format %Y%m%d -gmt 1] eq "$Y$M$D"}]
    if {$ok && $H ne ""} {
        set ok [expr {[scan $H %d] < 24 && [scan $Mi %d] < 60 && [scan $S %d] < 60}]
    }
    if {!$ok} {
        return -code error -errorcode {TICAL EVENT FORMAT} \
            "$field is not a valid date or time: \"$v\""
    }
    return $out
}

# date | local | utc (value in basic form)
proc ::tical::event::valueKind {v} {
    if {[string length $v] == 8} { return date }
    if {[string index $v end] eq "Z"} { return utc }
    return local
}

# Epoch of a basic-form value. date and local values are read in tz, UTC
# values as UTC.
proc ::tical::event::_epoch {v tz} {
    switch -- [valueKind $v] {
        date  { return [clock scan "$v 000000" -format "%Y%m%d %H%M%S" -timezone $tz] }
        utc   { return [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1] }
        local { return [clock scan $v -format %Y%m%dT%H%M%S -timezone $tz] }
    }
}

# Local date and time of a value: {YYYY-MM-DD HH:MM}; time is "" for dates.
proc ::tical::event::toLocal {v {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    set v [normalizeValue $v]
    if {[valueKind $v] eq "date"} {
        return [list "[string range $v 0 3]-[string range $v 4 5]-[string range $v 6 7]" ""]
    }
    set e [_epoch $v $tz]
    return [list [clock format $e -format %Y-%m-%d -timezone $tz] \
                 [clock format $e -format %H:%M -timezone $tz]]
}

proc ::tical::event::_tz {} {
    if {[catch {package require tical::config 1.0}] == 0} {
        return [tical::config::get timezone]
    }
    return :localtime
}

# --- rrule --------------------------------------------------------------

# RRULE as dict with lower-case keys; accepts a dict or an RRULE string
# ("FREQ=WEEKLY;BYDAY=MO,WE"). List parts (byday, bymonth, bymonthday) are
# Tcl lists.
proc ::tical::event::rrule {r} {
    set d [dict create]
    if {[string first = $r] >= 0} {
        foreach part [split [string trim $r] ";"] {
            set i [string first = $part]
            if {$i < 1} continue
            dict set d [string tolower [string range $part 0 $i-1]] [string range $part $i+1 end]
        }
    } else {
        if {[catch {dict size $r}]} {
            return -code error -errorcode {TICAL EVENT RRULE} "rrule must be a dict or an RRULE string, got \"$r\""
        }
        dict for {k v} $r { dict set d [string tolower $k] $v }
    }
    foreach k {byday bymonth bymonthday} {
        if {[dict exists $d $k]} {
            dict set d $k [split [join [dict get $d $k] ,] ,]
        }
    }
    if {[dict exists $d freq]} { dict set d freq [string toupper [dict get $d freq]] }
    return $d
}

# RRULE dict -> RRULE string (FREQ first, then the other parts).
proc ::tical::event::rruleString {r} {
    set d [rrule $r]
    set parts {}
    if {[dict exists $d freq]} { lappend parts FREQ=[dict get $d freq] }
    dict for {k v} $d {
        if {$k eq "freq"} continue
        lappend parts [string toupper $k]=[join $v ,]
    }
    return [join $parts ";"]
}

# --- normalize / validate -----------------------------------------------

proc ::tical::event::_get {ev key} {
    if {[dict exists $ev $key]} { return [dict get $ev $key] }
    return ""
}

proc ::tical::event::normalize {ev} {
    variable legacy
    if {[catch {dict size $ev}]} {
        return -code error -errorcode {TICAL EVENT ARGS} "event must be a dict, got \"$ev\""
    }
    set out [dict create]
    # keys that are neither core nor legacy pass through unchanged
    dict for {k v} $ev {
        if {$k in $legacy} continue
        dict set out $k $v
    }
    # summary <- title
    if {![dict exists $ev summary] && [dict exists $ev title]} {
        dict set out summary [dict get $ev title]
    }
    # uid <- id
    if {![dict exists $ev uid] && [_get $ev id] ne ""} {
        dict set out uid [dict get $ev id]
    }
    # categories <- category
    if {![dict exists $ev categories] && [_get $ev category] ne ""} {
        dict set out categories [list [dict get $ev category]]
    }
    # dtstart/dtend <- starts_at/ends_at or date + startTime/endTime
    if {[_get $ev dtstart] eq ""} {
        if {[_get $ev starts_at] ne ""} {
            dict set out dtstart [dict get $ev starts_at]
            if {[_get $ev dtend] eq "" && [_get $ev ends_at] ne ""} {
                dict set out dtend [dict get $ev ends_at]
            }
        } elseif {[_get $ev date] ne ""} {
            set date [dict get $ev date]
            if {[_get $ev startTime] ne ""} {
                dict set out dtstart "$date [_hms [dict get $ev startTime]]"
                if {[_get $ev dtend] eq "" && [_get $ev endTime] ne ""} {
                    dict set out dtend "$date [_hms [dict get $ev endTime]]"
                }
            } else {
                dict set out dtstart $date
            }
        }
    }
    # allday <- allDay
    set allday [_get $ev allday]
    if {$allday eq "" && [dict exists $ev allDay] && [_get $ev startTime] eq ""
            && [_get $ev starts_at] eq "" && ![dict exists $ev dtstart]} {
        set allday [dict get $ev allDay]
    }
    if {[_get $out dtend] eq ""} { dict unset out dtend }

    if {![dict exists $out dtstart] || [dict get $out dtstart] eq ""} {
        return -code error -errorcode {TICAL EVENT FIELD} \
            "event missing required field: dtstart"
    }
    if {![dict exists $out summary]} {
        return -code error -errorcode {TICAL EVENT FIELD} \
            "event missing required field: summary"
    }
    dict set out dtstart [normalizeValue [dict get $out dtstart] dtstart]
    if {[dict exists $out dtend]} {
        dict set out dtend [normalizeValue [dict get $out dtend] dtend]
    }
    # all-day: a date value, or allday 1 (date-times are cut to their date)
    if {$allday ne "" && ![string is boolean -strict $allday]} {
        return -code error -errorcode {TICAL EVENT FORMAT} \
            "allday must be 0 or 1, got \"$allday\""
    }
    set start [dict get $out dtstart]
    if {[valueKind $start] eq "date" || ($allday ne "" && $allday)} {
        dict set out dtstart [string range $start 0 7]
        if {[dict exists $out dtend]} {
            set end [dict get $out dtend]
            if {[valueKind $end] ne "date"} {
                # inclusive end day of a timed value -> exclusive date
                set end [_addDays [string range $end 0 7] 1]
            }
            if {$end <= [dict get $out dtstart]} {
                set end [_addDays [dict get $out dtstart] 1]
            }
            dict set out dtend $end
        }
        dict set out allday 1
    } else {
        dict set out allday 0
    }
    if {[dict exists $out rrule]} {
        if {[dict get $out rrule] eq ""} {
            dict unset out rrule
        } else {
            dict set out rrule [rrule [dict get $out rrule]]
        }
    }
    if {[dict exists $out exdate]} {
        dict set out exdate [lmap x [dict get $out exdate] {normalizeValue $x exdate}]
    }
    validate $out
    return $out
}

proc ::tical::event::_hms {t} {
    if {[regexp {^(\d{1,2}):(\d{2})(?::(\d{2}))?$} $t -> h m s]} {
        if {$s eq ""} { set s 00 }
        return [format %02d:%s:%s [scan $h %d] $m $s]
    }
    return -code error -errorcode {TICAL EVENT FORMAT} \
        "time format invalid: \"$t\" (expected HH:MM or HH:MM:SS)"
}

proc ::tical::event::_addDays {ymd n} {
    set t [clock scan $ymd -format %Y%m%d -gmt 1]
    return [clock format [clock add $t $n days -gmt 1] -format %Y%m%d -gmt 1]
}

# Validate a core event dict. Returns 1 or raises {TICAL EVENT <REASON>}.
proc ::tical::event::validate {ev} {
    if {[catch {dict size $ev}]} {
        return -code error -errorcode {TICAL EVENT ARGS} "event must be a dict, got \"$ev\""
    }
    foreach f {summary dtstart} {
        if {![dict exists $ev $f]} {
            return -code error -errorcode {TICAL EVENT FIELD} \
                "event missing required field: $f"
        }
    }
    set s [dict get $ev dtstart]
    if {[normalizeValue $s dtstart] ne $s} {
        return -code error -errorcode {TICAL EVENT FORMAT} \
            "dtstart not in basic form: \"$s\" (use tical::event::normalize)"
    }
    if {[dict exists $ev dtend]} {
        set e [dict get $ev dtend]
        if {[normalizeValue $e dtend] ne $e} {
            return -code error -errorcode {TICAL EVENT FORMAT} \
                "dtend not in basic form: \"$e\" (use tical::event::normalize)"
        }
        set ks [valueKind $s]; set ke [valueKind $e]
        if {($ks eq "date") != ($ke eq "date")} {
            return -code error -errorcode {TICAL EVENT FORMAT} \
                "dtstart and dtend must both be dates or both date-times"
        }
        if {$ks eq $ke && (($ks eq "date" && $e <= $s) || ($ks ne "date" && $e < $s))} {
            return -code error -errorcode {TICAL EVENT RANGE} \
                "dtend \"$e\" is before dtstart \"$s\"[expr {$ks eq "date" ? { (all-day dtend is exclusive)} : {}}]"
        }
    }
    if {[dict exists $ev allday]} {
        set a [dict get $ev allday]
        if {![string is boolean -strict $a] || ($a && [valueKind $s] ne "date")
                || (!$a && [valueKind $s] eq "date")} {
            return -code error -errorcode {TICAL EVENT FORMAT} \
                "allday \"$a\" does not match dtstart \"$s\""
        }
    }
    if {[dict exists $ev rrule]} {
        set r [rrule [dict get $ev rrule]]
        if {![dict exists $r freq]} {
            return -code error -errorcode {TICAL EVENT RRULE} "rrule requires freq"
        }
        if {[dict get $r freq] ni {DAILY WEEKLY MONTHLY YEARLY}} {
            return -code error -errorcode {TICAL EVENT RRULE} \
                "rrule freq must be DAILY, WEEKLY, MONTHLY or YEARLY, got \"[dict get $r freq]\""
        }
        if {[dict exists $r count] && [dict exists $r until]} {
            return -code error -errorcode {TICAL EVENT RRULE} \
                "rrule cannot have both count and until"
        }
    }
    return 1
}

# --- placing events on days -------------------------------------------------

# {start end} epochs of an event in tz; end is exclusive. Without dtend: a
# timed event lasts 0 s, an all-day event one day.
proc ::tical::event::epochs {ev {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    set s [_epoch [dict get $ev dtstart] $tz]
    if {[dict exists $ev dtend]} {
        set e [_epoch [dict get $ev dtend] $tz]
    } elseif {[valueKind [dict get $ev dtstart]] eq "date"} {
        set e [clock add $s 1 day -timezone $tz]
    } else {
        set e $s
    }
    return [list $s $e]
}

# Local days (YYYY-MM-DD) an event touches, in order.
proc ::tical::event::days {ev {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    lassign [epochs $ev $tz] s e
    set first [clock format $s -format %Y-%m-%d -timezone $tz]
    set last $first
    if {$e > $s} { set last [clock format [expr {$e - 1}] -format %Y-%m-%d -timezone $tz] }
    if {$last eq $first} { return [list $first] }
    return [::tical::util::dateRange $first $last $tz]
}

# Entry of an event in one cell: the event plus
#   part  single | start | middle | end   (position in a multi-day event)
#   time  local start HH:MM on the start day of a timed event, else ""
proc ::tical::event::_entry {ev part time} {
    return [dict merge $ev [dict create part $part time $time]]
}

# Put events (list of event dicts, any accepted form) into the `events` of
# the cells (each cell a dict with `date`). Events spanning several days
# appear in every touched cell. Returns the new cell list.
proc ::tical::event::distribute {cells events {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    set byDate [dict create]
    foreach ev $events {
        set ev [normalize $ev]
        set ds [days $ev $tz]
        set n [llength $ds]
        set time ""
        if {![dict get $ev allday]} {
            set time [lindex [toLocal [dict get $ev dtstart] $tz] 1]
        }
        set i 0
        foreach d $ds {
            if {$n == 1} {
                set part single
            } elseif {$i == 0} {
                set part start
            } elseif {$i == $n - 1} {
                set part end
            } else {
                set part middle
            }
            set t [expr {$part in {single start} ? $time : ""}]
            dict lappend byDate $d [list $t [_entry $ev $part $t]]
            incr i
        }
    }
    set out {}
    foreach c $cells {
        set d [expr {[dict exists $c date] ? [dict get $c date] : ""}]
        if {$d ne "" && [dict exists $byDate $d]} {
            set have [expr {[dict exists $c events] ? [dict get $c events] : {}}]
            # all-day and continuing entries first, then by start time
            foreach p [lsort -index 0 [dict get $byDate $d]] {
                lappend have [lindex $p 1]
            }
            dict set c events $have
        }
        lappend out $c
    }
    return $out
}
