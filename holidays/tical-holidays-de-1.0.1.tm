# tical::holidays::de - German public holidays for tical::holidays.
#
#   getHolidays ?-sundays 0|1? year  -> dict {YYYY-MM-DD name}, sorted
#
# Default: the nine holidays that are statutory in all German states (no
# state-specific days). -sundays 1 adds Ostersonntag and Pfingstsonntag;
# that is the list of tclutils::tuholiday::holidays. Region DE uses the
# default; to get the Sundays in the views:
#   tical::holidays::register DE {::tical::holidays::de::getHolidays -sundays 1}
# Errors: {TICAL HOLIDAYS OPTION}, {TICAL HOLIDAYS YEAR}.

package require tical::holidays 1.0

package provide tical::holidays::de 1.0.1
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

proc ::tical::holidays::de::getHolidays {args} {
    set sundays 0
    set year [lindex $args end]
    set opts [lrange $args 0 end-1]
    if {[llength $args] == 0 || [llength $opts] % 2} {
        return -code error -errorcode {TICAL HOLIDAYS OPTION} \
            "wrong # args: should be \"getHolidays ?-sundays 0|1? year\""
    }
    foreach {k v} $opts {
        if {$k ne "-sundays"} {
            return -code error -errorcode {TICAL HOLIDAYS OPTION} \
                "unknown option \"$k\", must be -sundays"
        }
        if {![string is boolean -strict $v]} {
            return -code error -errorcode {TICAL HOLIDAYS OPTION} \
                "-sundays must be 0 or 1, got \"$v\""
        }
        set sundays [string is true $v]
    }
    if {![string is integer -strict $year] || $year < 1583} {
        return -code error -errorcode {TICAL HOLIDAYS YEAR} \
            "not a Gregorian year: \"$year\""
    }
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

    if {$sundays} {
        dict set holidays [clock format $easterDate -format "%Y-%m-%d"] "Ostersonntag"
        dict set holidays [clock format [clock add $easterDate 49 days] -format "%Y-%m-%d"] \
            "Pfingstsonntag"
    }
    set out [dict create]
    foreach k [lsort [dict keys $holidays]] { dict set out $k [dict get $holidays $k] }
    return $out
}

tical::holidays::register DE ::tical::holidays::de::getHolidays


