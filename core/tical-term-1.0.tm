package provide tical::term 1.0
package require Tcl 8.6-

namespace eval tical::term {
    namespace export enableVT disableVT ansi
}

# Deprecated, removed in 1.2: placeholders (enableVT and disableVT do
# nothing, ansi wraps text in an escape sequence); nothing in tical uses them.
# The umbrella still loads the package in 1.1.x.
proc tical::term::enableVT {} { return 1 }
proc tical::term::disableVT {} { return 1 }

proc tical::term::ansi {seq text} {
    return "\033\[${seq}m${text}\033\[0m"
}
