package require Tk
package require tical::util 1.1
package require tical::locale 1.0

namespace eval ::tical::render::canvas {
    namespace export draw setSelectMode getSelection setSelection \
        clearSelection setSelectionCommand setCallback
    variable styleOptions
    variable onDayClickCallback
    variable state   ;# per-widget: $w,mode $w,sel $w,cmd $w,anchor $w,box,DATE
}

proc ::tical::render::canvas::init {{fontsize 12}} {
    variable styleOptions
    
    set cellW [expr {$fontsize * 2.5}]
    set cellH [expr {$fontsize * 2.0}]
    set leftW [expr {$cellW * 0.75}]
    set topH [expr {$cellH * 2.5}]
    
    set fontTitle [list Arial $fontsize bold]
    set fontDay [list Arial [expr {$fontsize - 1}]]
    
    set styleOptions [dict create \
        cellW $cellW \
        cellH $cellH \
        leftW $leftW \
        topH $topH \
        fontTitle $fontTitle \
        fontDay $fontDay \
        colorDefault "#FFFFFF" \
        colorToday "#FFFFCC" \
        colorHoliday "#FFEBEE" \
        colorAdjacent "#F5F5F5" \
        colorWeekend "#E6F3FF" \
        textDefault "black" \
        textToday "red" \
        textHoliday "#D32F2F" \
        textAdjacent "gray" \
        outlineDefault "gray80" \
        outlineToday "red" \
        outlineHoliday "#D32F2F" \
        ringWidth 1.5 \
        selectColor "#1565C0" \
        selectWidth 2 \
        selectStipple gray25 \
        eventColor "#2E7D32" \
        fontEvent [list Arial [expr {max(6, $fontsize - 3)}]] \
    ]
}

# Day-click callback (command prefix, called with the canvas and the date,
# in select mode "none"):
#   setCallback CMD      for every canvas (as up to 1.1)
#   setCallback W CMD    for canvas W only; it wins over the global one;
#                        "" removes it. Removed with the canvas.
proc ::tical::render::canvas::setCallback {args} {
    variable onDayClickCallback
    variable state
    switch -- [llength $args] {
        1 { set onDayClickCallback [lindex $args 0] }
        2 {
            lassign $args w cmd
            if {![string match .* $w]} {
                # the old mistake: setCallback {w date} {body}
                return -code error -errorcode {TICAL RENDER ARGS} \
                    "setCallback: \"$w\" is not a widget path; pass one command\
                    prefix (setCallback CMD) or a canvas and one (setCallback .c CMD)"
            }
            if {$cmd eq ""} { unset -nocomplain state($w,click); return }
            set state($w,click) $cmd
            if {[winfo exists $w] && ![info exists state($w,bound)]} {
                bind $w <Destroy> +[list ::tical::render::canvas::_cleanup %W]
                set state($w,bound) 1
            }
        }
        default {
            return -code error -errorcode {TICAL RENDER ARGS} \
                "wrong # args: should be \"setCallback ?w? callback\""
        }
    }
    return
}

# Options: -interactive 0|1, -fontsize N, -weekNumbers 0|1. Unknown options
# are an error {TICAL RENDER OPTION}. Events in the cells of the view are
# drawn as titles where there is room (week, day) and as dots otherwise
# (month); tag "event".
proc ::tical::render::canvas::draw {w viewSpec args} {
    array set opts [::tical::util::options render::canvas::draw \
        {-interactive 0 -fontsize 12 -weekNumbers 0} $args {TICAL RENDER OPTION}]
    if {![string is integer -strict $opts(-fontsize)] || $opts(-fontsize) < 4} {
        return -code error -errorcode {TICAL RENDER OPTION} \
            "render::canvas::draw: -fontsize must be an integer >= 4, got \"$opts(-fontsize)\""
    }
    
    init $opts(-fontsize)
    
    $w delete all
    
    if {![dict exists $viewSpec type]} {
        return -code error -errorcode {TICAL RENDER SPEC} \
            "render::canvas::draw: ViewSpec missing field: type"
    }
    
    set type [dict get $viewSpec type]
    
    switch -exact -- $type {
        "month-grid" {
            drawMonth $w $viewSpec opts
        }
        "week-grid" {
            drawWeek $w $viewSpec opts
        }
        "day-grid" {
            drawDay $w $viewSpec opts
        }
        default {
            return -code error -errorcode {TICAL RENDER TYPE} \
                "render::canvas::draw: expected type month-grid, week-grid or day-grid, got \"$type\""
        }
    }
}

