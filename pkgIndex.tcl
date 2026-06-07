# tical Package Index (MVP)

package ifneeded tical::core 1.0 \
    [list source [file join $dir core tical-core-1.0.tm]]

package ifneeded tical::util 1.0 \
    [list source [file join $dir core tical-util-1.0.tm]]

package ifneeded tical::config 1.0 \
    [list source [file join $dir core tical-config-1.0.tm]]

package ifneeded tical::locale 1.0 \
    [list source [file join $dir core tical-locale-1.0.tm]]

package ifneeded tical::term 1.0 \
    [list source [file join $dir core tical-term-1.0.tm]]

package ifneeded tical::view::month 1.0 \
    [list source [file join $dir views tical-view-month-1.0.tm]]

package ifneeded tical::view::week 1.0 \
    [list source [file join $dir views tical-view-week-1.0.tm]]

package ifneeded tical::view::day 1.0 \
    [list source [file join $dir views tical-view-day-1.0.tm]]

package ifneeded tical::render::term 1.0 \
    [list source [file join $dir render tical-render-term-1.0.tm]]

package ifneeded tical::render::canvas 1.0 \
    [list source [file join $dir render tical-render-canvas-1.0.tm]]

package ifneeded tical::render::pdf 1.0 \
    [list source [file join $dir render tical-render-pdf-1.0.tm]]

package ifneeded tical::holidays 1.0 \
    [list source [file join $dir core tical-holidays-1.0.tm]]

package ifneeded tical::holidays::de 1.0 \
    [list source [file join $dir holidays tical-holidays-de-1.0.tm]]

package ifneeded tical::model 1.0 \
    [list source [file join $dir model tical-model-1.0.tm]]

package ifneeded tical::io::ical 1.0 \
    [list source [file join $dir io tical-io-ical-1.0.tm]]

package ifneeded tical::adapter::sqlite 1.0 \
    [list source [file join $dir adapter tical-adapter-sqlite-1.0.tm]]

# umbrella: loads the Tk-free calendar engine (see tical-1.0.tm)
package ifneeded tical 1.0 \
    [list source [file join $dir tical-1.0.tm]]
