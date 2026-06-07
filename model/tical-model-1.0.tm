package provide tical::model 1.0
package require Tcl 8.6-

namespace eval ::tical::model {
    namespace export createAppointment createEvent
    variable appointments
    variable events
    variable nextId 1
    
    array set appointments {}
    array set events {}
}

proc ::tical::model::createAppointment {args} {
    array set o {
        -title {}
        -date {}
        -startTime {}
        -endTime {}
        -location {}
        -description {}
        -reminder 0
    }
    array set o $args
    
    if {$o(-title) eq {} || $o(-date) eq {}} {
        error "Appointment requires -title and -date"
    }
    
    variable nextId
    set id "appt-$nextId"
    incr nextId
    
    set appointment [dict create \
        id $id \
        type "appointment" \
        title $o(-title) \
        date $o(-date) \
        startTime $o(-startTime) \
        endTime $o(-endTime) \
        location $o(-location) \
        description $o(-description) \
        reminder $o(-reminder) \
        created [clock seconds]]
    
    variable appointments
    set appointments($id) $appointment
    
    return $id
}

proc ::tical::model::getAppointment {id} {
    variable appointments
    if {![info exists appointments($id)]} {
        error "Appointment $id not found"
    }
    return $appointments($id)
}

proc ::tical::model::updateAppointment {id args} {
    variable appointments
    if {![info exists appointments($id)]} {
        error "Appointment $id not found"
    }
    
    set appointment $appointments($id)
    
    foreach {key val} $args {
        set field [string trimleft $key -]
        if {[dict exists $appointment $field]} {
            dict set appointment $field $val
        }
    }
    
    set appointments($id) $appointment
    return $id
}

proc ::tical::model::deleteAppointment {id} {
    variable appointments
    if {![info exists appointments($id)]} {
        error "Appointment $id not found"
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

proc ::tical::model::getAppointmentsByDate {date} {
    variable appointments
    set result {}
    foreach {id appt} [array get appointments] {
        if {[dict get $appt date] eq $date} {
            lappend result $id $appt
        }
    }
    return $result
}

proc ::tical::model::createEvent {args} {
    array set o {
        -title {}
        -date {}
        -allDay 1
        -category {}
        -color {}
    }
    array set o $args
    
    if {$o(-title) eq {} || $o(-date) eq {}} {
        error "Event requires -title and -date"
    }
    
    variable nextId
    set id "evt-$nextId"
    incr nextId
    
    set event [dict create \
        id $id \
        type "event" \
        title $o(-title) \
        date $o(-date) \
        allDay $o(-allDay) \
        category $o(-category) \
        color $o(-color) \
        created [clock seconds]]
    
    variable events
    set events($id) $event
    
    return $id
}

proc ::tical::model::getEvent {id} {
    variable events
    if {![info exists events($id)]} {
        error "Event $id not found"
    }
    return $events($id)
}

proc ::tical::model::deleteEvent {id} {
    variable events
    if {![info exists events($id)]} {
        error "Event $id not found"
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

proc ::tical::model::clearAll {} {
    variable appointments
    variable events
    array unset appointments
    array unset events
}


