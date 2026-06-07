package require tical::holidays 1.0

package provide tical::holidays::de 1.0
package require Tcl 8.6-

namespace eval ::tical::holidays::de {
    namespace export getHolidays
}

proc ::tical::holidays::de::calcEaster {year} {
    set a [expr {$year % 19}]
    set b [expr {$year / 100}]
    set c [expr {$year % 100}]
    set d [expr {$b / 4}]
    set e [expr {$b % 4}]
    set f [expr {($b + 8) / 25}]
    set g [expr {($b - $f + 1) / 3}]
    set h [expr {(19 * $a + $b - $d - $g + 15) % 30}]
    set i [expr {$c / 4}]
    set k [expr {$c % 4}]
    set l [expr {(32 + 2 * $e + 2 * $i - $h - $k) % 7}]
    set m [expr {($a + 11 * $h + 22 * $l) / 451}]
    set month [expr {($h + $l - 7 * $m + 114) / 31}]
    set day [expr {(($h + $l - 7 * $m + 114) % 31) + 1}]
    
    return [list $month $day]
}

proc ::tical::holidays::de::getHolidays {year} {
    set holidays {}
    
    dict set holidays "$year-01-01" "Neujahr"
    dict set holidays "$year-05-01" "Tag der Arbeit"
    dict set holidays "$year-10-03" "Tag der Deutschen Einheit"
    dict set holidays "$year-12-25" "1. Weihnachtstag"
    dict set holidays "$year-12-26" "2. Weihnachtstag"
    
    lassign [calcEaster $year] eMonth eDay
    set easterDate [clock scan "$year-[format %02d $eMonth]-[format %02d $eDay]" -format "%Y-%m-%d"]
    
    set goodFriday [clock add $easterDate -2 days]
    dict set holidays [clock format $goodFriday -format "%Y-%m-%d"] "Karfreitag"
    
    set easterMonday [clock add $easterDate 1 day]
    dict set holidays [clock format $easterMonday -format "%Y-%m-%d"] "Ostermontag"
    
    set ascension [clock add $easterDate 39 days]
    dict set holidays [clock format $ascension -format "%Y-%m-%d"] "Christi Himmelfahrt"
    
    set pentecostMonday [clock add $easterDate 50 days]
    dict set holidays [clock format $pentecostMonday -format "%Y-%m-%d"] "Pfingstmontag"
    
    return $holidays
}

tical::holidays::register DE ::tical::holidays::de::getHolidays


