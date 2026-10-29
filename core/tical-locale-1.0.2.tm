# tical::locale - Internationalization (i18n) Module

package require tical::config 1.0

package provide tical::locale 1.0.2
package require Tcl 8.6-

namespace eval ::tical::locale {
    namespace export getMonthName getWeekdayName \
                     getMonthNames getWeekdayNames \
                     getMonthNamesShort getWeekdaysShort \
                     getMonthNamesLong getWeekdaysLong getWeekLabel
    
    variable translations
    
    # Deutsche Übersetzungen
    ::set translations [dict create \
        de [dict create \
            months {"" Januar Februar März April Mai Juni Juli August September Oktober November Dezember} \
            monthsShort {"" Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez} \
            weekdays {Montag Dienstag Mittwoch Donnerstag Freitag Samstag Sonntag} \
            weekdaysShort {Mo Di Mi Do Fr Sa So} \
            week KW weekShort KW] \
        en [dict create \
            months {"" January February March April May June July August September October November December} \
            monthsShort {"" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec} \
            weekdays {Monday Tuesday Wednesday Thursday Friday Saturday Sunday} \
            weekdaysShort {Mo Tu We Th Fr Sa Su} \
            week Week weekShort Wk] \
        fr [dict create \
            months {"" Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre} \
            monthsShort {"" Jan Fév Mar Avr Mai Juin Juil Août Sep Oct Nov Déc} \
            weekdays {Lundi Mardi Mercredi Jeudi Vendredi Samedi Dimanche} \
            weekdaysShort {Lu Ma Me Je Ve Sa Di} \
            week Semaine weekShort Sem]]
}

proc ::tical::locale::_getLang {} {
    ::set locale [tical::config::get locale]
    return [string range $locale 0 1]
}

proc ::tical::locale::getMonthNamesLong {} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang months]} {
        return [dict get $translations $lang months]
    }
    return [dict get $translations en months]
}

proc ::tical::locale::getMonthNamesShort {} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang monthsShort]} {
        return [dict get $translations $lang monthsShort]
    }
    return [dict get $translations en monthsShort]
}

# format: long | short; other values: error {TICAL LOCALE FORMAT}
proc ::tical::locale::getMonthNames {{format long}} {
    switch -- $format {
        short   { return [getMonthNamesShort] }
        long    { return [getMonthNamesLong] }
        default {
            return -code error -errorcode {TICAL LOCALE FORMAT} \
                "bad format \"$format\": must be long or short"
        }
    }
}

# Integer n in lo..hi ("05" accepted), else error {TICAL LOCALE <what>}.
proc ::tical::locale::_num {v lo hi what} {
    if {![regexp {^\d{1,2}$} $v] || [scan $v %d] < $lo || [scan $v %d] > $hi} {
        return -code error -level 2 -errorcode [list TICAL LOCALE [string toupper $what]] \
            "$what must be $lo..$hi, got \"$v\""
    }
    return [scan $v %d]
}

proc ::tical::locale::getMonthName {month {format long}} {
    ::set m [_num $month 1 12 month]
    ::set names [getMonthNames $format]
    return [lindex $names $m]
}

# Weekday lists start on Monday; startDow (1 = Monday .. 7 = Sunday) rotates
# the list so that it starts on that day (7 -> Su Mo Tu ...).
proc ::tical::locale::_rotate {names startDow} {
    if {![string is integer -strict $startDow] || $startDow < 1 || $startDow > 7} {
        return -code error -errorcode {TICAL LOCALE DOW} \
            "startDow must be an integer 1..7, got \"$startDow\""
    }
    ::set k [expr {$startDow - 1}]
    return [concat [lrange $names $k end] [lrange $names 0 [expr {$k - 1}]]]
}

proc ::tical::locale::getWeekdaysLong {{startDow 1}} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang weekdays]} {
        return [_rotate [dict get $translations $lang weekdays] $startDow]
    }
    return [_rotate [dict get $translations en weekdays] $startDow]
}

proc ::tical::locale::getWeekdaysShort {{startDow 1}} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang weekdaysShort]} {
        return [_rotate [dict get $translations $lang weekdaysShort] $startDow]
    }
    return [_rotate [dict get $translations en weekdaysShort] $startDow]
}

# format: long | short (also 2); other values: error {TICAL LOCALE FORMAT}
proc ::tical::locale::getWeekdayNames {{format long} {startDow 1}} {
    switch -- $format {
        short - 2 { return [getWeekdaysShort $startDow] }
        long      { return [getWeekdaysLong $startDow] }
        default {
            return -code error -errorcode {TICAL LOCALE FORMAT} \
                "bad format \"$format\": must be long or short"
        }
    }
}

# Label for a calendar week: long (title, "Week 42") or short (column head,
# "KW"/"Wk"/"Sem").
proc ::tical::locale::getWeekLabel {{format long}} {
    ::set lang [_getLang]
    ::set key [expr {$format eq "short" ? "weekShort" : "week"}]
    variable translations
    if {[dict exists $translations $lang $key]} {
        return [dict get $translations $lang $key]
    }
    return [dict get $translations en $key]
}

proc ::tical::locale::getWeekdayName {dow {format long}} {
    ::set d [_num $dow 1 7 dow]
    ::set names [getWeekdayNames $format]
    return [lindex $names [expr {$d - 1}]]
}

proc ::tical::locale::getSupportedLocales {} {
    return {de_DE en_US fr_FR}
}

proc ::tical::locale::getSupportedLanguages {} {
    return {de en fr}
}

