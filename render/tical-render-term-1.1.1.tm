package provide tical::render::term 1.1.1
package require Tcl 8.6-
package require tical::locale 1.0
package require tical::util 1.1

namespace eval tical::render::term {
    namespace export print
}

# A ViewSpec as plain text, returned as a string: month-grid as a grid,
# week-grid and day-grid as lists (see _week and _day below).
#
# Month grid (7 columns x 6 rows):
# Every column is four characters wide (monospaced):
#   " 17 "  day             "[17]"  today (with -color 1)
#   "(18)"  holiday         " 17*"  day with events (cell `events` of the view)
#   "[17*" / "(18*"         today / holiday with events
#   "  3 ", " [3]", " (3)", "  3*"  one-digit days (brackets hug the number)
#   " .. "  adjacent day    "  . "  empty cell (-showAdjacentDays 0)
# Today wins over holiday. Options:
#   -color 0|1        mark today (default 0, so output is reproducible)
#   -weekNumbers 0|1  week numbers in a first column (label from tical::locale);
#                     month only (the week list names its week in the title)
#   -weekStart mon|sun  check only: the week start comes from the view; a
#                     value that contradicts the view is an error
#                     {TICAL RENDER WEEKSTART}; no effect on a day view
# Unknown options: error {TICAL RENDER OPTION}; other view types: error
# {TICAL RENDER TYPE}.
proc tical::render::term::print {viewSpec args} {
    set o [::tical::util::options render::term::print \
        {-color 0 -weekNumbers 0 -weekStart {}} $args {TICAL RENDER OPTION}]
    set t [expr {[dict exists $viewSpec type] ? [dict get $viewSpec type] : ""}]
    if {$t ni {month-grid week-grid day-grid}} {
        return -code error -errorcode {TICAL RENDER TYPE} \
            "render::term::print: expected type month-grid, week-grid or day-grid, got \"$t\""
    }
    if {$t eq "day-grid"} { return [_day $viewSpec [dict get $o -color]] }
    set cells [dict get $viewSpec cells]
    set startDow [::tical::util::gridStartDow $cells]

    # -weekStart: accepted when it matches the view, error otherwise
    set ws [dict get $o -weekStart]
    if {$ws ne ""} {
        set want [::tical::util::weekStartDow $ws {TICAL RENDER OPTION}]
        if {$want != $startDow} {
            set have [expr {$startDow == 7 ? "sun" : ($startDow == 1 ? "mon" : $startDow)}]
            return -code error -errorcode {TICAL RENDER WEEKSTART} \
                "render::term::print: -weekStart $ws contradicts the view (starts on $have):\
                week start comes from the view; use getData ... -weekStart $ws"
        }
    }
    if {$t eq "week-grid"} { return [_week $viewSpec [dict get $o -color]] }
    set month [dict get $viewSpec month]
    set year  [dict get $viewSpec year]
    set weekNumbers [dict get $o -weekNumbers]
    set color [dict get $o -color]

    # header: month and weekday names from tical::locale (follows
    # tical::config locale), column order from the cells of the view
    set head ""
    if {$weekNumbers} {
        append head [format "%3s " [::tical::locale::getWeekLabel short]]
    }
    foreach wd [::tical::locale::getWeekdaysShort $startDow] {
        append head [format " %-2s " $wd]
    }
    set out ""
    append out [format " %s %d" [::tical::locale::getMonthName $month] $year] \n
    append out [string trimright $head] \n

    set line ""
    for {set i 0} {$i < [llength $cells]} {incr i} {
        set rec [lindex $cells $i]
        set date [dict get $rec date]

        # week number at the start of the row (tical::util::rowWeek)
        if {$weekNumbers && $i % 7 == 0} {
            set week [::tical::util::rowWeek $cells $i]
            if {$week ne ""} {
                append line [format "%3d " [scan $week %d]]
            } else {
                append line "    "
            }
        }

        if {$date eq {}} {
            set cell "  . "
        } elseif {![dict get $rec inMonth]} {
            set cell " .. "
        } else {
            set d [scan [string range $date 8 9] %d]
            set markers [expr {[dict exists $rec markers] ? [dict get $rec markers] : {}}]
            set isToday [expr {"today" in $markers
                || ([dict exists $rec isToday] && [dict get $rec isToday])}]
            set hasEvents [expr {[dict exists $rec events] && [llength [dict get $rec events]]}]
            if {$color && $isToday} {
                set l "\["; set r "\]"
            } elseif {"holiday" in $markers} {
                set l "("; set r ")"
            } else {
                set l " "; set r " "
            }
            if {$hasEvents} { set r "*" }
            # brackets hug the number, digits stay right-aligned: " (3)", "(18)"
            set cell [format %4s $l$d$r]
        }
        append line $cell
        if {($i+1) % 7 == 0} {
            append out [string trimright $line] \n
            set line ""
        }
    }
    return $out
}

