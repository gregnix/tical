package provide tical::config 1.0
package require Tcl 8.6-

namespace eval tical::config {
    variable _cfg
    if {![info exists _cfg]} {
        array set _cfg {
            locale    de_DE
            timezone  Europe/Berlin
            weekstart mon
            firstweek iso
            theme     default
        }
    }
    namespace export set get getThemeColors getDefaults
}

proc tical::config::set {key value} {
    variable _cfg
    ::set _cfg($key) $value
    return $value
}

proc tical::config::get {key} {
    variable _cfg
    if {![info exists _cfg($key)]} { error "unknown key: $key" }
    return $_cfg($key)
}

proc tical::config::getThemeColors {name} {
    switch -- $name {
        dark    {return {today red holiday blue weekend gray text white}}
        default {return {today magenta holiday cyan weekend gray text default}}
    }
}

proc tical::config::getDefaults {} {
    variable _cfg
    array get _cfg
}
