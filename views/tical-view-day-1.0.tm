package require tical::core 1.0
package require tical::config 1.0

package provide tical::view::day 1.0
package require Tcl 8.6-

namespace eval tical::view::day {
    namespace export getData validate
}

proc tical::view::day::getData {args} {
    array set o {
        -date {}
        -tz {}
        -holidays {}
        -hourStart 0
        -hourEnd 23
    }
    array set o $args
    
    if {$o(-date) eq {}} {
        error "view::day::getData: -date ist Pflicht"
    }
    
    if {$o(-tz) eq {}} {
        set o(-tz) [tical::config::get timezone]
    }
    
    # Datum parsen
    set ts [clock scan $o(-date) -format "%Y-%m-%d" -timezone $o(-tz)]
    set year [clock format $ts -format %Y -timezone $o(-tz)]
    set month [scan [clock format $ts -format %m -timezone $o(-tz)] %d]
    set day [scan [clock format $ts -format %d -timezone $o(-tz)] %d]
    set dow [clock format $ts -format %u -timezone $o(-tz)]
    set week [scan [clock format $ts -format %V -timezone $o(-tz)] %d]
    
    # Heute?
    set todayStr [clock format [clock seconds] -format %Y-%m-%d -timezone $o(-tz)]
    set isToday [expr {$o(-date) eq $todayStr}]
    
    # Feiertag?
    set isHoliday 0
    if {$o(-holidays) ne {}} {
        if {[catch {package require tical::holidays 1.0}] == 0} {
            set holidays [tical::holidays::getHolidays $o(-holidays) $year $month]
            if {[dict exists $holidays $day]} {
                set isHoliday 1
            }
        }
    }
    
    # Stunden-Zellen erstellen
    set cells {}
    for {set hour $o(-hourStart)} {$hour <= $o(-hourEnd)} {incr hour} {
        set hourStr [format %02d $hour]
        
        set markers {}
        if {$isToday} {
            lappend markers "today"
        }
        if {$isHoliday} {
            lappend markers "holiday"
        }
        
        lappend cells [dict create \
            hour $hour \
            time "$hourStr:00" \
            date $o(-date) \
            markers $markers \
            events {}]
    }
    
    set spec [dict create \
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
        cells $cells]
    
    return $spec
}

proc tical::view::day::validate {viewSpec} {
    foreach k {type date year month day dow week hours rows cells} {
        if {![dict exists $viewSpec $k]} {
            error "ViewSpec fehlt Feld: $k"
        }
    }
    if {[dict get $viewSpec type] ne "day-grid"} {
        error "ViewSpec type muss 'day-grid' sein"
    }
    return 1
}


