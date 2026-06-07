package provide tical::core 1.0
package require Tcl 8.6-

namespace eval tical::core {
    namespace export calendarData isLeap
}

proc tical::core::isLeap {year} {
    expr {($year % 400 == 0) || (($year % 4 == 0) && ($year % 100 != 0))}
}

# calendarData - erzeugt CalendarData für einen Monat
# Optionen: -year Y -month M -tz TZ -weekStart mon|sun -firstWeek iso|simple|us
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
        error "calendarData: -year und -month sind Pflicht"
    }

    set y $o(-year)
    set m [format %02d [scan $o(-month) %d]]
    set first [clock scan "$y-$m-01 00:00:00" -timezone $o(-tz)]
    # Letzter Tag des Monats:
    set lastTs  [clock add [clock add $first 1 month] -1 day]
    set lastDay [scan [clock format $lastTs -format %d -timezone $o(-tz)] %d]
    set days {}

    for {set d 1} {$d <= $lastDay} {incr d} {
        set ts   [clock scan "$y-$m-[format %02d $d] 12:00:00" -timezone $o(-tz)]
        set date [clock format $ts -format %Y-%m-%d -timezone $o(-tz)]
        # ISO-Tag 1..7
        set dow  [clock format $ts -format %u -timezone $o(-tz)]
        # ISO-Woche
        set week [clock format $ts -format %V -timezone $o(-tz)]
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