# --- week and day lists -----------------------------------------------------
#
# Week: title "<week label> <n> <year>", then one line per day; a day label
# is " Mo 13 Okt " (weekday and month names from tical::locale), "(Fr 03 Okt)"
# for a holiday, "[Di 14 Okt]" for today (with -color 1; today wins). Events
# follow the label, one per line: "HH:MM summary" for timed events, the
# summary alone for all-day events, ".. summary" where an event started on an
# earlier day.
#
#    KW 42 2025
#    Mo 13 Okt   09:00 Zahnarzt
#                18:00 Training
#   [Di 14 Okt]
#   (Fr 17 Okt)  Urlaub
#
# Day: title like a week line with the year, all-day events below it, then
# one line per hour "HH:00 |" with the events starting in that hour
# ("HH:MM summary") or running on ("| .. summary" in the first hour of the
# view only, so a long event does not fill every line).

# One event entry of a cell as text
proc tical::render::term::_entry {ev} {
    set sum [expr {[dict exists $ev summary] ? [dict get $ev summary] : ""}]
    set part [expr {[dict exists $ev part] ? [dict get $ev part] : "single"}]
    set time [expr {[dict exists $ev time] ? [dict get $ev time] : ""}]
    if {$part in {middle end}} { return ".. $sum" }
    if {$time ne ""} { return "$time $sum" }
    return $sum
}

# " Mo 13 Okt ", "(Fr 17 Okt)", "[Di 14 Okt]"
proc tical::render::term::_dayLabel {date markers color {withYear 0}} {
    scan $date %d-%d-%d y m d
    set t [clock scan $date -format %Y-%m-%d -gmt 1]
    set dow [clock format $t -format %u -gmt 1]
    set mon [::tical::locale::getMonthName $m short]
    set txt [format "%s %02d %s" [::tical::locale::getWeekdayName $dow short] $d $mon]
    if {$withYear} { append txt " $y" }
    if {$color && "today" in $markers} { return "\[$txt\]" }
    if {"holiday" in $markers} { return "($txt)" }
    return " $txt "
}

proc tical::render::term::_week {spec color} {
    set out [format " %s %d %d" [::tical::locale::getWeekLabel long] \
        [scan [dict get $spec week] %d] [dict get $spec year]]
    append out \n
    set labels {}
    foreach c [dict get $spec cells] {
        set markers [expr {[dict exists $c markers] ? [dict get $c markers] : {}}]
        if {[dict exists $c isToday] && [dict get $c isToday]} { lappend markers today }
        lappend labels [_dayLabel [dict get $c date] $markers $color]
    }
    set w 0
    foreach l $labels { set w [expr {max($w, [string length $l])}] }
    set pad [string repeat " " [expr {$w + 1}]]
    foreach c [dict get $spec cells] l $labels {
        set evs [expr {[dict exists $c events] ? [dict get $c events] : {}}]
        if {![llength $evs]} {
            append out [string trimright $l] \n
            continue
        }
        set first 1
        foreach ev $evs {
            set head [expr {$first ? [format "%-*s " $w $l] : $pad}]
            append out [string trimright "$head [_entry $ev]"] \n
            set first 0
        }
    }
    return $out
}

proc tical::render::term::_day {spec color} {
    set cells [dict get $spec cells]
    set markers {}
    if {[llength $cells]} { set markers [dict get [lindex $cells 0] markers] }
    set out [string trimright [_dayLabel [dict get $spec date] $markers $color 1]]
    append out \n
    set evs [expr {[dict exists $spec events] ? [dict get $spec events] : {}}]
    foreach ev $evs {
        if {[dict exists $ev allday] && [dict get $ev allday]} {
            append out "       " [_entry $ev] \n
        }
    }
    set i 0
    foreach c $cells {
        set line "[dict get $c time] |"
        set parts {}
        foreach ev [dict get $c events] {
            set part [dict get $ev part]
            if {$part in {single start}} {
                lappend parts [_entry $ev]
            } elseif {$i == 0} {
                lappend parts ".. [dict get $ev summary]"
            }
        }
        if {![llength $parts]} {
            append out $line \n
        } else {
            append out "$line [lindex $parts 0]" \n
            foreach p [lrange $parts 1 end] { append out "      | $p" \n }
        }
        incr i
    }
    return $out
}
