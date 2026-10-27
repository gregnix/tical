package provide tical::util 1.1
package require Tcl 8.6-

namespace eval tical::util {
    namespace export mm2pt defaults marker dateRange expandSelection gridStartDow \
        options weekStartDow rowWeek
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
            return -code error -errorcode {TICAL UTIL SELECTION} \
                "invalid selection entry: $tok"
        }
    }
    return [lsort [dict keys $out]]
}

# ISO weekday (1 = Monday .. 7 = Sunday) of the first grid column, taken
# from the cells of a ViewSpec. The view decides the week start; renderers
# label their columns with this instead of an option of their own.
# Empty cells (dow {}) are skipped; no dated cell -> 1 (Monday).
proc tical::util::gridStartDow {cells {cols 7}} {
    set i 0
    foreach c $cells {
        if {[dict exists $c dow] && [string is integer -strict [dict get $c dow]]} {
            return [expr {(([dict get $c dow] - 1 - $i % $cols) % 7 + 7) % 7 + 1}]
        }
        incr i
    }
    return 1
}

# --- option checking (views, renderers) -------------------------------------

# Parse "-name value ..." against a dict of defaults. Unknown names and a
# missing value are errors with errorcode $code (e.g. {TICAL VIEW OPTION});
# the message names the caller and the known options. Returns the merged dict.
proc tical::util::options {who defaults arglist code} {
    if {[llength $arglist] % 2} {
        return -code error -errorcode $code \
            "$who: missing value for option \"[lindex $arglist end]\""
    }
    set out $defaults
    foreach {k v} $arglist {
        if {![dict exists $defaults $k]} {
            set known [lsort [dict keys $defaults]]
            if {[llength $known] > 1} {
                set known "[join [lrange $known 0 end-1] {, }] or [lindex $known end]"
            }
            return -code error -errorcode $code \
                "$who: unknown option \"$k\", must be $known"
        }
        dict set out $k $v
    }
    return $out
}

# Week start name -> ISO weekday of the first column: mon|monday -> 1,
# sun|sunday -> 7 (case-insensitive). Anything else: error with $code.
proc tical::util::weekStartDow {value {code {TICAL UTIL WEEKSTART}}} {
    switch -- [string tolower $value] {
        mon - monday { return 1 }
        sun - sunday { return 7 }
    }
    return -code error -errorcode $code \
        "bad week start \"$value\": must be mon or sun"
}

# Week number to show for the grid row that starts at cell index first:
# the week of the middle cell (column 4) if it has a date, else of the
# first dated cell. With a Monday grid and ISO weeks all cells agree; with
# a Sunday grid or -firstWeek us the middle cell names the week most days
# of the row belong to. "" when the row has no dated cell.
proc tical::util::rowWeek {cells first {cols 7}} {
    set mid [lindex $cells [expr {$first + $cols / 2}]]
    if {[dict exists $mid week] && [dict get $mid week] ne ""} {
        return [dict get $mid week]
    }
    for {set j $first} {$j < $first + $cols && $j < [llength $cells]} {incr j} {
        set c [lindex $cells $j]
        if {[dict exists $c week] && [dict get $c week] ne ""} {
            return [dict get $c week]
        }
    }
    return ""
}
