# tical - umbrella package
#
# Loads the dependency-free (Tk-free) calendar engine in one require:
#   core data, config, locale, holidays, the event format, model, the
#   day/week/month views, the iCalendar export and the plain-text renderer.
#
# The OPTIONAL layers are deliberately NOT loaded here, because each needs an
# external package; require them directly when that dependency is present:
#   tical::render::canvas   -> Tk
#   tical::render::pdf      -> pdf4tcl
#   tical::adapter::sqlite  -> tdbc::sqlite3
#   tical::io::import       -> tclutils (tuical)

package require Tcl 8.6-

package require tical::util        1.1
package require tical::core        1.1
package require tical::config      1.0
package require tical::locale      1.0
package require tical::term        1.0
package require tical::holidays    1.0
package require tical::holidays::de 1.0
package require tical::event       1.1
package require tical::model       1.1
package require tical::io::ical    1.1
package require tical::view::day   1.1
package require tical::view::week  1.1
package require tical::view::month 1.1
package require tical::render::term 1.1

package provide tical 1.1.1
