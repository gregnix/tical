# tical - umbrella package
#
# Loads the dependency-free (Tk-free) calendar engine in one require:
#   core data, config, locale, holidays, model, the day/week/month views,
#   the iCalendar IO and the plain-text renderer.
#
# The OPTIONAL layers are deliberately NOT loaded here, because each needs an
# external package; require them directly when that dependency is present:
#   tical::render::canvas   -> Tk
#   tical::render::pdf      -> pdf4tcl
#   tical::adapter::sqlite  -> tdbc::sqlite3

package require Tcl 8.6-

package require tical::util        1.0
package require tical::core        1.0
package require tical::config      1.0
package require tical::locale      1.0
package require tical::term        1.0
package require tical::holidays    1.0
package require tical::holidays::de 1.0
package require tical::model       1.0
package require tical::io::ical    1.0
package require tical::view::day   1.0
package require tical::view::week  1.0
package require tical::view::month 1.0
package require tical::render::term 1.0

package provide tical 1.0
