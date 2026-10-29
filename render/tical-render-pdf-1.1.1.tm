# tical::render::pdf - PDF Calendar Renderer

package require Tcl 8.6-
package require pdf4tcl
package require tical::locale
package require tical::util 1.1

namespace eval ::tical::render::pdf {
    variable objCounter 0   ;# process-unique pdf object names (avoid clock collisions)
    namespace export create createQuarter createYear drawMonth drawWeek drawDay
    
    variable defaultOptions
    ::set defaultOptions [dict create \
        paper "a4" \
        orientation "portrait" \
        fontsize 10 \
        margin 20 \
        weekNumbers 1 \
        showGrid 1 \
        colorToday "#FFFFCC" \
        colorHoliday "#FFEBEE" \
        colorWeekend "#E6F3FF" \
        colorEvent "#E8F5E9" \
        colorEventText "#1B5E20" \
        events {}]
}

# Options as -key value (or key value). Unknown keys are an error
# {TICAL RENDER OPTION}; paper a4|a3|a5|letter (any case), orientation
# portrait|landscape. Option events (list of YYYY-MM-DD) is the form of
# 1.0.1 and is still accepted in 1.1 (deprecated): the events now come from
# the cells of the view (getData ... -events).
proc ::tical::render::pdf::_options {who arglist {extra {}}} {
    variable defaultOptions
    if {[llength $arglist] % 2} {
        return -code error -errorcode {TICAL RENDER OPTION} \
            "$who: missing value for option \"[lindex $arglist end]\""
    }
    ::set norm {}
    foreach {k v} $arglist { lappend norm [string trimleft $k -] $v }
    ::set defaults [dict merge $defaultOptions $extra]
    dict for {k v} $norm {
        if {![dict exists $defaults $k]} {
            ::set known [lmap x [lsort [dict keys $defaults]] {string cat - $x}]
            return -code error -errorcode {TICAL RENDER OPTION} \
                "$who: unknown option \"-$k\", must be [join [lrange $known 0 end-1] {, }] or [lindex $known end]"
        }
    }
    ::set opts [dict merge $defaults $norm]
    dict set opts paper [string tolower [dict get $opts paper]]
    if {[dict get $opts paper] ni {a3 a4 a5 letter}} {
        return -code error -errorcode {TICAL RENDER OPTION} \
            "$who: bad paper \"[dict get $opts paper]\": must be a3, a4, a5 or letter"
    }
    if {[dict get $opts orientation] ni {portrait landscape}} {
        return -code error -errorcode {TICAL RENDER OPTION} \
            "$who: bad orientation \"[dict get $opts orientation]\": must be portrait or landscape"
    }
    return $opts
}

# Shorten text to fit width points in the current font ("..." appended).
proc ::tical::render::pdf::_fit {pdf text width} {
    if {[$pdf getStringWidth $text] <= $width} { return $text }
    while {[string length $text] > 0 && [$pdf getStringWidth "$text..."] > $width} {
        ::set text [string range $text 0 end-1]
    }
    return "$text..."
}

# Display text of an event entry of a cell: "09:00 Title", "... Title" for
# the continuation of a multi-day event.
proc ::tical::render::pdf::_eventText {ev} {
    ::set t [dict get $ev summary]
    if {[dict exists $ev time] && [dict get $ev time] ne ""} { ::set t "[dict get $ev time] $t" }
    if {[dict exists $ev part] && [dict get $ev part] in {middle end}} { ::set t "... $t" }
    return $t
}

proc ::tical::render::pdf::_cellEvents {cellData} {
    if {[dict exists $cellData events]} { return [dict get $cellData events] }
    return {}
}

