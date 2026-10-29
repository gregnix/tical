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
#   tzid         optional time zone of local dtstart/dtend/exdate values
#                (iCalendar TZID: Europe/Berlin, also prefixed ids such as
#                /mozilla.org/.../Europe/Berlin and common Windows names such
#                as "W. Europe Standard Time"); epochs, days, distribute and
#                the views convert such times to the display zone. A TZID
#                Tcl does not know leaves the time as local time (see tzid).
# Other keys are kept unchanged.
#
# normalize also accepts ISO input (2025-10-14, 2025-10-14T09:00, 2025-10-14
# 09:00:00Z) and, for one version, the older field names:
#   title -> summary, date + startTime/endTime -> dtstart/dtend (tical::model),
#   starts_at/ends_at -> dtstart/dtend (tical::adapter::sqlite),
#   allDay -> allday, category -> categories, id -> uid.

package require Tcl 8.6-
package require tical::util 1.0

package provide tical::event 1.1.1

namespace eval ::tical::event {
    namespace export normalize validate normalizeValue valueKind \
        toLocal epochs days distribute rrule rruleString tzid expand
    variable legacy {title date startTime endTime starts_at ends_at allDay category id}
    variable tzCache
    array set tzCache {}
    # Windows time zone names (Outlook, Exchange) -> IANA
    variable windowsZones {
        {W. Europe Standard Time} Europe/Berlin
        {Central Europe Standard Time} Europe/Budapest
        {Central European Standard Time} Europe/Warsaw
        {Romance Standard Time} Europe/Paris
        {GMT Standard Time} Europe/London
        {Greenwich Standard Time} Atlantic/Reykjavik
        {E. Europe Standard Time} Europe/Chisinau
        {FLE Standard Time} Europe/Kiev
        {GTB Standard Time} Europe/Bucharest
        {Russian Standard Time} Europe/Moscow
        {Turkey Standard Time} Europe/Istanbul
        {UTC} UTC
        {Coordinated Universal Time} UTC
        {Eastern Standard Time} America/New_York
        {Central Standard Time} America/Chicago
        {Mountain Standard Time} America/Denver
        {Pacific Standard Time} America/Los_Angeles
        {Tokyo Standard Time} Asia/Tokyo
        {China Standard Time} Asia/Shanghai
        {India Standard Time} Asia/Kolkata
        {AUS Eastern Standard Time} Australia/Sydney
    }
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

# A date as YYYY-MM-DD (input ISO or basic form), else an error with
# errorcode code; for the -date options of the views.
proc ::tical::event::_isoDate {v who code} {
    if {[catch {normalizeValue $v} n] || [string length $n] != 8} {
        return -code error -errorcode $code \
            "$who: -date must be a date (YYYY-MM-DD or YYYYMMDD), got \"$v\""
    }
    return "[string range $n 0 3]-[string range $n 4 5]-[string range $n 6 7]"
}

# date | local | utc (value in basic form)
proc ::tical::event::valueKind {v} {
    if {[string length $v] == 8} { return date }
    if {[string index $v end] eq "Z"} { return utc }
    return local
}

# Epoch of a basic-form value. date values are read in tz, local values in
# src (default tz), UTC values as UTC.
proc ::tical::event::_epoch {v tz {src {}}} {
    if {$src eq {}} { set src $tz }
    switch -- [valueKind $v] {
        date  { return [clock scan "$v 000000" -format "%Y%m%d %H%M%S" -timezone $tz] }
        utc   { return [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1] }
        local { return [clock scan $v -format %Y%m%dT%H%M%S -timezone $src] }
    }
}

# Tcl time zone (":Europe/Berlin") for an iCalendar TZID, "" when Tcl does
# not know it. Accepts IANA names, prefixed ids (/mozilla.org/.../Europe/Berlin)
# and common Windows names ("W. Europe Standard Time").
proc ::tical::event::tzid {name} {
    variable tzCache
    variable windowsZones
    set n [string trim $name "\" "]
    if {[info exists tzCache($n)]} { return $tzCache($n) }
    set cands {}
    if {$n ne ""} { lappend cands $n }
    if {[regexp {([A-Za-z]+/[A-Za-z_+-]+(?:/[A-Za-z_+-]+)?)$} $n -> tail] && $tail ne $n} {
        lappend cands $tail
    }
    if {[dict exists $windowsZones $n]} { lappend cands [dict get $windowsZones $n] }
    set result ""
    foreach c $cands {
        if {[regexp {^[A-Za-z][A-Za-z0-9_+/-]*$} $c]
                && ![catch {clock format 0 -timezone :$c}]} {
            set result :$c
            break
        }
    }
    set tzCache($n) $result
    return $result
}

# Zone the local values of an event are in: its tzid when Tcl knows it, else tz.
proc ::tical::event::_src {ev tz} {
    if {[dict exists $ev tzid] && [dict get $ev tzid] ne ""} {
        set z [tzid [dict get $ev tzid]]
        if {$z ne ""} { return $z }
    }
    return $tz
}

# Local date and time of a value: {YYYY-MM-DD HH:MM}; time is "" for dates.
# tzid: zone of a local value (iCalendar TZID); default: the value is in tz.
proc ::tical::event::toLocal {v {tz {}} {tzid {}}} {
    if {$tz eq {}} { set tz [_tz] }
    set v [normalizeValue $v]
    if {[valueKind $v] eq "date"} {
        return [list "[string range $v 0 3]-[string range $v 4 5]-[string range $v 6 7]" ""]
    }
    set src $tz
    if {$tzid ne "" && [set z [tzid $tzid]] ne ""} { set src $z }
    set e [_epoch $v $tz $src]
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
        if {$ks ne $ke && $ks ne "date" && $ke ne "date"} {
            # one UTC, one local: compare as points in time (local in the
            # zone of tzid, else the display zone)
            set z [_src $ev [_tz]]
            if {[_epoch $e $z] < [_epoch $s $z]} {
                return -code error -errorcode {TICAL EVENT RANGE} \
                    "dtend \"$e\" is before dtstart \"$s\""
            }
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
        _checkRrule $r
    }
    return 1
}

# Values of the rrule parts tical writes and reads. Error {TICAL EVENT RRULE}.
proc ::tical::event::_checkRrule {r} {
    set bad {{part v must} {
        return -code error -level 2 -errorcode {TICAL EVENT RRULE} \
            "rrule $part \"$v\": must be $must"
    }}
    foreach part {interval count} {
        if {[dict exists $r $part]} {
            set v [dict get $r $part]
            if {![string is integer -strict $v] || $v < 1} {
                apply $bad $part $v "an integer >= 1"
            }
        }
    }
    if {[dict exists $r until]} {
        set v [dict get $r until]
        if {[catch {normalizeValue $v until}]} {
            apply $bad until $v "a date or date-time (YYYYMMDD, YYYYMMDDTHHMMSS, ...Z)"
        }
    }
    if {[dict exists $r byday]} {
        foreach v [dict get $r byday] {
            if {![regexp {^([+-]?)(\d{0,2})(MO|TU|WE|TH|FR|SA|SU)$} [string toupper $v] -> s n]
                    || ($n ne "" && ([scan $n %d] < 1 || [scan $n %d] > 53))} {
                apply $bad byday $v "MO..SU, optionally with a number (1MO, -1FR)"
            }
        }
    }
    if {[dict exists $r bymonth]} {
        foreach v [dict get $r bymonth] {
            if {![string is integer -strict $v] || $v < 1 || $v > 12} {
                apply $bad bymonth $v "1..12"
            }
        }
    }
    if {[dict exists $r bymonthday]} {
        foreach v [dict get $r bymonthday] {
            if {![string is integer -strict $v] || $v == 0 || abs($v) > 31} {
                apply $bad bymonthday $v "1..31 or -31..-1"
            }
        }
    }
    if {[dict exists $r wkst] && [string toupper [dict get $r wkst]] ni {MO TU WE TH FR SA SU}} {
        apply $bad wkst [dict get $r wkst] "MO..SU"
    }
}

# --- recurrence ---------------------------------------------------------
#
# Expands the rrule subset tical writes and reads: FREQ DAILY, WEEKLY,
# MONTHLY, YEARLY with INTERVAL, COUNT, UNTIL, BYDAY (weekdays; with an
# ordinal such as 1MO or -1FR for MONTHLY and YEARLY), BYMONTH, BYMONTHDAY
# (negative from the month end) and WKST. Other parts (BYSETPOS, BYWEEKNO,
# BYYEARDAY, BYHOUR ...) are an error {TICAL EVENT RRULE}. Pure Tcl, no
# tclutils. Calendar arithmetic on day numbers, the time of day of dtstart
# kept: a series stays at its wall-clock time (in its tzid, or floating).

# Julian day number of a date and back; weekday 1 = Monday .. 7 = Sunday
proc ::tical::event::_jdn {y m d} {
    set a [expr {(14 - $m) / 12}]
    set yy [expr {$y + 4800 - $a}]
    set mm [expr {$m + 12 * $a - 3}]
    return [expr {$d + (153 * $mm + 2) / 5 + 365 * $yy + $yy / 4 - $yy / 100 + $yy / 400 - 32045}]
}

proc ::tical::event::_ymd {j} {
    set a [expr {$j + 32044}]
    set b [expr {(4 * $a + 3) / 146097}]
    set c [expr {$a - 146097 * $b / 4}]
    set d [expr {(4 * $c + 3) / 1461}]
    set e [expr {$c - 1461 * $d / 4}]
    set m [expr {(5 * $e + 2) / 153}]
    return [list [expr {100 * $b + $d - 4800 + $m / 10}] \
                 [expr {$m + 3 - 12 * ($m / 10)}] \
                 [expr {$e - (153 * $m + 2) / 5 + 1}]]
}

proc ::tical::event::_dow {j} { return [expr {$j % 7 + 1}] }

proc ::tical::event::_monthLen {y m} {
    if {$m == 12} { return [expr {[_jdn [expr {$y + 1}] 1 1] - [_jdn $y 12 1]}] }
    return [expr {[_jdn $y [expr {$m + 1}] 1] - [_jdn $y $m 1]}]
}

# byday list -> list of {ordinal dow}; ordinal "" for every such weekday
proc ::tical::event::_bydays {list} {
    set out {}
    foreach v $list {
        regexp {^([+-]?\d*)(MO|TU|WE|TH|FR|SA|SU)$} [string toupper $v] -> n wd
        set n [expr {$n eq "" || $n eq "+" || $n eq "-" ? "" : [scan $n %d]}]
        lappend out [list $n [expr {[lsearch {MO TU WE TH FR SA SU} $wd] + 1}]]
    }
    return $out
}

# Days (day numbers) first .. first+len-1 matching the bydays; an ordinal
# counts within that span (month or year)
proc ::tical::event::_pickDays {first len bydays} {
    set out {}
    foreach bd $bydays {
        lassign $bd n wd
        set all {}
        set j [expr {$first + ($wd - [_dow $first] + 7) % 7}]
        for {} {$j < $first + $len} {incr j 7} { lappend all $j }
        if {$n eq ""} {
            lappend out {*}$all
        } elseif {$n > 0 && $n <= [llength $all]} {
            lappend out [lindex $all [expr {$n - 1}]]
        } elseif {$n < 0 && -$n <= [llength $all]} {
            lappend out [lindex $all end-[expr {-$n - 1}]]
        }
    }
    return $out
}

# Candidate days of one month
proc ::tical::event::_monthDays {y m r d0} {
    set first [_jdn $y $m 1]
    set len [_monthLen $y $m]
    set out {}
    if {[dict exists $r bymonthday]} {
        foreach v [dict get $r bymonthday] {
            set dd [expr {$v > 0 ? $v : $len + $v + 1}]
            if {$dd >= 1 && $dd <= $len} { lappend out [expr {$first + $dd - 1}] }
        }
        if {[dict exists $r byday]} {
            set wds [lmap bd [_bydays [dict get $r byday]] {lindex $bd 1}]
            set out [lmap j $out {expr {[_dow $j] in $wds ? $j : [continue]}}]
        }
    } elseif {[dict exists $r byday]} {
        set out [_pickDays $first $len [_bydays [dict get $r byday]]]
    } elseif {$d0 <= $len} {
        set out [list [expr {$first + $d0 - 1}]]
    }
    return $out
}

# Occurrence values (basic form, same kind as start) of a series from start
# up to the day toDay (YYYYMMDD) or the end of the rule. src: zone of a local
# start, used for a UNTIL in UTC. fromDay (YYYYMMDD, optional): without
# COUNT, periods ending before it are skipped (values before it may still
# come back).
proc ::tical::event::_occurrences {start r toDay src {fromDay {}}} {
    foreach k [dict keys $r] {
        if {$k ni {freq interval count until byday bymonth bymonthday wkst}} {
            return -code error -errorcode {TICAL EVENT RRULE} \
                "unsupported rule part: [string toupper $k]"
        }
    }
    set kind [valueKind $start]
    scan [string range $start 0 7] %4d%2d%2d y0 m0 d0
    set time ""
    if {$kind ne "date"} { set time [string range $start 9 14] }
    set zsuf [expr {$kind eq "utc" ? "Z" : ""}]
    set freq [dict get $r freq]
    set interval [expr {[dict exists $r interval] ? [dict get $r interval] : 1}]
    set count [expr {[dict exists $r count] ? [dict get $r count] : 0}]
    set until ""
    if {[dict exists $r until]} {
        set until [normalizeValue [dict get $r until] until]
        if {$kind eq "date"} {
            set until [string range $until 0 7]
        } else {
            if {[string length $until] == 8} { append until T235959 }
            if {$kind eq "local" && [string index $until end] eq "Z"} {
                set t [clock scan [string range $until 0 end-1] -format %Y%m%dT%H%M%S -gmt 1]
                set until [clock format $t -format %Y%m%dT%H%M%S -timezone $src]
            }
            set until [string trimright $until Z]
        }
    }
    set months [expr {[dict exists $r bymonth] ? [lmap v [dict get $r bymonth] {scan $v %d}] : {}}]
    set sj [_jdn $y0 $m0 $d0]
    scan $toDay %4d%2d%2d ty tm td
    set toJ [_jdn $ty $tm $td]
    if {$freq eq "WEEKLY" && [dict exists $r bymonthday]} {
        return -code error -errorcode {TICAL EVENT RRULE} \
            "unsupported rule part: BYMONTHDAY with FREQ=WEEKLY"
    }
    # DTSTART counts only when it matches the rule (as tclutils::turrule)
    set out {}
    set n 0
    set wkst [expr {[dict exists $r wkst]
        ? [lsearch {MO TU WE TH FR SA SU} [string toupper [dict get $r wkst]]] + 1 : 1}]
    set p0 0
    if {$fromDay ne "" && !$count} {
        scan $fromDay %4d%2d%2d fy fm fd
        set gap [expr {[_jdn $fy $fm $fd] - $sj}]
        if {$gap > 0} {
            set per [dict get {DAILY 1 WEEKLY 7 MONTHLY 28 YEARLY 365} $freq]
            set p0 [expr {max(0, $gap / ($per * $interval) - 2)}]
            # month and year periods are longer than 28 / 365 days: stay safe
            if {$freq eq "MONTHLY"} { set p0 [expr {max(0, ($gap / 31) / $interval - 2)}] }
            if {$freq eq "YEARLY"}  { set p0 [expr {max(0, ($gap / 366) / $interval - 2)}] }
        }
    }
    for {set p $p0} {1} {incr p} {
        switch -- $freq {
            DAILY {
                set base [expr {$sj + $p * $interval}]
                set cands [list $base]
                if {[dict exists $r bymonthday]} {
                    lassign [_ymd $base] cy cm cd
                    set len [_monthLen $cy $cm]
                    set ok 0
                    foreach v [dict get $r bymonthday] {
                        if {$cd == ($v > 0 ? $v : $len + $v + 1)} { set ok 1 }
                    }
                    if {!$ok} { set cands {} }
                }
                if {[dict exists $r byday]} {
                    set wds [lmap bd [_bydays [dict get $r byday]] {lindex $bd 1}]
                    if {[_dow $base] ni $wds} { set cands {} }
                }
            }
            WEEKLY {
                set ws [expr {$sj - ([_dow $sj] - $wkst + 7) % 7}]
                set base [expr {$ws + $p * 7 * $interval}]
                if {[dict exists $r byday]} {
                    set cands [lmap bd [_bydays [dict get $r byday]] {
                        expr {$base + ([lindex $bd 1] - $wkst + 7) % 7}
                    }]
                } else {
                    set cands [list [expr {$base + ([_dow $sj] - $wkst + 7) % 7}]]
                }
            }
            MONTHLY {
                set mi [expr {$y0 * 12 + $m0 - 1 + $p * $interval}]
                set cy [expr {$mi / 12}]; set cm [expr {$mi % 12 + 1}]
                set base [_jdn $cy $cm 1]
                set cands [_monthDays $cy $cm $r $d0]
            }
            YEARLY {
                set cy [expr {$y0 + $p * $interval}]
                set base [_jdn $cy 1 1]
                set cands {}
                if {[llength $months]} {
                    foreach cm $months { lappend cands {*}[_monthDays $cy $cm $r $d0] }
                } elseif {[dict exists $r bymonthday]} {
                    for {set cm 1} {$cm <= 12} {incr cm} {
                        lappend cands {*}[_monthDays $cy $cm $r $d0]
                    }
                } elseif {[dict exists $r byday]} {
                    set cands [_pickDays $base [expr {[_jdn [expr {$cy + 1}] 1 1] - $base}] \
                        [_bydays [dict get $r byday]]]
                } else {
                    set cands [_monthDays $cy $m0 [dict create] $d0]
                }
            }
        }
        if {$base > $toJ} break
        foreach j [lsort -integer -unique $cands] {
            if {$j < $sj || $j > $toJ} continue
            lassign [_ymd $j] cy cm cd
            if {[llength $months] && $cm ni $months} continue
            set v [format %04d%02d%02d $cy $cm $cd]
            if {$time ne ""} { append v T$time }
            if {$until ne "" && $v > $until} { return $out }
            lappend out $v$zsuf
            if {$count && [incr n] >= $count} { return $out }
        }
    }
    return $out
}

# Shift a basic-form value by secs (calendar arithmetic in UTC, so local
# and date values keep their wall-clock meaning).
proc ::tical::event::_shift {v secs} {
    switch -- [valueKind $v] {
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

proc ::tical::event::_secs {v} {
    switch -- [valueKind $v] {
        date  { return [clock scan $v -format %Y%m%d -gmt 1] }
        utc   { return [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1] }
        local { return [clock scan $v -format %Y%m%dT%H%M%S -gmt 1] }
    }
}

# A UTC value (...Z) as wall-clock time in zone src; other values unchanged.
proc ::tical::event::_wall {v src} {
    if {[valueKind $v] ne "utc"} { return $v }
    set t [clock scan [string range $v 0 end-1] -format %Y%m%dT%H%M%S -gmt 1]
    return [clock format $t -format %Y%m%dT%H%M%S -timezone $src]
}

proc ::tical::event::_isoDay {iso n} {
    set t [clock scan $iso -format %Y-%m-%d -gmt 1]
    return [clock format [clock add $t $n days -gmt 1] -format %Y-%m-%d -gmt 1]
}

# Events touching the days from..to (YYYY-MM-DD, inclusive) with series
# expanded: each occurrence is the event with its own dtstart/dtend, key
# recurrence-id and without rrule/exdate. EXDATE (also VALUE=DATE for a
# timed series, also in UTC) skips occurrences; an event with the same uid
# and a recurrence-id replaces its occurrence, with STATUS CANCELLED it
# removes it. Events without rrule pass when they touch the range. Sorted
# by start. Errors {TICAL EVENT RANGE|RRULE ...}.
proc ::tical::event::expand {events from to {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    foreach b {from to} {
        set v [normalizeValue [set $b] $b]
        if {[string length $v] != 8} {
            return -code error -errorcode {TICAL EVENT RANGE} \
                "range bounds must be dates (YYYY-MM-DD), got \"[set $b]\""
        }
        set $b "[string range $v 0 3]-[string range $v 4 5]-[string range $v 6 7]"
    }
    if {$to < $from} {
        return -code error -errorcode {TICAL EVENT RANGE} \
            "range end $to is before start $from"
    }
    set events [lmap ev $events {normalize $ev}]
    set overridden [dict create]
    foreach ev $events {
        if {[dict exists $ev recurrence-id] && [dict exists $ev uid]} {
            dict lappend overridden [dict get $ev uid] \
                [list [dict get $ev recurrence-id] [_src $ev $tz]]
        }
    }
    set out {}
    foreach ev $events {
        if {![dict exists $ev rrule] || [dict exists $ev recurrence-id]} {
            if {[dict exists $ev recurrence-id] && [dict exists $ev status]
                    && [string toupper [dict get $ev status]] eq "CANCELLED"} continue
            if {[_touchesRange $ev $from $to $tz]} { lappend out $ev }
            continue
        }
        set start [dict get $ev dtstart]
        set kind  [valueKind $start]
        set dur 0
        if {[dict exists $ev dtend]} {
            set dur [expr {[_secs [dict get $ev dtend]] - [_secs $start]}]
        }
        set src [_src $ev $tz]
        set skip {}
        set skipDays {}
        if {[dict exists $ev exdate]} {
            foreach x [dict get $ev exdate] {
                if {$kind ne "date" && [string length $x] == 8} {
                    lappend skipDays $x
                    continue
                }
                lappend skip [expr {$kind eq "local" ? [_wall $x $src] : $x}]
            }
        }
        if {[dict exists $ev uid] && [dict exists $overridden [dict get $ev uid]]} {
            foreach p [dict get $overridden [dict get $ev uid]] {
                lassign $p rid ridSrc
                lappend skip [expr {$kind eq "local" ? [_wall $rid $ridSrc] : $rid}]
            }
        }
        set toDay [string map {- {}} [_isoDay $to 2]]
        set base [dict remove $ev rrule exdate]
        set fromDay [string map {- {}} [_isoDay $from [expr {-$dur / 86400 - 2}]]]
        foreach v [_occurrences $start [dict get $ev rrule] $toDay $src $fromDay] {
            if {$v in $skip} continue
            if {[llength $skipDays]} {
                set day [expr {$kind eq "utc"
                    ? [clock format [_secs $v] -format %Y%m%d -timezone $src]
                    : [string range $v 0 7]}]
                if {$day in $skipDays} continue
            }
            set o [dict replace $base dtstart $v recurrence-id $v]
            if {[dict exists $ev dtend]} { dict set o dtend [_shift $v $dur] }
            if {[_touchesRange $o $from $to $tz]} { lappend out $o }
        }
    }
    set keyed [lmap ev $out {list [lindex [epochs $ev $tz] 0] $ev}]
    return [lmap p [lsort -integer -index 0 $keyed] {lindex $p 1}]
}

proc ::tical::event::_touchesRange {ev from to tz} {
    set ds [days $ev $tz]
    return [expr {[lindex $ds end] >= $from && [lindex $ds 0] <= $to}]
}

# --- placing events on days -------------------------------------------------

# {start end} epochs of an event in tz; end is exclusive. Without dtend: a
# timed event lasts 0 s, an all-day event one day. Local times of an event
# with tzid are read in that zone.
proc ::tical::event::epochs {ev {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    set src [_src $ev $tz]
    set s [_epoch [dict get $ev dtstart] $tz $src]
    if {[dict exists $ev dtend]} {
        set e [_epoch [dict get $ev dtend] $tz $src]
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
# appear in every touched cell; series (rrule) are expanded over the days of
# the cells (see expand). Returns the new cell list.
proc ::tical::event::distribute {cells events {tz {}}} {
    if {$tz eq {}} { set tz [_tz] }
    # series (rrule) and their overrides: expand over the days of the cells
    set series 0
    foreach ev $events {
        if {[dict exists $ev rrule] || [dict exists $ev recurrence-id]} { set series 1; break }
    }
    if {$series} {
        set dates [lsort [lmap c $cells {
            expr {[dict exists $c date] && [dict get $c date] ne "" ? [dict get $c date] : [continue]}
        }]]
        if {[llength $dates]} {
            set events [expand $events [lindex $dates 0] [lindex $dates end] $tz]
        }
    }
    set byDate [dict create]
    foreach ev $events {
        set ev [normalize $ev]
        set ds [days $ev $tz]
        set n [llength $ds]
        set time ""
        if {![dict get $ev allday]} {
            set time [clock format [lindex [epochs $ev $tz] 0] -format %H:%M -timezone $tz]
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
