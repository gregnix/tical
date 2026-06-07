package provide tical::util 1.0
package require Tcl 8.6-

namespace eval tical::util {
    namespace export mm2pt defaults marker dateRange expandSelection
}

proc tical::util::mm2pt x { expr {$x * 72.0 / 25.4} }

proc tical::util::defaults {key} {
    dict get {
        locale      de_DE
        timezone    Europe/Berlin
        weekstart   mon
        firstweek   iso
        theme       default
    } $key
}

proc tical::util::marker {type} {
    dict get {
        today   "●"
        holiday "▲"
        weekend "◆"
        event   "○"
    } $type
}

# --- selection helpers (Tk-free, used by render::canvas) --------------------

# Inclusive list of ISO dates from a..b (order-independent). Steps by whole
# days at noon, so DST transitions never drop or duplicate a day.
proc tical::util::dateRange {a b {tz UTC}} {
    set ta [clock scan "$a 12:00:00" -timezone $tz]
    set tb [clock scan "$b 12:00:00" -timezone $tz]
    if {$tb < $ta} { set t $ta; set ta $tb; set tb $t }
    set out {}
    for {set t $ta} {$t <= $tb} {set t [clock add $t 1 day -timezone $tz]} {
        lappend out [clock format $t -format %Y-%m-%d -timezone $tz]
    }
    return $out
}

# Expand a selection spec (list of YYYY-MM-DD and YYYY-MM-DD..YYYY-MM-DD ranges)
# into a sorted, unique list of ISO dates.
proc tical::util::expandSelection {spec {tz UTC}} {
    set out {}
    foreach tok $spec {
        if {[regexp {^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$} $tok -> x y]} {
            foreach d [dateRange $x $y $tz] { dict set out $d 1 }
        } elseif {[regexp {^\d{4}-\d{2}-\d{2}$} $tok]} {
            dict set out $tok 1
        } else {
            error "invalid selection entry: $tok"
        }
    }
    return [lsort [dict keys $out]]
}
