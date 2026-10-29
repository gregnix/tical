# tical::model - appointments and events in memory
#
# Records use the event format of tical::event (summary, dtstart, dtend,
# allday, location, description, categories ...) plus id, type, created.
# For one version (1.1) the older fields are still accepted as options
# (-title, -date, -startTime, -endTime, -allDay, -category) and still
# present in every record (title, date, startTime, endTime, allDay,
# category); they will be removed in 1.2.
#   toEvents  -> list of event dicts for getData ... -events

package provide tical::model 1.1.1
package require Tcl 8.6-
package require tical::event 1.1.1

namespace eval ::tical::model {
    namespace export createAppointment createEvent toEvents
    variable appointments
    variable events
    variable nextId 1

    array set appointments {}
    array set events {}
}

# option list -> event input dict (keys without "-"; empty values dropped).
# Unknown options and a missing value: error {TICAL MODEL OPTION}.
proc ::tical::model::_input {defaults arglist} {
    array set o $defaults
    if {[llength $arglist] % 2} {
        return -code error -errorcode {TICAL MODEL OPTION} \
            "missing value for option \"[lindex $arglist end]\""
    }
    foreach {k v} $arglist {
        if {![info exists o($k)]} {
            return -code error -errorcode {TICAL MODEL OPTION} \
                "unknown option \"$k\", must be [join [lsort [dict keys $defaults]] {, }]"
        }
    }
    array set o $arglist
    set in {}
    foreach k [array names o] {
        if {$o($k) ne ""} { dict set in [string trimleft $k -] $o($k) }
    }
    return $in
}

# event (core format) + record fields; legacy mirrors for 1.1
proc ::tical::model::_record {id type ev extra} {
    set ev [::tical::event::normalize $ev]
    dict set ev uid $id
    lassign [::tical::event::toLocal [dict get $ev dtstart]] date startTime
    set endTime ""
    if {[dict exists $ev dtend] && ![dict get $ev allday]} {
        set endTime [lindex [::tical::event::toLocal [dict get $ev dtend]] 1]
    }
    set rec [dict merge [dict create id $id type $type] $ev $extra]
    # 1.0.1 field names (deprecated)
    dict set rec title [dict get $ev summary]
    dict set rec date $date
    if {$type eq "appointment"} {
        dict set rec startTime $startTime
        dict set rec endTime $endTime
    } else {
        dict set rec allDay [dict get $ev allday]
        dict set rec category [expr {[dict exists $ev categories] ? [lindex [dict get $ev categories] 0] : ""}]
    }
    return $rec
}

proc ::tical::model::createAppointment {args} {
    set in [_input {
        -summary {} -dtstart {} -dtend {} -allday {}
        -title {} -date {} -startTime {} -endTime {}
        -location {} -description {} -reminder 0
    } $args]
    if {!(([dict exists $in summary] || [dict exists $in title])
          && ([dict exists $in dtstart] || [dict exists $in date]))} {
        return -code error -errorcode {TICAL MODEL ARGS} \
            "appointment requires -summary and -dtstart (or -title and -date)"
    }
    set reminder [expr {[dict exists $in reminder] ? [dict get $in reminder] : 0}]
    variable nextId
    set id "appt-$nextId"
    set rec [_record $id appointment [dict remove $in reminder] \
        [dict create reminder $reminder created [clock seconds]]]
    incr nextId
    variable appointments
    set appointments($id) $rec
    return $id
}

proc ::tical::model::getAppointment {id} {
    variable appointments
    if {![info exists appointments($id)]} {
        return -code error -errorcode {TICAL MODEL NOTFOUND} "appointment not found: $id"
    }
    return $appointments($id)
}