proc ::tical::render::pdf::create {filename viewSpec args} {
    ::set opts [_options render::pdf::create $args]
    
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    
    ::set objName "ticalpdf[incr ::tical::render::pdf::objCounter]"
    # portrait/landscape-safe page from explicit oriented point dimensions
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pdf [pdf4tcl::new $objName -paper [list [lindex $dims 0]p [lindex $dims 1]p]]
    $pdf startPage
    
    ::set type [dict get $viewSpec type]
    
    switch -exact -- $type {
        "month-grid" {
            _drawMonthGrid $pdf $viewSpec $opts
        }
        "week-grid" {
            _drawWeekGrid $pdf $viewSpec $opts
        }
        "day-grid" {
            _drawDayGrid $pdf $viewSpec $opts
        }
        default {
            return -code error -errorcode {TICAL RENDER TYPE} \
                "render::pdf::create: expected type month-grid, week-grid or day-grid, got \"$type\""
        }
    }
    
    $pdf endPage
    $pdf write -file $filename
    $pdf destroy
    
    return $filename
}

proc ::tical::render::pdf::_drawMonthGrid {pdf viewSpec opts} {
    # full-page month = one month block filling the drawable area
    ::set margin [dict get $opts margin]
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pageWidth [expr {[lindex $dims 0] - 2 * $margin}]
    ::set pageHeight [expr {[lindex $dims 1] - 2 * $margin}]
    _drawMonthBlock $pdf $viewSpec $margin $margin $pageWidth $pageHeight $opts
}