proc ::tical::render::canvas::drawMonth {w viewSpec optsName} {
    upvar 1 $optsName o
    
    variable styleOptions
    variable state
    array unset state $w,box,*
    if {![info exists state($w,bound)]} {
        bind $w <Destroy> +[list ::tical::render::canvas::_cleanup %W]
        set state($w,bound) 1
    }
    set cellW [dict get $styleOptions cellW]
    set cellH [dict get $styleOptions cellH]
    set leftW [dict get $styleOptions leftW]
    set topH [dict get $styleOptions topH]
    set fontTitle [dict get $styleOptions fontTitle]
    set fontDay [dict get $styleOptions fontDay]
    
    set year [dict get $viewSpec year]
    set month [dict get $viewSpec month]
    set cells [dict get $viewSpec cells]
    
    # Monats- und Tagesnamen aus tical::locale (folgt tical::config locale),
    # Spaltenfolge aus den Zellen der View (Wochenstart der View)
    set monthName [::tical::locale::getMonthName $month]
    
    set headerText "$monthName $year"
    set headerX [expr {$leftW + 3.5 * $cellW}]
    set headerY [expr {$topH * 0.25}]
    $w create text $headerX $headerY -text $headerText \
        -anchor center -font $fontTitle -fill black -tags title
    
    set weekdayNames [::tical::locale::getWeekdaysShort \
        [::tical::util::gridStartDow $cells]]
    set startX $leftW
    if {$o(-weekNumbers)} {
        set startX [expr {$leftW + $cellW * 0.5}]
    }
    
    for {set col 0} {$col < 7} {incr col} {
        set x [expr {$startX + $col * $cellW + $cellW / 2}]
        set y [expr {$topH * 0.75}]
        $w create text $x $y -text [lindex $weekdayNames $col] \
            -anchor center -font $fontTitle -fill black -tags weekday
    }
    
    set row 0
    set col 0
    set lastWeek ""
    
    foreach cellData $cells {
        set date [dict get $cellData date]
        set inMonth [dict get $cellData inMonth]
        set dow [dict get $cellData dow]
        set week [dict get $cellData week]
        
        set x [expr {$startX + $col * $cellW}]
        set y [expr {$topH + $row * $cellH}]
        
        if {$o(-weekNumbers) && $col == 0 && [set week [::tical::util::rowWeek $cells [expr {$row * 7}]]] ne ""} {
            set weekX [expr {$leftW * 0.6}]
            set weekY [expr {$y + $cellH / 2}]
            $w create text $weekX $weekY -text [format %02d $week] \
                -anchor center -font $fontDay -fill gray -tags weeknr
        }
        
        set fill [dict get $styleOptions colorDefault]
        set textColor [dict get $styleOptions textDefault]
        set outline [dict get $styleOptions outlineDefault]
        
        if {!$inMonth} {
            set fill [dict get $styleOptions colorAdjacent]
            set textColor [dict get $styleOptions textAdjacent]
        } elseif {$dow == 6 || $dow == 7} {
            set fill [dict get $styleOptions colorWeekend]
        }
        
        # Holiday marker
        if {[dict exists $cellData markers] && "holiday" in [dict get $cellData markers]} {
            set fill [dict get $styleOptions colorHoliday]
            set textColor [dict get $styleOptions textHoliday]
            set outline [dict get $styleOptions outlineHoliday]
        }
        
        # Today overrides everything
        if {[dict exists $cellData markers] && "today" in [dict get $cellData markers]} {
            set fill [dict get $styleOptions colorToday]
            set textColor [dict get $styleOptions textToday]
            set outline [dict get $styleOptions outlineToday]
        }
        
        set tag "day-$date"
        set rectTag "rect-$date"
        
        $w create rectangle $x $y [expr {$x + $cellW}] [expr {$y + $cellH}] \
            -fill $fill -outline $outline -width 1 -tags [list $tag $rectTag daycell]
        
        # empty cell (view with -showAdjacentDays 0): no day number, no bindings
        set dd ""
        if {$date ne ""} { scan $date "%d-%d-%d" yy mm dd }
        $w create text [expr {$x + $cellW / 2}] [expr {$y + $cellH / 2}] \
            -text $dd -fill $textColor -font $fontDay -anchor center -tags [list $tag daytext]
        _drawEvents $w $cellData $x $y $cellW $cellH $tag
        
        if {$date ne ""} {
            set state($w,box,$date) [list $x $y [expr {$x + $cellW}] [expr {$y + $cellH}]]
        }
        
        if {$o(-interactive) && $date ne ""} {
            $w bind $tag <Button-1>       [list ::tical::render::canvas::onDayClick $w $date 0]
            $w bind $tag <Shift-Button-1> [list ::tical::render::canvas::onDayClick $w $date 1]
            $w bind $tag <Enter> [list ::tical::render::canvas::onDayEnter $w $date]
            $w bind $tag <Leave> [list ::tical::render::canvas::onDayLeave $w $date]
        }
        
        incr col
        if {$col >= 7} {
            set col 0
            incr row
        }
    }
    
    set totalW [expr {$startX + 7 * $cellW + $leftW * 0.5}]
    set totalH [expr {$topH + 6 * $cellH + $topH * 0.5}]
    
    $w configure -scrollregion [list 0 0 $totalW $totalH]
    _applySelection $w
}

