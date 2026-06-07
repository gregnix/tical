#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
# optional PNG helper (sibling util/png tree); override via TICAL_DIR/env if needed
lappend auto_path [file normalize [file join $here .. .. util png]]
catch {fconfigure stdout -encoding utf-8}    ;# robust UTF-8 output on Tcl 9

package require tical::core
package require tical::config
package require tical::util
package require tical::holidays
package require tical::holidays::de
package require tical::view::month
package require tical::render::pdf
package require tical::locale
package require pdf4tcl

# write all generated artifacts into demos/out/ (kept out of the lib release)
set outDir [file join [file dirname [file normalize [info script]]] out]
file mkdir $outDir
cd $outDir

# Für PNG-Konvertierung
if {[catch {package require tclMuPDF}]} {
    puts "Fehler: tclMuPDF nicht installiert!"
    puts "Installiere mit: teacup install tclMuPDF"
    exit 1
}

puts "\n=== Jahreskalender 2025 PNG Demo ===\n"

tical::config::set today "2025-10-14"

set year 2025

puts "1. Erstelle PDF (via tical::render::pdf::createYear)..."

# build the 12 month views and let the shared renderer draw the year grid
set specs {}
for {set m 1} {$m <= 12} {incr m} {
    lappend specs [tical::view::month::getData -year $year -month $m -holidays {de}]
}
set pdfFile "calendar-year-2025.pdf"
tical::render::pdf::createYear $pdfFile $specs -orientation landscape -weekNumbers 1

puts "   PDF erstellt: $pdfFile"

# PDF → PNG konvertieren
puts "\n2. Konvertiere PDF → PNG..."

set pdfObj [mupdf::open $pdfFile]
set pageObj [$pdfObj getpage 0]

# Verschiedene Auflösungen (via -zoom)
# zoom 1.0 = 72 DPI, 2.0 = 144 DPI, 4.0 = 288 DPI
set zooms {
    {1.0 "72dpi"}
    {2.0 "144dpi"}
    {4.0 "288dpi"}
}

foreach zoomData $zooms {
    lassign $zoomData zoom label
    set pngFile "calendar-year-2025-${label}.png"
    
    if {[catch {
        $pageObj savePNG $pngFile -zoom $zoom
        puts "   PNG erstellt: $pngFile (zoom ${zoom})"
    } err]} {
        puts "   Fehler bei zoom $zoom: $err"
    }
}

$pdfObj close

puts "\n=== Jahreskalender erstellt! ===\n"
puts "Files:"
puts "  - calendar-year-2025.pdf"
puts "  - calendar-year-2025-72dpi.png (Screen, zoom 1.0)"
puts "  - calendar-year-2025-144dpi.png (Web, zoom 2.0)"
puts "  - calendar-year-2025-288dpi.png (Print, zoom 4.0)"
puts ""