# Update fields: event fields (-summary, -dtstart ...) or, for 1.1, the
# older ones (-title, -date, -startTime, -endTime). Unknown fields and a
# missing value are an error {TICAL MODEL OPTION} (were ignored up to 1.1).
proc ::tical::model::updateAppointment {id args} {
    variable appointments
    if {![info exists appointments($id)]} {
        return -code error -errorcode {TICAL MODEL NOTFOUND} "appointment not found: $id"
    }
    set rec $appointments($id)
    set core [dict remove $rec id type title date startTime endTime reminder created]
    set legacy [dict create]
    if {[llength $args] % 2} {
        return -code error -errorcode {TICAL MODEL OPTION} \
            "missing value for option \"[lindex $args end]\""
    }
    set known {summary dtstart dtend allday categories location description status
               title date startTime endTime reminder}
    foreach k [dict keys $rec] {
        if {$k ni {id type created uid} && $k ni $known} { lappend known $k }
    }
    foreach {key val} $args {
        if {[string trimleft $key -] ni $known} {
            return -code error -errorcode {TICAL MODEL OPTION} \
                "unknown option \"$key\", must be -[join [lsort $known] {, -}]"
        }
    }
    foreach {key val} $args {
        set field [string trimleft $key -]
        switch -- $field {
            title { dict set core summary $val }
            date - startTime - endTime { dict set legacy $field $val }
            reminder { dict set rec reminder $val }
            default { dict set core $field $val }
        }
    }
    if {[dict size $legacy]} {
        # rebuild start/end from date + times (current values as default)
        foreach f {date startTime endTime} {
            if {![dict exists $legacy $f]} { dict set legacy $f [dict get $rec $f] }
        }
        set core [dict remove $core dtstart dtend allday]
        dict set core date [dict get $legacy date]
        if {[dict get $legacy startTime] ne ""} { dict set core startTime [dict get $legacy startTime] }
        if {[dict get $legacy endTime] ne ""}   { dict set core endTime [dict get $legacy endTime] }
    } elseif {[dict exists $core dtstart] && [lsearch -exact [lmap {k v} $args {string trimleft $k -}] dtstart] >= 0} {
        # a new dtstart decides all-day again
        dict unset core allday
    }
    if {[dict exists $core dtend] && [dict get $core dtend] eq ""} { dict unset core dtend }
    set appointments($id) [_record $id appointment $core \
        [dict create reminder [dict get $rec reminder] created [dict get $rec created]]]
    return $id
}

proc ::tical::model::deleteAppointment {id} {
    variable appointments
    if {![info exists appointments($id)]} {
        return -code error -errorcode {TICAL MODEL NOTFOUND} "appointment not found: $id"
    }
    unset appointments($id)
    return
}

proc ::tical::model::listAppointments {{pattern *}} {
    variable appointments
    set result {}
    foreach id [lsort [array names appointments $pattern]] {
        lappend result $id $appointments($id)
    }
    return $result
}

# Appointments on a day (YYYY-MM-DD or YYYYMMDD; local start day).
proc ::tical::model::getAppointmentsByDate {date} {
    variable appointments
    set date [lindex [::tical::event::toLocal $date] 0]
    set result {}
    foreach id [lsort [array names appointments]] {
        set appt $appointments($id)
        if {[dict get $appt date] eq $date} {
            lappend result $id $appt
        }
    }
    return $result
}

proc ::tical::model::createEvent {args} {
    set in [_input {
        -summary {} -dtstart {} -dtend {} -allday {} -categories {}
        -title {} -date {} -allDay {} -category {} -color {}
        -location {} -description {}
    } $args]
    if {!(([dict exists $in summary] || [dict exists $in title])
          && ([dict exists $in dtstart] || [dict exists $in date]))} {
        return -code error -errorcode {TICAL MODEL ARGS} \
            "event requires -summary and -dtstart (or -title and -date)"
    }
    set color [expr {[dict exists $in color] ? [dict get $in color] : ""}]
    variable nextId
    set id "evt-$nextId"
    set rec [_record $id event [dict remove $in color] \
        [dict create color $color created [clock seconds]]]
    incr nextId
    variable events
    set events($id) $rec
    return $id
}

proc ::tical::model::getEvent {id} {
    variable events
    if {![info exists events($id)]} {
        return -code error -errorcode {TICAL MODEL NOTFOUND} "event not found: $id"
    }
    return $events($id)
}

proc ::tical::model::deleteEvent {id} {
    variable events
    if {![info exists events($id)]} {
        return -code error -errorcode {TICAL MODEL NOTFOUND} "event not found: $id"
    }
    unset events($id)
    return
}

proc ::tical::model::listEvents {{pattern *}} {
    variable events
    set result {}
    foreach id [lsort [array names events $pattern]] {
        lappend result $id $events($id)
    }
    return $result
}

# All appointments and events as event dicts (tical::event format, uid = id),
# e.g. for tical::view::month::getData ... -events [tical::model::toEvents].
proc ::tical::model::toEvents {} {
    variable appointments
    variable events
    set out {}
    foreach arr {appointments events} {
        foreach id [lsort [array names $arr]] {
            set rec [set ${arr}($id)]
            lappend out [dict remove $rec id type created reminder \
                title date startTime endTime allDay category]
        }
    }
    return $out
}

proc ::tical::model::clearAll {} {
    variable appointments
    variable events
    array unset appointments
    array unset events
}
