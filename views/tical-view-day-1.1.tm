package require tical::core 1.0
package require tical::config 1.0
package require tical::util 1.1
package require tical::event 1.1

package provide tical::view::day 1.1
package require Tcl 8.6-

namespace eval tical::view::day {
    namespace export getData validate
}

# Options (unknown ones are an error, errorcode {TICAL VIEW OPTION}):
#   -date (required), -tz, -holidays REGION, -hourStart, -hourEnd, -events LIST
# Events: the ViewSpec key `events` lists every event touching the day
# (all-day ones included); each hour cell lists the timed events running in
# that hour (part start/middle/end/single as in the month and week views).
proc tical::view::day::getData {args} {
    array set o [::tical::util::options view::day::getData {
        -date {} -tz {} -holidays {} -hourStart 0 -hourEnd 23 -events {}
    } $args {TICAL VIEW OPTION}]

    if {$o(-date) eq {}} {
        return -code error -errorcode {TICAL VIEW ARGS} \
            "view::day::getData: -date is required"
    }
    foreach k {-hourStart -hourEnd} {
        if {![string is integer -strict $o($k)] || $o($k) < 0 || $o($k) > 23} {
            return -code error -errorcode {TICAL VIEW OPTION} \
                "view::day::getData: $k must be an integer 0..23, got \"$o($k)\""
        }
    }

    if {$o(-tz) eq {}} {
        set o(-tz) [tical::config::get timezone]
    }
    set tz $o(-tz)

    set ts [clock scan $o(-date) -format "%Y-%m-%d" -timezone $tz]
    set year [clock format $ts -format %Y -timezone $tz]
    set month [scan [clock format $ts -format %m -timezone $tz] %d]
    set day [scan [clock format $ts -format %d -timezone $tz] %d]
    set dow [clock format $ts -format %u -timezone $tz]
    set week [scan [clock format $ts -format %V -timezone $tz] %d]

    set todayStr [clock format [clock seconds] -format %Y-%m-%d -timezone $tz]
    set isToday [expr {$o(-date) eq $todayStr}]

    set isHoliday 0
    if {$o(-holidays) ne {}} {
        if {[catch {package require tical::holidays 1.0}] == 0} {
            set holidays [tical::holidays::getHolidays $o(-holidays) $year $month]
            if {[dict exists $holidays $day]} {
                set isHoliday 1
            }
        }
    }

    # events of the day; timed ones also per hour
    set dayEvents {}
    set byHour [dict create]
    if {[llength $o(-events)]} {
        set dayEvents [dict get [lindex [::tical::event::distribute \
            [list [dict create date $o(-date) events {}]] $o(-events) $tz] 0] events]
        set dayStart [clock scan "$o(-date) 00:00:00" -timezone $tz]
        set dayEnd   [clock add $dayStart 1 day -timezone $tz]
        foreach ev $dayEvents {
            if {[dict get $ev allday]} continue
            lassign [::tical::event::epochs $ev $tz] s0 e0
            if {$e0 <= $s0} {
                # no duration: the hour it starts in
                set hours [list [scan [clock format $s0 -format %H -timezone $tz] %d]]
            } else {
                set s [expr {max($s0, $dayStart)}]
                set e [expr {min($e0, $dayEnd)}]
                if {$e <= $s} continue
                set h1 [scan [clock format $s -format %H -timezone $tz] %d]
                set h2 [scan [clock format [expr {$e - 1}] -format %H -timezone $tz] %d]
                set hours {}
                for {set h $h1} {$h <= $h2} {incr h} { lappend hours $h }
            }
            foreach h $hours {
                # part relative to the hours: starts / ends in this hour?
                set hs [clock scan "$o(-date) [format %02d $h]:00:00" -timezone $tz]
                set he [expr {$hs + 3600}]
                set starts [expr {$s0 >= $hs && $s0 < $he}]
                set ends   [expr {$e0 <= $s0 || ($e0 > $hs && $e0 <= $he)}]
                set part [expr {$starts && $ends ? "single"
                    : ($starts ? "start" : ($ends ? "end" : "middle"))}]
                dict lappend byHour $h [dict replace $ev part $part \
                    time [expr {$starts ? [dict get $ev time] : ""}]]
            }
        }
    }

    set cells {}
    for {set hour $o(-hourStart)} {$hour <= $o(-hourEnd)} {incr hour} {
        set markers {}
        if {$isToday} {
            lappend markers "today"
        }
        if {$isHoliday} {
            lappend markers "holiday"
        }
        set evs [expr {[dict exists $byHour $hour] ? [dict get $byHour $hour] : {}}]
        lappend cells [dict create \
            hour $hour \
            time "[format %02d $hour]:00" \
            date $o(-date) \
            markers $markers \
            events $evs]
    }

    return [dict create \
        type "day-grid" \
        date $o(-date) \
        year $year \
        month $month \
        day $day \
        dow $dow \
        week $week \
        hourStart $o(-hourStart) \
        hourEnd $o(-hourEnd) \
        hours [expr {$o(-hourEnd) - $o(-hourStart) + 1}] \
        rows [expr {$o(-hourEnd) - $o(-hourStart) + 1}] \
        events $dayEvents \
        cells $cells]
}

proc tical::view::day::validate {viewSpec} {
    foreach k {type date year month day dow week hours rows cells} {
        if {![dict exists $viewSpec $k]} {
            return -code error -errorcode {TICAL VIEW SPEC} "ViewSpec missing field: $k"
        }
    }
    if {[dict get $viewSpec type] ne "day-grid"} {
        return -code error -errorcode {TICAL VIEW TYPE} \
            "ViewSpec type must be day-grid, got \"[dict get $viewSpec type]\""
    }
    return 1
}
