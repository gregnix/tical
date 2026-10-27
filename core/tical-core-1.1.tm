package provide tical::core 1.1
package require Tcl 8.6-

namespace eval tical::core {
    namespace export calendarData isLeap weekNumber
}

proc tical::core::isLeap {year} {
    expr {($year % 400 == 0) || (($year % 4 == 0) && ($year % 100 != 0))}
}

# Week number of a point in time (epoch) in timezone tz:
#   iso     ISO 8601: weeks start Monday, week 1 holds the first Thursday
#   simple  week 1 = January 1-7, week 2 = January 8-14, ...
#   us      weeks start Sunday, the week with January 1 is week 1
#           (weeks before the first Sunday count as week 1)
proc tical::core::weekNumber {ts tz {firstWeek iso}} {
    switch -- $firstWeek {
        iso {
            return [scan [clock format $ts -format %V -timezone $tz] %d]
        }
        simple {
            set doy [scan [clock format $ts -format %j -timezone $tz] %d]
            return [expr {($doy - 1) / 7 + 1}]
        }
        us {
            # %U: Sunday weeks, days before the first Sunday are week 0
            set u [scan [clock format $ts -format %U -timezone $tz] %d]
            set y [clock format $ts -format %Y -timezone $tz]
            set jan1 [clock scan "$y-01-01 12:00:00" -timezone $tz]
            set jan1Sunday [expr {[clock format $jan1 -format %u -timezone $tz] == 7}]
            return [expr {$jan1Sunday ? $u : $u + 1}]
        }
    }
    return -code error -errorcode {TICAL CORE FIRSTWEEK} \
        "bad firstWeek \"$firstWeek\": must be iso, simple or us"
}

# calendarData - CalendarData for one month
# Options: -year Y -month M -tz TZ -weekStart mon|sun -firstWeek iso|simple|us
proc tical::core::calendarData {args} {
    array set o {
        -year       {}
        -month      {}
        -tz         Europe/Berlin
        -weekStart  mon
        -firstWeek  iso
    }
    array set o $args
    if {$o(-year) eq {} || $o(-month) eq {}} {
        return -code error -errorcode {TICAL CORE ARGS} \
            "calendarData: -year and -month are required"
    }

    set y $o(-year)
    set m [format %02d [scan $o(-month) %d]]
    set first [clock scan "$y-$m-01 00:00:00" -timezone $o(-tz)]
    # last day of the month
    set lastTs  [clock add [clock add $first 1 month] -1 day]
    set lastDay [scan [clock format $lastTs -format %d -timezone $o(-tz)] %d]
    set days {}

    for {set d 1} {$d <= $lastDay} {incr d} {
        set ts   [clock scan "$y-$m-[format %02d $d] 12:00:00" -timezone $o(-tz)]
        set date [clock format $ts -format %Y-%m-%d -timezone $o(-tz)]
        # ISO weekday 1..7
        set dow  [clock format $ts -format %u -timezone $o(-tz)]
        # week number (two digits, as before) per -firstWeek
        set week [format %02d [weekNumber $ts $o(-tz) $o(-firstWeek)]]
        set isToday [expr {[clock format [clock seconds] -format %Y-%m-%d -timezone $o(-tz)] eq $date}]
        lappend days [dict create date $date dow $dow week $week isHoliday 0 isToday $isToday notes {} events {}]
    }

    dict create \
        tz        $o(-tz) \
        weekStart $o(-weekStart) \
        firstWeek $o(-firstWeek) \
        range     [list "$y-$m-01" "$y-$m-$lastDay"] \
        days      $days
}