# Draw one month into the box (x0,y0,blockW,blockH). Single source of truth for
# the month grid: localized names, weekend/today/holiday fills, per-cell border,
# week numbers and the top-left day number. Used by the full-page month as well
# as by the quarter and year layouts.
proc ::tical::render::pdf::_drawMonthBlock {pdf viewSpec x0 y0 blockW blockH opts} {
    ::set fontsize [dict get $opts fontsize]
    ::set weekNumbers [dict get $opts weekNumbers]
    ::set showGrid [dict get $opts showGrid]

    # events: from the cells of the view; option events (list of YYYY-MM-DD,
    # form of 1.0.1, deprecated) still marks those days
    ::set events {}
    if {[dict exists $opts events]} { ::set events [dict get $opts events] }
    ::set colorEvent "#E8F5E9"
    if {[dict exists $opts colorEvent]} { ::set colorEvent [dict get $opts colorEvent] }
    ::set colorEventText "#1B5E20"
    if {[dict exists $opts colorEventText]} { ::set colorEventText [dict get $opts colorEventText] }

    ::set cols 7
    if {$weekNumbers} { ::set cols 8 }
    ::set rows 6
    ::set headerHeight [expr {$fontsize * 3}]
    ::set weekdayHeight [expr {$fontsize * 2}]
    ::set gridHeight [expr {$blockH - $headerHeight - $weekdayHeight}]
    ::set cellW [expr {$blockW / double($cols)}]
    ::set cellH [expr {$gridHeight / double($rows)}]

    ::set year [dict get $viewSpec year]
    ::set month [dict get $viewSpec month]
    ::set cells [dict get $viewSpec cells]

    ::set monthName [::tical::locale::getMonthName $month]
    # black title and weekday names (the previous block may have left a
    # grey fill colour from its adjacent days)
    $pdf setFillColor #000000
    $pdf setFont [expr {$fontsize * 1.8}] Helvetica-Bold
    $pdf text "$monthName $year" -x [expr {$x0 + $blockW / 2.0}] \
        -y [expr {$y0 + $headerHeight / 2.0}] -align center

    # column order follows the view's week start (cells), not a fixed Monday
    ::set weekdayNames [::tical::locale::getWeekdaysShort \
        [::tical::util::gridStartDow $cells]]
    $pdf setFont $fontsize Helvetica-Bold

    ::set colStart 0
    if {$weekNumbers} {
        $pdf text [::tical::locale::getWeekLabel short] -x [expr {$x0 + $cellW / 2.0}] \
            -y [expr {$y0 + $headerHeight + $weekdayHeight / 2.0}] -align center
        ::set colStart 1
    }

    for {::set col 0} {$col < 7} {incr col} {
        ::set x [expr {$x0 + ($col + $colStart) * $cellW + $cellW / 2.0}]
        ::set y [expr {$y0 + $headerHeight + $weekdayHeight / 2.0}]
        $pdf text [lindex $weekdayNames $col] -x $x -y $y -align center
    }

    if {$showGrid} {
        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.5
        for {::set row 0} {$row <= $rows} {incr row} {
            ::set y [expr {$y0 + $headerHeight + $weekdayHeight + $row * $cellH}]
            $pdf line $x0 $y [expr {$x0 + $blockW}] $y
        }
        for {::set col 0} {$col <= $cols} {incr col} {
            ::set x [expr {$x0 + $col * $cellW}]
            ::set y1 [expr {$y0 + $headerHeight + $weekdayHeight}]
            ::set y2 [expr {$y1 + $gridHeight}]
            $pdf line $x $y1 $x $y2
        }
    }

    $pdf setFont $fontsize Helvetica

    ::set idx 0
    for {::set row 0} {$row < $rows} {incr row} {
        for {::set col 0} {$col < 7} {incr col} {
            ::set cellData [lindex $cells $idx]
            ::set date [dict get $cellData date]
            ::set day [lindex [split $date "-"] 2]
            ::set inMonth [dict get $cellData inMonth]
            ::set week [dict get $cellData week]
            ::set markers [dict get $cellData markers]

            ::set isToday [expr {"today" in $markers}]
            ::set isHoliday [expr {"holiday" in $markers}]
            ::set dow [dict get $cellData dow]
            ::set isWeekend [expr {$dow == 6 || $dow == 7}]
            ::set cellEvents [_cellEvents $cellData]
            ::set hasEvent [expr {($date ne "" && $date in $events) || [llength $cellEvents]}]

            ::set cellX [expr {$x0 + ($col + $colStart) * $cellW}]
            ::set cellY [expr {$y0 + $headerHeight + $weekdayHeight + $row * $cellH}]

            if {$isToday} {
                $pdf setFillColor [dict get $opts colorToday]
                $pdf rectangle $cellX $cellY $cellW $cellH -filled 1 -stroke 0
            } elseif {$hasEvent} {
                $pdf setFillColor $colorEvent
                $pdf rectangle $cellX $cellY $cellW $cellH -filled 1 -stroke 0
            } elseif {$isHoliday} {
                $pdf setFillColor [dict get $opts colorHoliday]
                $pdf rectangle $cellX $cellY $cellW $cellH -filled 1 -stroke 0
            } elseif {$isWeekend} {
                $pdf setFillColor [dict get $opts colorWeekend]
                $pdf rectangle $cellX $cellY $cellW $cellH -filled 1 -stroke 0
            }

            # border every day cell *on top* of any fill
            if {$showGrid} {
                $pdf setStrokeColor 0.7 0.7 0.7
                $pdf setLineWidth 0.5
                $pdf rectangle $cellX $cellY $cellW $cellH -filled 0 -stroke 1
            }

            if {$weekNumbers && $col == 0} { ::set week [::tical::util::rowWeek $cells $idx] }
            if {$weekNumbers && $col == 0 && $week ne ""} {
                $pdf setFillColor #000000
                $pdf setFont [expr {$fontsize * 0.8}] Helvetica
                ::set weekX [expr {$x0 + $cellW / 2.0}]
                ::set weekY [expr {$cellY + $cellH / 2.0}]
                $pdf text [format %02d $week] -x $weekX -y $weekY -align center
            }

            if {!$inMonth} {
                $pdf setFillColor 0.6 0.6 0.6
            } elseif {$isToday} {
                $pdf setFillColor #FF0000
            } elseif {$isHoliday} {
                $pdf setFillColor "#D32F2F"
            } else {
                $pdf setFillColor #000000
            }

            $pdf setFont $fontsize Helvetica
            ::set textX [expr {$cellX + $fontsize * 0.4}]
            ::set textY [expr {$cellY + $fontsize * 1.1}]
            if {$date ne ""} {
                $pdf text [scan $day %d] -x $textX -y $textY -align left
            }

            # event titles below the day number where there is room,
            # otherwise a dot (quarter and year blocks)
            if {[llength $cellEvents]} {
                ::set efs [expr {$fontsize * 0.7}]
                ::set lineH [expr {$efs * 1.15}]
                ::set lines [expr {int(($cellH - $fontsize * 1.4) / $lineH)}]
                $pdf setFillColor $colorEventText
                if {$lines >= 1 && $cellW >= $fontsize * 4} {
                    $pdf setFont $efs Helvetica
                    ::set n [llength $cellEvents]
                    for {::set k 0} {$k < min($n, $lines)} {incr k} {
                        if {$k == $lines - 1 && $n > $lines} {
                            ::set t "+[expr {$n - $k}]"
                        } else {
                            ::set t [_eventText [lindex $cellEvents $k]]
                        }
                        $pdf text [_fit $pdf $t [expr {$cellW - $fontsize * 0.6}]] \
                            -x $textX -y [expr {$textY + ($k + 1) * $lineH}] -align left
                    }
                } else {
                    ::set r [expr {max(0.8, $fontsize * 0.18)}]
                    $pdf circle [expr {$cellX + $cellW - $r * 2.5}] \
                        [expr {$cellY + $r * 2.5}] $r -filled 1 -stroke 0
                }
            }

            incr idx
        }
    }
}