proc ::tical::render::canvas::onDayClick {w date {shift 0}} {
    variable state
    variable onDayClickCallback
    set mode [expr {[info exists state($w,mode)] ? $state($w,mode) : "none"}]
    if {$date eq ""} return

    if {$mode eq "none"} {
        # just notify, no persistent selection; the canvas's own callback
        # wins over the global one
        if {[info exists state($w,click)]} {
            uplevel #0 [list {*}$state($w,click) $w $date]
        } elseif {[info exists onDayClickCallback] && $onDayClickCallback ne ""} {
            uplevel #0 [list {*}$onDayClickCallback $w $date]
        }
        return
    }

    if {$mode eq "single"} {
        set state($w,sel) [dict create $date 1]
        set state($w,anchor) $date
    } else {
        # multiple
        if {$shift && [info exists state($w,anchor)] && $state($w,anchor) ne ""} {
            foreach d [tical::util::dateRange $state($w,anchor) $date] {
                dict set state($w,sel) $d 1
            }
        } elseif {[info exists state($w,sel)] && [dict exists $state($w,sel) $date]} {
            dict unset state($w,sel) $date
            set state($w,anchor) $date
        } else {
            dict set state($w,sel) $date 1
            set state($w,anchor) $date
        }
    }
    _applySelection $w
    _fireSel $w
}

# --- selection public API ---------------------------------------------------

proc ::tical::render::canvas::setSelectMode {w mode} {
    variable state
    if {$mode ni {none single multiple}} {
        return -code error -errorcode {TICAL RENDER OPTION} \
            "selectmode must be none, single or multiple, got \"$mode\""
    }
    set state($w,mode) $mode
    if {$mode eq "none"} { set state($w,sel) {}; _applySelection $w }
    return $mode
}

proc ::tical::render::canvas::getSelection {w} {
    variable state
    if {![info exists state($w,sel)]} { return {} }
    return [lsort [dict keys $state($w,sel)]]
}

proc ::tical::render::canvas::setSelection {w dates} {
    variable state
    set state($w,sel) {}
    foreach d [tical::util::expandSelection $dates] { dict set state($w,sel) $d 1 }
    _applySelection $w
    return [getSelection $w]
}

proc ::tical::render::canvas::clearSelection {w} {
    variable state
    set state($w,sel) {}
    _applySelection $w
}

proc ::tical::render::canvas::setSelectionCommand {w cmd} {
    variable state
    set state($w,cmd) $cmd
}

proc ::tical::render::canvas::_fireSel {w} {
    variable state
    if {[info exists state($w,cmd)] && $state($w,cmd) ne ""} {
        uplevel #0 [list {*}$state($w,cmd) $w [getSelection $w]]
    }
}

