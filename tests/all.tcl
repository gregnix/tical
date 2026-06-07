#!/usr/bin/env tclsh
# tical - Test Runner (isolated, dependency-tolerant)
#
# Each *.test runs in its own child process, so a missing OPTIONAL package
# (Tk, pdf4tcl, tdbc::sqlite3) only skips that one file instead of aborting
# the whole suite. ASCII-only output (safe on Tcl 9 under any locale).
# Exit code is nonzero only on real test failures/errors.

catch {fconfigure stdout -encoding utf-8}

set thisDir   [file dirname [file normalize [info script]]]
set testFiles [lsort [glob -nocomplain [file join $thisDir *.test]]]

puts "=== tical Test Suite ==="
puts "Location: $thisDir\n"
if {[llength $testFiles] == 0} { puts "ERROR: No test files found!"; exit 1 }
puts "Running [llength $testFiles] test file(s):\n"

set tcl [info nameofexecutable]
set nFiles [llength $testFiles]
set okFiles 0; set skipFiles 0; set failFiles 0
set totPass 0; set totFail 0; set totSkip 0
set skipped {}; set failed {}

foreach testFile $testFiles {
    set name [file tail $testFile]
    catch {exec $tcl $testFile} out   ;# child stdout+stderr land in $out
    set summary ""
    foreach line [split $out \n] {
        if {[regexp {Total\s+\d+\s+Passed\s+\d+\s+Skipped\s+\d+\s+Failed\s+\d+} $line]} {
            set summary $line
        }
    }
    if {$summary ne ""} {
        regexp {Passed\s+(\d+)\s+Skipped\s+(\d+)\s+Failed\s+(\d+)} $summary -> P S F
        incr totPass $P; incr totSkip $S; incr totFail $F
        if {$F > 0} {
            puts [format "  FAIL  %-22s %d passed, %d FAILED" $name $P $F]
            incr failFiles; lappend failed $name
        } else {
            puts [format "  ok    %-22s %d passed%s" $name $P [expr {$S ? ", $S skipped" : ""}]]
            incr okFiles
        }
    } elseif {[regexp {can't find package (\S+)} $out -> pkg]} {
        puts [format "  SKIP  %-22s missing package %s" $name $pkg]
        incr skipFiles; lappend skipped "$name -> $pkg"
    } else {
        puts [format "  FAIL  %-22s ERROR" $name]; incr failFiles; lappend failed $name
        puts [string trim $out]
    }
}

puts "\n=== Test Summary ==="
puts "Files : $nFiles total | $okFiles ok | $skipFiles skipped | $failFiles failed"
puts "Tests : $totPass passed | $totFail failed | $totSkip skipped"
if {[llength $skipped]} { puts "Skipped (missing deps): [join $skipped {; }]" }
if {[llength $failed]}  { puts "Failed files: [join $failed {, }]" }
exit [expr {$failFiles > 0}]