proc ::tical::render::pdf::_drawWeekGrid {pdf viewSpec opts} {
    ::set margin [dict get $opts margin]
    ::set fontsize [dict get $opts fontsize]
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pageWidth [expr {[lindex $dims 0] - 2 * $margin}]
    ::set pageHeight [expr {[lindex $dims 1] - 2 * $margin}]
    
    ::set week [dict get $viewSpec week]
    ::set year [dict get $viewSpec year]
    ::set cells [dict get $viewSpec cells]
    
    $pdf setFont [expr {$fontsize * 1.5}] Helvetica-Bold
    $pdf text "[::tical::locale::getWeekLabel] $week, $year" -x [expr {$margin + $pageWidth / 2.0}] \
        -y [expr {$margin + $fontsize * 2}] -align center
    
    ::set cellH [expr {($pageHeight - $fontsize * 4) / 7.0}]
    ::set weekdayNames [::tical::locale::getWeekdaysLong]
    
    $pdf setFont $fontsize Helvetica
    
    ::set idx 0
    foreach cellData $cells {
        ::set date [dict get $cellData date]
        ::set day [lindex [split $date "-"] 2]
        ::set weekdayName [lindex $weekdayNames [expr {[dict get $cellData dow] - 1}]]
        
        ::set y [expr {$margin + $fontsize * 4 + $idx * $cellH}]
        
        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.5
        $pdf line $margin $y [expr {$margin + $pageWidth}] $y
        
        $pdf setFillColor #000000
        $pdf setFont $fontsize Helvetica
        $pdf text "$weekdayName, $date" -x [expr {$margin + 10}] \
            -y [expr {$y + $fontsize * 1.5}] -align left
        ::set evs [_cellEvents $cellData]
        if {[llength $evs]} {
            ::set efs [expr {$fontsize * 0.9}]
            ::set lineH [expr {$efs * 1.25}]
            ::set lines [expr {max(1, int(($cellH - $fontsize * 2) / $lineH))}]
            $pdf setFont $efs Helvetica
            $pdf setFillColor [dict get $opts colorEventText]
            ::set n [llength $evs]
            for {::set k 0} {$k < min($n, $lines)} {incr k} {
                if {$k == $lines - 1 && $n > $lines} {
                    ::set t "+[expr {$n - $k}]"
                } else {
                    ::set t [_eventText [lindex $evs $k]]
                }
                $pdf text [_fit $pdf $t [expr {$pageWidth - 40}]] -x [expr {$margin + 20}] \
                    -y [expr {$y + $fontsize * 1.5 + ($k + 1) * $lineH}] -align left
            }
            $pdf setFont $fontsize Helvetica
        }
        
        incr idx
    }
    
    ::set y [expr {$margin + $fontsize * 4 + 7 * $cellH}]
    $pdf line $margin $y [expr {$margin + $pageWidth}] $y
}

