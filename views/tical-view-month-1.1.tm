package require tical::core 1.1
package require tical::config 1.0
package require tical::util 1.1
package require tical::event 1.1

package provide tical::view::month 1.1
package require Tcl 8.6-

namespace eval tical::view::month {
    namespace export getData validate
}

# Days between the 1st of the month and the first grid column.
proc ::tical::view::month::_firstCellOffset {y m weekStart tz} {
    set firstTs [clock scan "$y-$m-01 12:00:00" -timezone $tz]
    set dow     [clock format $firstTs -format %u -timezone $tz] ;# 1..7 (Mon=1)
    set startIx [::tical::util::weekStartDow $weekStart {TICAL VIEW OPTION}]
    return [expr {($dow - $startIx + 7) % 7}]
}

# Options (unknown ones are an error, errorcode {TICAL VIEW OPTION}):
#   -year -month (required), -tz, -weekStart mon|sun, -firstWeek iso|simple|us,
#   -showAdjacentDays 0|1, -count N, -holidays REGION, -events LIST
proc tical::view::month::getData {args} {
    set o [::tical::util::options view::month::getData {
        -year {} -month {} -tz {} -weekStart {} -firstWeek {}
        -showAdjacentDays 1 -count 1 -holidays {} -events {}
    } $args {TICAL VIEW OPTION}]
    if {[dict get $o -year] eq {} || [dict get $o -month] eq {}} {
        return -code error -errorcode {TICAL VIEW ARGS} \
            "view::month::getData: -year and -month are required"
    }
    # -count N (N > 1): list of N consecutive month ViewSpecs, starting at
    # -year/-month (rolls over into the following year). -count 1 (default)
    # returns a single ViewSpec.
    set count [dict get $o -count]
    if {![string is integer -strict $count] || $count < 1} {
        return -code error -errorcode {TICAL VIEW COUNT} \
            "view::month::getData: -count must be an integer >= 1, got \"$count\""
    }
    if {$count > 1} {
        set y [scan [dict get $o -year] %d]
        set m [scan [dict get $o -month] %d]
        set specs {}
        for {set i 0} {$i < $count} {incr i} {
            lappend specs [getData {*}[dict replace $o -year $y -month $m -count 1]]
            if {[incr m] > 12} { set m 1; incr y }
        }
        return $specs
    }

    if {[dict get $o -tz] eq {}}        { dict set o -tz        [tical::config::get timezone] }
    if {[dict get $o -weekStart] eq {}} { dict set o -weekStart [tical::config::get weekstart] }
    if {[dict get $o -firstWeek] eq {}} { dict set o -firstWeek [tical::config::get firstweek] }
    set tz [dict get $o -tz]
    set weekStart [expr {[::tical::util::weekStartDow [dict get $o -weekStart] {TICAL VIEW OPTION}] == 7 ? "sun" : "mon"}]
    set firstWeek [dict get $o -firstWeek]
    if {$firstWeek ni {iso simple us}} {
        return -code error -errorcode {TICAL VIEW OPTION} \
            "view::month::getData: bad -firstWeek \"$firstWeek\": must be iso, simple or us"
    }

    # holidays (optional)
    set holidayDict {}
    if {[dict get $o -holidays] ne {}} {
        if {[catch {package require tical::holidays 1.0}]} {
            puts stderr "Warning: tical::holidays not available"
        } else {
            set holidayDict [tical::holidays::getHolidays [dict get $o -holidays] \
                [dict get $o -year] [dict get $o -month]]
        }
    }

    set y [dict get $o -year]
    set m [format %02d [scan [dict get $o -month] %d]]

    set cal  [tical::core::calendarData -year $y -month $m -tz $tz \
        -weekStart $weekStart -firstWeek $firstWeek]
    set days [dict get $cal days]

    # 6x7 cells, filled with days of the adjacent months
    set cols 7; set rows 6; set cells {}
    set offs [_firstCellOffset $y $m $weekStart $tz]
    set adjacent [dict get $o -showAdjacentDays]

    # lead-in (before the 1st)
    if {$adjacent} {
        set prevFirst [clock add [clock scan "$y-$m-01" -timezone $tz] -1 month]
        set py        [clock format $prevFirst -format %Y -timezone $tz]
        set pm        [format %02d [scan [clock format $prevFirst -format %m -timezone $tz] %d]]
        set plastTs   [clock add [clock scan "$py-$pm-01" -timezone $tz] 1 month -1 day]
        set plastDay  [scan [clock format $plastTs -format %d -timezone $tz] %d]
        for {set i $offs} {$i > 0} {incr i -1} {
            set d [expr {$plastDay - $i + 1}]
            lappend cells [_adjCell "$py-$pm-[format %02d $d]" $tz $firstWeek]
        }
    } else {
        for {set i 0} {$i < $offs} {incr i} {
            lappend cells [dict create date {} inMonth 0 dow {} week {} markers {} events {}]
        }
    }

    # days of the month
    foreach rec $days {
        set markerList {}
        if {[dict get $rec isToday]} {
            lappend markerList "today"
        }
        set date [dict get $rec date]
        set day [scan [lindex [split $date -] 2] %d]
        if {[dict exists $holidayDict $day]} {
            lappend markerList "holiday"
        }
        lappend cells [dict merge $rec [dict create inMonth 1 markers $markerList]]
    }

    # run-out
    set need [expr {$rows*$cols - [llength $cells]}]
    if {$need > 0} {
        if {$adjacent} {
            set nextFirst [clock add [clock scan "$y-$m-01" -timezone $tz] 1 month]
            set ny        [clock format $nextFirst -format %Y -timezone $tz]
            set nm        [format %02d [scan [clock format $nextFirst -format %m -timezone $tz] %d]]
            for {set d 1} {$d <= $need} {incr d} {
                lappend cells [_adjCell "$ny-$nm-[format %02d $d]" $tz $firstWeek]
            }
        } else {
            for {set i 0} {$i < $need} {incr i} {
                lappend cells [dict create date {} inMonth 0 dow {} week {} markers {} events {}]
            }
        }
    }

    # events (all cells with a date, adjacent days included)
    if {[llength [dict get $o -events]]} {
        set cells [::tical::event::distribute $cells [dict get $o -events] $tz]
    }

    set spec [dict create \
        type   month-grid \
        month  [scan $m %d] \
        year   $y \
        cols   $cols \
        rows   $rows \
        weekStart $weekStart \
        firstWeek $firstWeek \
        cells  $cells \
        legend {markers {{today ●} {holiday ▲} {event ○}}} \
        grid   {cols 7 rows 6 gutter 2 padding 1}]
    return $spec
}

proc ::tical::view::month::_adjCell {date tz firstWeek} {
    set ts [clock scan "$date 12:00:00" -timezone $tz]
    return [dict create date $date inMonth 0 \
        dow [clock format $ts -format %u -timezone $tz] \
        week [format %02d [::tical::core::weekNumber $ts $tz $firstWeek]] \
        markers {} events {}]
}

proc tical::view::month::validate {viewSpec} {
    foreach k {type month year cols rows cells} {
        if {![dict exists $viewSpec $k]} {
            return -code error -errorcode {TICAL VIEW SPEC} "ViewSpec missing field: $k"
        }
    }
    if {[dict get $viewSpec type] ne "month-grid"} {
        return -code error -errorcode {TICAL VIEW TYPE} \
            "ViewSpec type must be month-grid, got \"[dict get $viewSpec type]\""
    }
    return 1
}
