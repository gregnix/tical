package require tical::core 1.0
package require tical::config 1.0

package provide tical::view::month 1.0
package require Tcl 8.6-

namespace eval tical::view::month {
    namespace export getData validate
}

# Hilfsproc: erster Datumseintrag (YYYY-MM-DD) -> ISO-Wochentag (1..7) mit weekStart-Offset
proc ::tical::view::month::_firstCellOffset {y m weekStart tz} {
    set firstTs [clock scan "$y-$m-01 12:00:00" -timezone $tz]
    set dow     [clock format $firstTs -format %u -timezone $tz] ;# 1..7 (Mon=1)
    set startIx [expr {$weekStart eq "sun" ? 7 : 1}]             ;# mon->1, sun->7
    # Ziel: Raster beginnt bei weekStart; offset = wie viele Tage zurück
    set offs [expr {($dow - $startIx + 7) % 7}]
    return $offs
}

proc tical::view::month::getData {args} {
    array set o {
        -year {}
        -month {}
        -tz {}
        -weekStart {}
        -firstWeek {}
        -showAdjacentDays 1
        -count 1
        -holidays {}
    }
    array set o $args
    if {$o(-year) eq {} || $o(-month) eq {}} {
        error "view::month::getData: -year und -month sind Pflicht"
    }
    if {$o(-tz) eq {}}        { set o(-tz)        [tical::config::get timezone] }
    if {$o(-weekStart) eq {}} { set o(-weekStart) [tical::config::get weekstart] }
    if {$o(-firstWeek) eq {}} { set o(-firstWeek) [tical::config::get firstweek] }
    
    # Feiertage laden (falls gewunscht)
    set holidayDict {}
    if {$o(-holidays) ne {}} {
        if {[catch {package require tical::holidays 1.0}]} {
            puts stderr "Warning: tical::holidays not available"
        } else {
            set holidayDict [tical::holidays::getHolidays $o(-holidays) $o(-year) $o(-month)]
        }
    }

    # Ein einzelnes ViewSpec erzeugen
    set y $o(-year)
    set m [format %02d [scan $o(-month) %d]]

    set cal  [tical::core::calendarData -year $y -month $m -tz $o(-tz) -weekStart $o(-weekStart) -firstWeek $o(-firstWeek)]
    set days [dict get $cal days]

    # 6x7 Zellen: mit Nachbar-Tagen auffüllen
    set cols 7; set rows 6; set cells {}
    set offs [_firstCellOffset $y $m $o(-weekStart) $o(-tz)]

    # Vorlauf (vor dem 1. des Monats)
    if {$o(-showAdjacentDays)} {
        set prevFirst [clock add [clock scan "$y-$m-01" -timezone $o(-tz)] -1 month]
        set py        [clock format $prevFirst -format %Y -timezone $o(-tz)]
        set pm        [format %02d [scan [clock format $prevFirst -format %m -timezone $o(-tz)] %d]]
        set plastTs   [clock add [clock scan "$py-$pm-01" -timezone $o(-tz)] 1 month -1 day]
        set plastDay  [scan [clock format $plastTs -format %d -timezone $o(-tz)] %d]
        for {set i $offs} {$i > 0} {incr i -1} {
            set d [expr {$plastDay - $i + 1}]
            set date "$py-$pm-[format %02d $d]"
            set ts [clock scan "$date 12:00:00" -timezone $o(-tz)]
            set adjDow [clock format $ts -format %u -timezone $o(-tz)]
            set adjWeek [clock format $ts -format %V -timezone $o(-tz)]
            lappend cells [dict create date $date inMonth 0 dow $adjDow week $adjWeek markers {} events {}]
        }
    } else {
        for {set i 0} {$i < $offs} {incr i} {
            lappend cells [dict create date {} inMonth 0 dow {} week {} markers {} events {}]
        }
    }

    # Monats-Tage
    foreach rec $days {
        set markerList {}
        if {[dict get $rec isToday]} {
            lappend markerList "today"
        }
        
        # Prufen ob Feiertag
        set date [dict get $rec date]
        set day [scan [lindex [split $date -] 2] %d]
        if {[dict exists $holidayDict $day]} {
            lappend markerList "holiday"
        }
        
        lappend cells [dict merge $rec [dict create inMonth 1 markers $markerList]]
    }

    # Nachlauf
    set need [expr {$rows*$cols - [llength $cells]}]
    if {$need > 0} {
        if {$o(-showAdjacentDays)} {
            set nextFirst [clock add [clock scan "$y-$m-01" -timezone $o(-tz)] 1 month]
            set ny        [clock format $nextFirst -format %Y -timezone $o(-tz)]
            set nm        [format %02d [scan [clock format $nextFirst -format %m -timezone $o(-tz)] %d]]
            for {set d 1} {$d <= $need} {incr d} {
                set date "$ny-$nm-[format %02d $d]"
                set ts [clock scan "$date 12:00:00" -timezone $o(-tz)]
                set adjDow [clock format $ts -format %u -timezone $o(-tz)]
                set adjWeek [clock format $ts -format %V -timezone $o(-tz)]
                lappend cells [dict create date $date inMonth 0 dow $adjDow week $adjWeek markers {} events {}]
            }
        } else {
            for {set i 0} {$i < $need} {incr i} {
                lappend cells [dict create date {} inMonth 0 dow {} week {} markers {} events {}]
            }
        }
    }

    set spec [dict create \
        type   month-grid \
        month  [scan $m %d] \
        year   $y \
        cols   $cols \
        rows   $rows \
        cells  $cells \
        legend {markers {{today ●} {holiday ▲}}} \
        grid   {cols 7 rows 6 gutter 2 padding 1}]
    return $spec
}

proc tical::view::month::validate {viewSpec} {
    foreach k {type month year cols rows cells} {
        if {![dict exists $viewSpec $k]} { error "ViewSpec fehlt Feld: $k" }
    }
    if {[dict get $viewSpec type] ne "month-grid"} {
        error "ViewSpec type muss 'month-grid' sein"
    }
    return 1
}