proc ::tical::render::canvas::_applySelection {w} {
    variable state
    variable styleOptions
    catch {$w delete seloverlay}
    if {![info exists state($w,sel)]} return
    set col [dict get $styleOptions selectColor]
    set wd  [dict get $styleOptions selectWidth]
    set stp [dict get $styleOptions selectStipple]
    foreach date [dict keys $state($w,sel)] {
        if {![info exists state($w,box,$date)]} continue
        lassign $state($w,box,$date) x1 y1 x2 y2
        $w create rectangle $x1 $y1 $x2 $y2 \
            -outline $col -width $wd -fill $col -stipple $stp \
            -tags [list seloverlay sel-$date]
    }
    catch {$w raise daytext}
}

proc ::tical::render::canvas::_cleanup {w} {
    variable state
    array unset state $w,*
}

proc ::tical::render::canvas::onDayEnter {w date} {
    variable state
    catch {
        set state($w,hover,$date) \
            [list [$w itemcget rect-$date -outline] [$w itemcget rect-$date -width]]
    }
    $w itemconfigure rect-$date -outline blue -width 2
}

proc ::tical::render::canvas::onDayLeave {w date} {
    variable state
    variable styleOptions
    if {[info exists state($w,hover,$date)]} {
        lassign $state($w,hover,$date) ol wd
        unset state($w,hover,$date)
    } else {
        set ol [dict get $styleOptions outlineDefault]
        set wd 1
    }
    catch {$w itemconfigure rect-$date -outline $ol -width $wd}
}

proc ::tical::render::canvas::drawWeek {w viewSpec optsName} {
    upvar 1 $optsName o
    
    variable styleOptions
    variable state
    array unset state $w,box,*
    if {![info exists state($w,bound)]} {
        bind $w <Destroy> +[list ::tical::render::canvas::_cleanup %W]
        set state($w,bound) 1
    }
    set cellW [expr {[dict get $styleOptions cellW] * 1.8}]
    set cellH [expr {[dict get $styleOptions cellH] * 1.5}]
    # wider columns when there are event titles to show
    foreach c [dict get $viewSpec cells] {
        if {[dict exists $c events] && [llength [dict get $c events]]} {
            set cellW [expr {[dict get $styleOptions cellW] * 3.2}]
            break
        }
    }
    set leftW [dict get $styleOptions leftW]
    set topH [expr {[dict get $styleOptions topH] * 1.2}]
    set fontTitle [dict get $styleOptions fontTitle]
    set fontDay [dict get $styleOptions fontDay]
    
    set year [dict get $viewSpec year]
    set week [dict get $viewSpec week]
    set cells [dict get $viewSpec cells]
    
    # room for event titles below the date: one line per event (max. 6)
    set lineH [expr {[font metrics [dict get $styleOptions fontEvent] -linespace] + 1}]
    set nEv 0
    foreach c $cells {
        if {[dict exists $c events]} { set nEv [expr {max($nEv, [llength [dict get $c events]])}] }
    }
    set nEv [expr {min($nEv, 6)}]
    set boxH [expr {$cellH * 1.5 + $nEv * $lineH}]

    set headerText "[::tical::locale::getWeekLabel] $week, $year"
    set headerX [expr {$leftW + 3.5 * $cellW}]
    set headerY [expr {$topH * 0.25}]
    $w create text $headerX $headerY -text $headerText \
        -anchor center -font $fontTitle -fill black -tags title
    
    set weekdayNames [::tical::locale::getWeekdaysShort]   ;# Mo..So, dow 1..7
    
    set col 0
    foreach cellData $cells {
        set date [dict get $cellData date]
        set dow [dict get $cellData dow]
        
        set x [expr {$leftW + $col * $cellW}]
        set y $topH
        
        set fill [dict get $styleOptions colorDefault]
        set textColor [dict get $styleOptions textDefault]
        set outline [dict get $styleOptions outlineDefault]
        
        if {$dow == 6 || $dow == 7} {
            set fill [dict get $styleOptions colorWeekend]
        }
        
        if {[dict exists $cellData markers] && "holiday" in [dict get $cellData markers]} {
            set fill [dict get $styleOptions colorHoliday]
            set textColor [dict get $styleOptions textHoliday]
            set outline [dict get $styleOptions outlineHoliday]
        }
        
        if {[dict exists $cellData markers] && "today" in [dict get $cellData markers]} {
            set fill [dict get $styleOptions colorToday]
            set textColor [dict get $styleOptions textToday]
            set outline [dict get $styleOptions outlineToday]
        }
        
        set tag "day-$date"
        set rectTag "rect-$date"
        
        $w create rectangle $x $y [expr {$x + $cellW}] [expr {$y + $boxH}] \
            -fill $fill -outline $outline -width 1 -tags [list $tag $rectTag daycell]
        
        set dowName [lindex $weekdayNames [expr {$dow - 1}]]
        $w create text [expr {$x + $cellW / 2}] [expr {$y + $cellH * 0.3}] \
            -text $dowName -fill gray -font $fontDay -anchor center -tags $tag
        
        scan $date "%d-%d-%d" yy mm dd
        $w create text [expr {$x + $cellW / 2}] [expr {$y + $cellH * 0.75}] \
            -text "$dd.$mm" -fill $textColor -font $fontTitle -anchor center -tags [list $tag daytext]
        _drawEventTitles $w $cellData [expr {$x + 3}] [expr {$y + $cellH * 1.5}] \
            [expr {$cellW - 6}] $nEv $tag
        
        set state($w,box,$date) [list $x $y [expr {$x + $cellW}] [expr {$y + $boxH}]]
        if {$o(-interactive)} {
            $w bind $tag <Button-1>       [list ::tical::render::canvas::onDayClick $w $date 0]
            $w bind $tag <Shift-Button-1> [list ::tical::render::canvas::onDayClick $w $date 1]
            $w bind $tag <Enter> [list ::tical::render::canvas::onDayEnter $w $date]
            $w bind $tag <Leave> [list ::tical::render::canvas::onDayLeave $w $date]
        }
        
        incr col
    }
    
    set totalW [expr {$leftW + 7 * $cellW + $leftW * 0.5}]
    set totalH [expr {$topH + $boxH + $cellH * 0.5}]
    
    $w configure -scrollregion [list 0 0 $totalW $totalH]
    _applySelection $w
}