proc ::tical::render::pdf::_drawDayGrid {pdf viewSpec opts} {
    ::set margin [dict get $opts margin]
    ::set fontsize [dict get $opts fontsize]
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pageWidth [expr {[lindex $dims 0] - 2 * $margin}]
    ::set pageHeight [expr {[lindex $dims 1] - 2 * $margin}]
    
    ::set date [dict get $viewSpec date]
    ::set cells [dict get $viewSpec cells]
    
    $pdf setFont [expr {$fontsize * 1.5}] Helvetica-Bold
    $pdf text $date -x [expr {$margin + $pageWidth / 2.0}] \
        -y [expr {$margin + $fontsize * 2}] -align center
    
    # all-day events (and days inside multi-day events) under the title
    ::set top [expr {$fontsize * 4}]
    if {[dict exists $viewSpec events]} {
        $pdf setFont $fontsize Helvetica
        $pdf setFillColor [dict get $opts colorEventText]
        foreach ev [dict get $viewSpec events] {
            if {![dict get $ev allday] && [dict get $ev part] ne "middle"} continue
            $pdf text [_fit $pdf [_eventText $ev] [expr {$pageWidth - 20}]] \
                -x [expr {$margin + 10}] -y [expr {$margin + $top}] -align left
            ::set top [expr {$top + $fontsize * 1.4}]
        }
        $pdf setFillColor #000000
    }

    ::set cellH [expr {($pageHeight - $top) / double([llength $cells])}]
    
    $pdf setFont $fontsize Helvetica
    
    ::set idx 0
    foreach cellData $cells {
        ::set hour [dict get $cellData hour]
        ::set time [format "%02d:00" $hour]
        
        ::set y [expr {$margin + $top + $idx * $cellH}]
        
        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.5
        $pdf line $margin $y [expr {$margin + $pageWidth}] $y
        
        $pdf setFillColor #000000
        $pdf text $time -x [expr {$margin + 10}] \
            -y [expr {$y + $cellH / 2.0}] -align left
        ::set evs [_cellEvents $cellData]
        if {[llength $evs]} {
            $pdf setFillColor [dict get $opts colorEventText]
            ::set t [join [lmap ev $evs {_eventText $ev}] "; "]
            $pdf text [_fit $pdf $t [expr {$pageWidth - 70}]] -x [expr {$margin + 60}] \
                -y [expr {$y + $cellH / 2.0}] -align left
            $pdf setFillColor #000000
        }
        
        incr idx
    }
}

proc ::tical::render::pdf::_getPageDimensions {paper orientation} {
    array set sizes {
        a4 {595 842}
        letter {612 792}
        a3 {842 1191}
        a5 {420 595}
    }
    
    ::set paper [string tolower $paper]
    if {![info exists sizes($paper)]} {
        ::set paper "a4"
    }
    
    ::set dims $sizes($paper)
    ::set w [lindex $dims 0]
    ::set h [lindex $dims 1]
    
    if {$orientation eq "landscape"} {
        return [list $h $w]
    } else {
        return [list $w $h]
    }
}

proc ::tical::render::pdf::createQuarter {filename specList args} {
    # One page, three month blocks side by side. specList = 3 month viewSpecs.
    ::set given [lmap {k v} $args {string trimleft $k -}]
    ::set opts [_options render::pdf::createQuarter $args]
    if {"orientation" ni $given} { dict set opts orientation landscape }
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    ::set margin [dict get $opts margin]

    ::set objName "ticalpdf[incr ::tical::render::pdf::objCounter]"
    # build the page from explicit oriented point dimensions ({Wp Hp}); this is
    # portrait/landscape-safe across pdf4tcl versions (the "{a4 -landscape}" form
    # is not accepted by newer pdf4tcl)
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pdf [pdf4tcl::new $objName -paper [list [lindex $dims 0]p [lindex $dims 1]p]]
    $pdf startPage

    ::set pageWidth [expr {[lindex $dims 0] - 2 * $margin}]
    ::set pageHeight [expr {[lindex $dims 1] - 2 * $margin}]

    ::set fs [dict get $opts fontsize]
    ::set titleH [expr {$fs * 3}]
    ::set year [dict get [lindex $specList 0] year]
    ::set m1 [dict get [lindex $specList 0] month]
    ::set q [expr {($m1 - 1) / 3 + 1}]
    $pdf setFont [expr {$fs * 1.6}] Helvetica-Bold
    $pdf text "Q$q $year" -x [expr {$margin + $pageWidth / 2.0}] \
        -y [expr {$margin + $titleH / 2.0}] -align center

    ::set n [llength $specList]
    ::set gutter $fs
    ::set blockW [expr {($pageWidth - ($n - 1) * $gutter) / double($n)}]
    ::set blockH [expr {$pageHeight - $titleH}]
    # per-block font size (tunable): scales with block height, clamped
    ::set bfs [expr {min(13.0, max(7.0, $blockH / 24.0))}]
    ::set bopts [dict replace $opts fontsize $bfs]

    for {::set i 0} {$i < $n} {incr i} {
        ::set x0 [expr {$margin + $i * ($blockW + $gutter)}]
        ::set y0 [expr {$margin + $titleH}]
        _drawMonthBlock $pdf [lindex $specList $i] $x0 $y0 $blockW $blockH $bopts
    }

    $pdf endPage
    $pdf write -file $filename
    $pdf destroy
    return $filename
}

