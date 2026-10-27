package require tical::core 1.0
package require tical::config 1.0
package require tical::util 1.1
package require tical::event 1.1

package provide tical::view::week 1.1
package require Tcl 8.6-

namespace eval tical::view::week {
    namespace export getData validate
}

proc tical::view::week::getIsoWeekStart {year week {tz {}}} {
    # Finde Montag der ISO-Woche (12:00 Uhr in tz, damit Zeitzone und
    # Sommerzeit das Datum nicht verschieben)
    # ISO-Woche 1 enthält den ersten Donnerstag des Jahres
    if {$tz eq {}} { set tz [tical::config::get timezone] }
    
    set jan4 [clock scan "$year-01-04 12:00:00" -format "%Y-%m-%d %H:%M:%S" -timezone $tz]
    set jan4Dow [clock format $jan4 -format %u -timezone $tz]
    
    # Montag von Woche 1
    set week1Monday [clock add $jan4 [expr {1 - $jan4Dow}] days -timezone $tz]
    
    # Montag der gewünschten Woche
    set weekMonday [clock add $week1Monday [expr {($week - 1) * 7}] days -timezone $tz]
    
    return $weekMonday
}

# Options (unknown ones are an error, errorcode {TICAL VIEW OPTION}):
#   -year -week (ISO) or -date, -tz, -holidays REGION, -events LIST
# The week always runs Monday to Sunday (ISO week).
proc tical::view::week::getData {args} {
    array set o [::tical::util::options view::week::getData {
        -year {} -week {} -date {} -tz {} -holidays {} -events {}
    } $args {TICAL VIEW OPTION}]
    
    if {$o(-tz) eq {}} {
        set o(-tz) [tical::config::get timezone]
    }
    
    # Wenn -date angegeben, ISO-Jahr (%G) und ISO-Woche daraus bestimmen;
    # %Y wäre am Jahreswechsel falsch (2024-12-30 liegt in Woche 1/2025)
    if {$o(-date) ne {}} {
        set ts [clock scan $o(-date) -format "%Y-%m-%d" -timezone $o(-tz)]
        set o(-year) [clock format $ts -format %G -timezone $o(-tz)]
        set o(-week) [scan [clock format $ts -format %V -timezone $o(-tz)] %d]
    }
    
    if {$o(-year) eq {} || $o(-week) eq {}} {
        return -code error -errorcode {TICAL VIEW ARGS} \
            "view::week::getData: -year and -week (or -date) are required"
    }
    
    # Montag der Woche finden
    set monday [getIsoWeekStart $o(-year) $o(-week) $o(-tz)]
    
    # Feiertage laden: die Monate der sieben Tage (Woche kann über Monats-
    # und Jahresgrenzen gehen)
    set holidaysByMonth {}
    if {$o(-holidays) ne {}} {
        if {[catch {package require tical::holidays 1.0}] == 0} {
            set seen {}
            for {set i 0} {$i < 7} {incr i} {
                set t [clock add $monday $i days -timezone $o(-tz)]
                set y [clock format $t -format %Y -timezone $o(-tz)]
                set m [scan [clock format $t -format %m -timezone $o(-tz)] %d]
                if {[dict exists $seen $y-$m]} continue
                dict set seen $y-$m 1
                set holidays [tical::holidays::getHolidays $o(-holidays) $y $m]
                dict for {day name} $holidays {
                    set date "$y-[format %02d $m]-[format %02d $day]"
                    dict set holidaysByMonth $date $name
                }
            }
        }
    }
    
    # 7 Tage erstellen (Mo-So)
    set cells {}
    set todayStr [clock format [clock seconds] -format %Y-%m-%d -timezone $o(-tz)]
    
    for {set i 0} {$i < 7} {incr i} {
        set dayTs [clock add $monday $i days -timezone $o(-tz)]
        set date [clock format $dayTs -format %Y-%m-%d -timezone $o(-tz)]
        set dow [expr {$i + 1}]
        
        set markers {}
        if {$date eq $todayStr} {
            lappend markers "today"
        }
        if {[dict exists $holidaysByMonth $date]} {
            lappend markers "holiday"
        }
        
        lappend cells [dict create \
            date $date \
            dow $dow \
            week $o(-week) \
            markers $markers \
            events {}]
    }
    
    if {[llength $o(-events)]} {
        set cells [::tical::event::distribute $cells $o(-events) $o(-tz)]
    }

    set spec [dict create \
        type "week-grid" \
        year $o(-year) \
        week $o(-week) \
        cols 7 \
        rows 1 \
        cells $cells]
    
    return $spec
}

proc tical::view::week::validate {viewSpec} {
    foreach k {type year week cols rows cells} {
        if {![dict exists $viewSpec $k]} {
            return -code error -errorcode {TICAL VIEW SPEC} "ViewSpec missing field: $k"
        }
    }
    if {[dict get $viewSpec type] ne "week-grid"} {
        return -code error -errorcode {TICAL VIEW TYPE} \
            "ViewSpec type must be week-grid, got \"[dict get $viewSpec type]\""
    }
    return 1
}


