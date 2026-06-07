# tical::render::pdf - PDF Calendar Renderer

package require Tcl 8.6-
package require pdf4tcl
package require tical::locale

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
        colorWeekend "#E6F3FF"]
}

proc ::tical::render::pdf::create {filename viewSpec args} {
    variable defaultOptions
    # accept both -key and key style options
    ::set norm {}
    foreach {k v} $args { lappend norm [string trimleft $k -] $v }
    ::set opts [dict merge $defaultOptions $norm]
    
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
            error "Unknown ViewSpec type: $type"
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

    # optional event highlighting (list of YYYY-MM-DD dates); empty by default
    ::set events {}
    if {[dict exists $opts events]} { ::set events [dict get $opts events] }
    ::set colorEvent "#E8F5E9"
    if {[dict exists $opts colorEvent]} { ::set colorEvent [dict get $opts colorEvent] }

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
    $pdf setFont [expr {$fontsize * 1.8}] Helvetica-Bold
    $pdf text "$monthName $year" -x [expr {$x0 + $blockW / 2.0}] \
        -y [expr {$y0 + $headerHeight / 2.0}] -align center

    ::set weekdayNames [::tical::locale::getWeekdayNames short]
    $pdf setFont $fontsize Helvetica-Bold

    ::set colStart 0
    if {$weekNumbers} {
        $pdf text "KW" -x [expr {$x0 + $cellW / 2.0}] \
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
            ::set hasEvent [expr {$date in $events}]

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

            if {$weekNumbers && $col == 0 && $week ne ""} {
                $pdf setFillColor #000000
                $pdf setFont [expr {$fontsize * 0.8}] Helvetica
                ::set weekX [expr {$x0 + $cellW / 2.0}]
                ::set weekY [expr {$cellY + $cellH / 2.0}]
                $pdf text $week -x $weekX -y $weekY -align center
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
            $pdf text [scan $day %d] -x $textX -y $textY -align left

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
    $pdf text "Week $week, $year" -x [expr {$margin + $pageWidth / 2.0}] \
        -y [expr {$margin + $fontsize * 2}] -align center
    
    ::set cellH [expr {($pageHeight - $fontsize * 4) / 7.0}]
    ::set weekdayNames [::tical::locale::getWeekdaysLong]
    
    $pdf setFont $fontsize Helvetica
    
    ::set idx 0
    foreach cellData $cells {
        ::set date [dict get $cellData date]
        ::set day [lindex [split $date "-"] 2]
        ::set weekdayName [lindex $weekdayNames $idx]
        
        ::set y [expr {$margin + $fontsize * 4 + $idx * $cellH}]
        
        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.5
        $pdf line $margin $y [expr {$margin + $pageWidth}] $y
        
        $pdf setFillColor #000000
        $pdf text "$weekdayName, $date" -x [expr {$margin + 10}] \
            -y [expr {$y + $cellH / 2.0}] -align left
        
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
    
    ::set cellH [expr {($pageHeight - $fontsize * 4) / double([llength $cells])}]
    
    $pdf setFont $fontsize Helvetica
    
    ::set idx 0
    foreach cellData $cells {
        ::set hour [dict get $cellData hour]
        ::set time [format "%02d:00" $hour]
        
        ::set y [expr {$margin + $fontsize * 4 + $idx * $cellH}]
        
        $pdf setStrokeColor 0.7 0.7 0.7
        $pdf setLineWidth 0.5
        $pdf line $margin $y [expr {$margin + $pageWidth}] $y
        
        $pdf setFillColor #000000
        $pdf text $time -x [expr {$margin + 10}] \
            -y [expr {$y + $cellH / 2.0}] -align left
        
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
    variable defaultOptions
    # accept both -key and key style options
    ::set norm {}
    foreach {k v} $args { lappend norm [string trimleft $k -] $v }
    ::set opts [dict merge $defaultOptions $norm]
    if {![dict exists $norm orientation]} { dict set opts orientation landscape }
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
    variable defaultOptions
    # accept both -key and key style options
    ::set norm {}
    foreach {k v} $args { lappend norm [string trimleft $k -] $v }
    ::set opts [dict merge $defaultOptions $norm]
    if {![dict exists $norm orientation]} { dict set opts orientation landscape }
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
    variable defaultOptions
    ::set opts [dict merge $defaultOptions $args]
    _drawMonthGrid $pdf $viewSpec $opts
}

proc ::tical::render::pdf::drawWeek {pdf viewSpec args} {
    variable defaultOptions
    ::set opts [dict merge $defaultOptions $args]
    _drawWeekGrid $pdf $viewSpec $opts
}

proc ::tical::render::pdf::drawDay {pdf viewSpec args} {
    variable defaultOptions
    ::set opts [dict merge $defaultOptions $args]
    _drawDayGrid $pdf $viewSpec $opts
}

package provide tical::render::pdf 1.0