proc ::tical::render::canvas::drawDay {w viewSpec optsName} {
    upvar 1 $optsName o
    
    variable styleOptions
    set cellW [expr {[dict get $styleOptions cellW] * 2}]
    set cellH [expr {[dict get $styleOptions cellH] * 1.2}]
    set leftW [dict get $styleOptions leftW]
    set topH [expr {[dict get $styleOptions topH] * 1.2}]
    set fontTitle [dict get $styleOptions fontTitle]
    set fontDay [dict get $styleOptions fontDay]
    
    set date [dict get $viewSpec date]
    set year [dict get $viewSpec year]
    set month [dict get $viewSpec month]
    set day [dict get $viewSpec day]
    set cells [dict get $viewSpec cells]
    
    set headerText "$day.$month.$year"
    set headerX [expr {$leftW + $cellW * 2}]
    set headerY [expr {$topH * 0.3}]
    $w create text $headerX $headerY -text $headerText \
        -anchor center -font $fontTitle -fill black -tags title
    
    # all-day events (and days of multi-day events) under the title
    set allday {}
    if {[dict exists $viewSpec events]} {
        foreach ev [dict get $viewSpec events] {
            if {[dict get $ev allday] || [dict get $ev part] eq "middle"} { lappend allday $ev }
        }
    }
    if {[llength $allday]} {
        _drawEventTitles $w [dict create events $allday] $leftW [expr {$topH * 0.55}] \
            [expr {$cellW * 4}] [llength $allday] allday
        set topH [expr {$topH + [llength $allday] * \
            ([font metrics [dict get $styleOptions fontEvent] -linespace] + 1)}]
    }
    
    set row 0
    foreach cellData $cells {
        set hour [dict get $cellData hour]
        set time [dict get $cellData time]
        set markers [dict get $cellData markers]
        
        set y [expr {$topH + $row * $cellH}]
        
        set fill [dict get $styleOptions colorDefault]
        set textColor [dict get $styleOptions textDefault]
        
        if {"holiday" in $markers} {
            set fill [dict get $styleOptions colorHoliday]
        }
        if {"today" in $markers} {
            set fill [dict get $styleOptions colorToday]
        }
        
        set tag "hour-$hour"
        
        $w create rectangle $leftW $y [expr {$leftW + $cellW * 4}] [expr {$y + $cellH * 0.9}] \
            -fill $fill -outline gray80 -width 1 -tags [list $tag hourcell]
        
        $w create text [expr {$leftW + 10}] [expr {$y + $cellH * 0.45}] \
            -text $time -fill $textColor -font $fontDay -anchor w -tags $tag
        if {[dict exists $cellData events] && [llength [dict get $cellData events]]} {
            set titles {}
            foreach ev [dict get $cellData events] {
                set t [dict get $ev summary]
                if {[dict get $ev time] ne ""} { set t "[dict get $ev time] $t" }
                if {[dict get $ev part] in {middle end}} { set t "\u2026 $t" }
                lappend titles $t
            }
            set tx [expr {$leftW + 10 + [font measure $fontDay "00:00"] + 10}]
            $w create text $tx [expr {$y + $cellH * 0.45}] \
                -text [_fit [join $titles "; "] [dict get $styleOptions fontDay] \
                    [expr {$leftW + $cellW * 4 - $tx - 4}]] \
                -fill [dict get $styleOptions eventColor] -font $fontDay -anchor w \
                -tags [list $tag event]
        }
        
        incr row
    }
    
    set totalW [expr {$leftW + $cellW * 5}]
    set totalH [expr {$topH + [llength $cells] * $cellH + $topH}]
    
    $w configure -scrollregion [list 0 0 $totalW $totalH]
}

