package provide tical::holidays 1.0
package require Tcl 8.6-

namespace eval ::tical::holidays {
    namespace export getHolidays getMarkers
    variable plugins
    array set plugins {}
}

proc ::tical::holidays::register {country proc} {
    variable plugins
    set plugins($country) $proc
}

proc ::tical::holidays::getHolidays {country year month} {
    variable plugins
    
    if {![info exists plugins($country)]} {
        return {}
    }
    
    set allHolidays [{*}$plugins($country) $year]
    
    set monthStr [format %02d [scan $month %d]]
    set result {}
    
    dict for {date name} $allHolidays {
        if {[string match "$year-$monthStr-*" $date]} {
            set day [scan [lindex [split $date -] 2] %d]
            dict set result $day $name
        }
    }
    
    return $result
}

proc ::tical::holidays::getMarkers {country year month} {
    set holidays [getHolidays $country $year $month]
    set markers {}
    
    dict for {day name} $holidays {
        lappend markers $day [list holiday $name]
    }
    
    return $markers
}