proc ::tical::render::pdf::createYear {filename specList args} {
    # One page, twelve mini month blocks in a 4x3 grid. specList = 12 month specs.
    ::set given [lmap {k v} $args {string trimleft $k -}]
    ::set opts [_options render::pdf::createYear $args]
    if {"orientation" ni $given} { dict set opts orientation landscape }
    ::set paper [dict get $opts paper]
    ::set orientation [dict get $opts orientation]
    ::set margin [dict get $opts margin]

    ::set objName "ticalpdf[incr ::tical::render::pdf::objCounter]"
    # build the page from explicit oriented point dimensions ({Wp Hp}); this is
    # portrait/landscape-safe across pdf4tcl versions (the "{a4 -landscape}" form
    # is not accepted by newer pdf4tcl)
    ::set dims [_getPageDimensions $paper $orientation]
    ::set pdf [pdf4tcl::new $objName -paper [list [lindex $dims 0]p [lindex $dims 1]p]]
    $pdf startPage

    ::set pageWidth [expr {[lindex $dims 0] - 2 * $margin}]
    ::set pageHeight [expr {[lindex $dims 1] - 2 * $margin}]

    ::set fs [dict get $opts fontsize]
    ::set titleH [expr {$fs * 3}]
    ::set year [dict get [lindex $specList 0] year]
    $pdf setFont [expr {$fs * 1.8}] Helvetica-Bold
    $pdf text "$year" -x [expr {$margin + $pageWidth / 2.0}] \
        -y [expr {$margin + $titleH / 2.0}] -align center

    ::set ncols 4
    ::set nrows 3
    ::set gutter [expr {$fs * 1.2}]
    ::set gridTop [expr {$margin + $titleH}]
    ::set blockW [expr {($pageWidth - ($ncols - 1) * $gutter) / double($ncols)}]
    ::set blockH [expr {($pageHeight - $titleH - ($nrows - 1) * $gutter) / double($nrows)}]
    # mini-month font size (tunable): scales with block height, clamped small
    ::set bfs [expr {min(8.0, max(4.0, $blockH / 24.0))}]
    ::set bopts [dict replace $opts fontsize $bfs]

    for {::set i 0} {$i < [llength $specList]} {incr i} {
        ::set col [expr {$i % $ncols}]
        ::set row [expr {$i / $ncols}]
        ::set x0 [expr {$margin + $col * ($blockW + $gutter)}]
        ::set y0 [expr {$gridTop + $row * ($blockH + $gutter)}]
        _drawMonthBlock $pdf [lindex $specList $i] $x0 $y0 $blockW $blockH $bopts
    }

    $pdf endPage
    $pdf write -file $filename
    $pdf destroy
    return $filename
}

proc ::tical::render::pdf::drawMonth {pdf viewSpec args} {
    ::set opts [_options render::pdf::drawMonth $args]
    _drawMonthGrid $pdf $viewSpec $opts
}

proc ::tical::render::pdf::drawWeek {pdf viewSpec args} {
    ::set opts [_options render::pdf::drawWeek $args]
    _drawWeekGrid $pdf $viewSpec $opts
}

proc ::tical::render::pdf::drawDay {pdf viewSpec args} {
    ::set opts [_options render::pdf::drawDay $args]
    _drawDayGrid $pdf $viewSpec $opts
}

package provide tical::render::pdf 1.1.1

