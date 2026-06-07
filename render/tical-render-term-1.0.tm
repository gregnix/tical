package provide tical::render::term 1.0
package require Tcl 8.6-

namespace eval tical::render::term {
    namespace export print
}

# Einfaches ASCII-Raster (7 Spalten × 6 Zeilen), gibt String zurück.
# Option -color 1 aktiviert minimale Hervorhebungen (heute markiert).
# Option -weekNumbers 1 zeigt ISO-Wochennummern in erster Spalte.
proc tical::render::term::print {viewSpec args} {
    array set o {-color 0 -weekStart mon -weekNumbers 0}
    array set o $args
    # Validieren
    if {[dict get $viewSpec type] ne "month-grid"} {
        error "render::term::print erwartet type=month-grid"
    }
    set month [dict get $viewSpec month]
    set year  [dict get $viewSpec year]
    set cells [dict get $viewSpec cells]

    # Kopf abhängig von weekStart
    if {$o(-weekNumbers)} {
        set headerDays(mon) " KW Mo Tu We Th Fr Sa Su"
        set headerDays(sun) " KW Su Mo Tu We Th Fr Sa"
    } else {
        set headerDays(mon) " Mo Tu We Th Fr Sa Su"
        set headerDays(sun) " Su Mo Tu We Th Fr Sa"
    }
    set header [format " %s %d " [clock format [clock scan "$year-[format %02d $month]-01"] -format %B] $year]
    set out  ""
    append out $header \n
    append out $headerDays($o(-weekStart)) \n

    # 42 Zellen in 6 Zeilen
    for {set i 0} {$i < [llength $cells]} {incr i} {
        set rec [lindex $cells $i]
        set date [dict get $rec date]
        
        # Wochennummer am Zeilenanfang (wenn gewünscht)
        if {$o(-weekNumbers) && $i % 7 == 0} {
            # Finde erste nicht-leere Woche in dieser Zeile
            set week ""
            for {set j $i} {$j < $i + 7 && $j < [llength $cells]} {incr j} {
                set w [dict get [lindex $cells $j] week]
                if {$w ne ""} {
                    set week $w
                    break
                }
            }
            if {$week ne ""} {
                append out [format " %2d" [scan $week %d]]
            } else {
                append out "   "
            }
        }
        
        if {$date eq {}} {
            set dstr "  ."
        } else {
            set d [scan [string range $date 8 9] %d]
            set inM [dict get $rec inMonth]
            set isToday [expr {[dict exists $rec isToday] ? [dict get $rec isToday] : 0}]
            set dd [format %2d $d]
            if {!$inM} { set dd ".." }
            if {$o(-color) && $isToday} {
                # einfache Hervorhebung: Stern davor und danach, auf Breite trimmen
                set dd "*$dd"
                set dd [string range $dd end-1 end]
            }
            set dstr " $dd"
        }
        append out $dstr
        if {($i+1) % 7 == 0} { append out "\n" }
    }
    return $out
}
