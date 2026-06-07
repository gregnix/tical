# tical::locale - Internationalization (i18n) Module

package require tical::config 1.0

package provide tical::locale 1.0
package require Tcl 8.6-

namespace eval ::tical::locale {
    namespace export getMonthName getWeekdayName \
                     getMonthNames getWeekdayNames \
                     getMonthNamesShort getWeekdaysShort \
                     getMonthNamesLong getWeekdaysLong
    
    variable translations
    
    # Deutsche Übersetzungen
    ::set translations [dict create \
        de [dict create \
            months {"" Januar Februar März April Mai Juni Juli August September Oktober November Dezember} \
            monthsShort {"" Jan Feb Mär Apr Mai Jun Jul Aug Sep Okt Nov Dez} \
            weekdays {Montag Dienstag Mittwoch Donnerstag Freitag Samstag Sonntag} \
            weekdaysShort {Mo Di Mi Do Fr Sa So}] \
        en [dict create \
            months {"" January February March April May June July August September October November December} \
            monthsShort {"" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec} \
            weekdays {Monday Tuesday Wednesday Thursday Friday Saturday Sunday} \
            weekdaysShort {Mo Tu We Th Fr Sa Su}] \
        fr [dict create \
            months {"" Janvier Février Mars Avril Mai Juin Juillet Août Septembre Octobre Novembre Décembre} \
            monthsShort {"" Jan Fév Mar Avr Mai Juin Juil Août Sep Oct Nov Déc} \
            weekdays {Lundi Mardi Mercredi Jeudi Vendredi Samedi Dimanche} \
            weekdaysShort {Lu Ma Me Je Ve Sa Di}]]
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

proc ::tical::locale::getMonthNames {{format long}} {
    if {$format eq "short"} {
        return [getMonthNamesShort]
    }
    return [getMonthNamesLong]
}

proc ::tical::locale::getMonthName {month {format long}} {
    ::set names [getMonthNames $format]
    return [lindex $names $month]
}

proc ::tical::locale::getWeekdaysLong {} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang weekdays]} {
        return [dict get $translations $lang weekdays]
    }
    return [dict get $translations en weekdays]
}

proc ::tical::locale::getWeekdaysShort {} {
    ::set lang [_getLang]
    
    variable translations
    if {[dict exists $translations $lang weekdaysShort]} {
        return [dict get $translations $lang weekdaysShort]
    }
    return [dict get $translations en weekdaysShort]
}

proc ::tical::locale::getWeekdayNames {{format long}} {
    if {$format eq "short" || $format == 2} {
        return [getWeekdaysShort]
    }
    return [getWeekdaysLong]
}

proc ::tical::locale::getWeekdayName {dow {format long}} {
    ::set names [getWeekdayNames $format]
    return [lindex $names [expr {$dow - 1}]]
}

proc ::tical::locale::getSupportedLocales {} {
    return {de_DE en_US fr_FR}
}

proc ::tical::locale::getSupportedLanguages {} {
    return {de en fr}
}

