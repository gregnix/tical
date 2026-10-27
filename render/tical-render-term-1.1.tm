package provide tical::render::term 1.1
package require Tcl 8.6-
package require tical::locale 1.0
package require tical::util 1.1

namespace eval tical::render::term {
    namespace export print
}

# Month grid as plain text (7 columns x 6 rows), returned as a string.
# Every column is four characters wide (monospaced):
#   " 17 "  day             "[17]"  today (with -color 1)
#   "(18)"  holiday         " 17*"  day with events (cell `events` of the view)
#   "[17*" / "(18*"         today / holiday with events
#   "  3 ", " [3]", " (3)", "  3*"  one-digit days (brackets hug the number)
#   " .. "  adjacent day    "  . "  empty cell (-showAdjacentDays 0)
# Today wins over holiday. Options:
#   -color 0|1        mark today (default 0, so output is reproducible)
#   -weekNumbers 0|1  week numbers in a first column (label from tical::locale)
#   -weekStart mon|sun  check only: the week start comes from the view; a
#                     value that contradicts the view is an error
#                     {TICAL RENDER WEEKSTART}
# Unknown options: error {TICAL RENDER OPTION}.
proc tical::render::term::print {viewSpec args} {
    set o [::tical::util::options render::term::print \
        {-color 0 -weekNumbers 0 -weekStart {}} $args {TICAL RENDER OPTION}]
    if {![dict exists $viewSpec type] || [dict get $viewSpec type] ne "month-grid"} {
        set t [expr {[dict exists $viewSpec type] ? [dict get $viewSpec type] : ""}]
        return -code error -errorcode {TICAL RENDER TYPE} \
            "render::term::print: expected type month-grid, got \"$t\""
    }
    set month [dict get $viewSpec month]
    set year  [dict get $viewSpec year]
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
