package provide tical::term 1.0
package require Tcl 8.6-

namespace eval tical::term {
    namespace export enableVT disableVT ansi
}

# Stub-Funktionen: Unter Windows könnte enableVT echte ConsoleModes setzen (twapi),
# hier ein einfacher Platzhalter.
proc tical::term::enableVT {} { return 1 }
proc tical::term::disableVT {} { return 1 }

proc tical::term::ansi {seq text} {
    return "\033\[${seq}m${text}\033\[0m"
}
