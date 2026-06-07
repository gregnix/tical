package require tical::core 1.0
package require tical::config 1.0

package provide tical::view::week 1.0
package require Tcl 8.6-

namespace eval tical::view::week {
    namespace export getData validate
}

proc tical::view::week::getIsoWeekStart {year week} {
    # Finde Montag der ISO-Woche
    # ISO-Woche 1 enthält den ersten Donnerstag des Jahres
    
    set jan4 [clock scan "$year-01-04" -format "%Y-%m-%d"]
    set jan4Dow [clock format $jan4 -format %u]
    
    # Montag von Woche 1
    set week1Monday [clock add $jan4 [expr {1 - $jan4Dow}] days]
    
    # Montag der gewünschten Woche
    set weekMonday [clock add $week1Monday [expr {($week - 1) * 7}] days]
    
    return $weekMonday
}

proc tical::view::week::getData {args} {
    array set o {
        -year {}
        -week {}
        -date {}
        -tz {}
        -holidays {}
    }
    array set o $args
    
    if {$o(-tz) eq {}} {
        set o(-tz) [tical::config::get timezone]
    }
    
    # Wenn -date angegeben, Jahr und Woche daraus bestimmen
    if {$o(-date) ne {}} {
        set ts [clock scan $o(-date) -format "%Y-%m-%d" -timezone $o(-tz)]
        set o(-year) [clock format $ts -format %Y -timezone $o(-tz)]
        set o(-week) [scan [clock format $ts -format %V -timezone $o(-tz)] %d]
    }
    
    if {$o(-year) eq {} || $o(-week) eq {}} {
        error "view::week::getData: -year und -week (oder -date) sind Pflicht"
    }
    
    # Feiertage laden
    set holidaysByMonth {}
    if {$o(-holidays) ne {}} {
        if {[catch {package require tical::holidays 1.0}] == 0} {
            # Lade Feiertage für alle möglichen Monate (Woche kann über Monatsgrenzen gehen)
            for {set m 1} {$m <= 12} {incr m} {
                set holidays [tical::holidays::getHolidays $o(-holidays) $o(-year) $m]
                dict for {day name} $holidays {
                    set date "$o(-year)-[format %02d $m]-[format %02d $day]"
                    dict set holidaysByMonth $date $name
                }
            }
        }
    }
    
    # Montag der Woche finden
    set monday [getIsoWeekStart $o(-year) $o(-week)]
    
    # 7 Tage erstellen (Mo-So)
    set cells {}
    set todayStr [clock format [clock seconds] -format %Y-%m-%d -timezone $o(-tz)]
    
    for {set i 0} {$i < 7} {incr i} {
        set dayTs [clock add $monday $i days]
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
            error "ViewSpec fehlt Feld: $k"
        }
    }
    if {[dict get $viewSpec type] ne "week-grid"} {
        error "ViewSpec type muss 'week-grid' sein"
    }
    return 1
}


