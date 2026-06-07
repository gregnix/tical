#!/usr/bin/env tclsh

# --- locate the tical engine (pkgIndex.tcl at the repo root) -----------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    lappend auto_path [file dirname $here]
}
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

if {[catch {package require tclMuPDF}]} {
    puts "Fehler: tclMuPDF nicht installiert!"
    puts "Installiere mit: teacup install tclMuPDF"
    exit 1
}

puts "\n=== Quartalskalender 2025 PNG Demo ===\n"

tical::config::set today "2025-10-14"

set year 2025

set quarters {
    {1 "Q1" {1 2 3}}
    {2 "Q2" {4 5 6}}
    {3 "Q3" {7 8 9}}
    {4 "Q4" {10 11 12}}
}


foreach quarter $quarters {
    lassign $quarter qNum qName months
    
    puts "Erstelle Quartal $qNum ($qName)..."
    
    # PDF erstellen (mit KW!)
    set pdfFile "calendar-2025-Q${qNum}.pdf"
    
    # build the 3 month views and let the shared renderer draw the quarter
    set specs {}
    foreach m $months {
        lappend specs [tical::view::month::getData -year $year -month $m -holidays {de}]
    }
    tical::render::pdf::createQuarter $pdfFile $specs -weekNumbers 1
    
    puts "   PDF: $pdfFile"
    
    # PDF → PNG (zoom 2.0 = 144 DPI für gute Qualität)
    set pdfObj [mupdf::open $pdfFile]
    set pageObj [$pdfObj getpage 0]
    
    set pngFile "calendar-2025-Q${qNum}.png"
    $pageObj savePNG $pngFile -zoom 2.0
    $pdfObj close
    
    puts "   PNG: $pngFile"
}

puts "\n=== Alle Quartalskalender erstellt! ===\n"
puts "Files:"
puts "  - calendar-2025-Q1.pdf + .png (Jan-Mär)"
puts "  - calendar-2025-Q2.pdf + .png (Apr-Jun)"
puts "  - calendar-2025-Q3.pdf + .png (Jul-Sep)"
puts "  - calendar-2025-Q4.pdf + .png (Okt-Dez)"
puts ""

