package provide tical::config 1.0.2
package require Tcl 8.6-

# Settings for all of tical. Keys and values are checked:
#   locale     de_DE | en_US | fr_FR (any locale of these languages, e.g. en_GB)
#   timezone   a zone Tcl knows (Europe/Berlin, :localtime, UTC ...)
#   weekstart  mon | sun (monday, sunday accepted)
#   firstweek  iso | simple | us
#   theme      default | dark
#   today      YYYY-MM-DD or "" (empty: the real date); the date the views
#              mark as today, e.g. for reproducible output
# Unknown key: {TICAL CONFIG KEY}; bad value: {TICAL CONFIG VALUE}.
namespace eval tical::config {
    variable _cfg
    if {![info exists _cfg]} {
        array set _cfg {
            locale    de_DE
            timezone  Europe/Berlin
            weekstart mon
            firstweek iso
            theme     default
            today     {}
        }
    }
    variable languages {de en fr}
    namespace export set get getThemeColors getDefaults today
}

proc tical::config::_bad {key value must} {
    return -code error -errorcode {TICAL CONFIG VALUE} \
        "bad $key \"$value\": must be $must"
}

proc tical::config::set {key value} {
    variable _cfg
    variable languages
    switch -- $key {
        locale {
            if {![regexp {^([a-z]{2})(?:_[A-Z]{2})?$} $value -> lang] || $lang ni $languages} {
                _bad $key $value "a locale of [join $languages {, }] (de_DE, en_US, fr_FR)"
            }
        }
        timezone {
            if {$value eq "" || [catch {clock format 0 -timezone $value}]} {
                _bad $key $value "a time zone Tcl knows, such as Europe/Berlin"
            }
        }
        weekstart {
            if {[string tolower $value] ni {mon sun monday sunday}} {
                _bad $key $value "mon or sun"
            }
        }
        firstweek {
            if {$value ni {iso simple us}} { _bad $key $value "iso, simple or us" }
        }
        theme {
            if {$value ni {default dark}} { _bad $key $value "default or dark" }
        }
        today {
            if {$value ne "" && ([catch {clock scan $value -format %Y-%m-%d -gmt 1} t]
                    || [clock format $t -format %Y-%m-%d -gmt 1] ne $value)} {
                _bad $key $value "a date YYYY-MM-DD or empty"
            }
        }
        default {
            return -code error -errorcode {TICAL CONFIG KEY} \
                "unknown key \"$key\": must be [join [lsort [array names _cfg]] {, }]"
        }
    }
    ::set _cfg($key) $value
    return $value
}

proc tical::config::get {key} {
    variable _cfg
    if {![info exists _cfg($key)]} {
        return -code error -errorcode {TICAL CONFIG KEY} "unknown key: $key"
    }
    return $_cfg($key)
}

# Today as YYYY-MM-DD in tz: the setting `today`, else the real date.
proc tical::config::today {{tz {}}} {
    variable _cfg
    if {$_cfg(today) ne ""} { return $_cfg(today) }
    if {$tz eq ""} { ::set tz $_cfg(timezone) }
    return [clock format [clock seconds] -format %Y-%m-%d -timezone $tz]
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