# --- events -------------------------------------------------------------

# Shorten text to fit into width pixels (ellipsis).
proc ::tical::render::canvas::_fit {text font width} {
    if {[font measure $font $text] <= $width} { return $text }
    set ell "\u2026"
    while {[string length $text] > 0 && [font measure $font $text$ell] > $width} {
        set text [string range $text 0 end-1]
    }
    return $text$ell
}

# Month cell: up to three dots at the bottom (titles do not fit).
proc ::tical::render::canvas::_drawEvents {w cellData x y cellW cellH tag} {
    variable styleOptions
    if {![dict exists $cellData events]} return
    set n [llength [dict get $cellData events]]
    if {$n == 0} return
    set col [dict get $styleOptions eventColor]
    set r [expr {max(1.5, $cellH / 16.0)}]
    set k [expr {min($n, 3)}]
    set cy [expr {$y + $cellH - $r - 1.5}]
    for {set i 0} {$i < $k} {incr i} {
        set cx [expr {$x + $cellW / 2.0 + ($i - ($k - 1) / 2.0) * 3 * $r}]
        $w create oval [expr {$cx - $r}] [expr {$cy - $r}] [expr {$cx + $r}] [expr {$cy + $r}] \
            -fill $col -outline $col -tags [list $tag event]
    }
}

# Titles one per line from (x,y), at most maxLines (last line "+N").
proc ::tical::render::canvas::_drawEventTitles {w cellData x y width maxLines tag} {
    variable styleOptions
    if {![dict exists $cellData events]} return
    set evs [dict get $cellData events]
    if {![llength $evs] || $maxLines < 1} return
    set font [dict get $styleOptions fontEvent]
    set lineH [expr {[font metrics $font -linespace] + 1}]
    set i 0
    foreach ev $evs {
        if {$i == $maxLines - 1 && [llength $evs] > $maxLines} {
            set t "+[expr {[llength $evs] - $i}]"
        } else {
            set t [dict get $ev summary]
            if {[dict get $ev time] ne ""} { set t "[dict get $ev time] $t" }
            if {[dict get $ev part] in {middle end}} { set t "\u2026 $t" }
        }
        $w create text $x [expr {$y + $i * $lineH}] -text [_fit $t $font $width] \
            -anchor nw -font $font -fill [dict get $styleOptions eventColor] \
            -tags [list $tag event]
        if {[incr i] >= $maxLines} break
    }
}

package provide tical::render::canvas 1.1.1
package require Tcl 8.6-

