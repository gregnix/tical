# CalendarData Schema

**Source:** `tical::core::calendarData`  
**Consumer:** `tical::view::*`  
**Type:** Tcl Dict

---

## Purpose

CalendarData is the **raw, unformatted** calendar data structure returned by `tical::core`. It contains dates, metadata, and ISO week numbers but **no layout information**.

---

## Structure

```tcl
dict create \
  tz        STRING      # IANA timezone (e.g., "Europe/Berlin")
  weekStart STRING      # "mon" | "sun"
  firstWeek STRING      # "iso" | "simple" | "us"
  range     LIST        # [startDate endDate] (YYYY-MM-DD format)
  days      LIST        # List of Day records (see below)
```

---

## Day Record

Each element in the `days` list is a dict:

```tcl
dict create \
  date      STRING      # YYYY-MM-DD (ISO 8601)
  dow       INTEGER     # Day of week: 1=Monday, 7=Sunday (ISO 8601)
  week      INTEGER     # ISO week number (1-53)
  isHoliday BOOLEAN     # 0 or 1
  isToday   BOOLEAN     # 0 or 1
  notes     LIST        # List of note strings
  events    LIST        # List of event dicts (future)
```

---

## Field Details

### `tz` (timezone)

- IANA timezone identifier
- Examples: `Europe/Berlin`, `America/New_York`, `UTC`
- Used for: today calculation, event times

### `weekStart` (week start day)

- First day of the week
- Values: `"mon"` (Monday), `"sun"` (Sunday)
- Affects: week calculation, calendar grid

### `firstWeek` (first week of year)

- Week numbering system
- Values:
  - `"iso"` - ISO 8601 (week with first Thursday)
  - `"simple"` - Week containing Jan 1
  - `"us"` - Week containing first Sunday

### `range` (date range)

- Two-element list: `[startDate endDate]`
- Format: `YYYY-MM-DD`
- Example: `[list 2025-10-01 2025-10-31]`

### `days` (day records)

- List of all days in the range
- Ordered chronologically
- Includes all metadata per day

---

## Example

```tcl
set data [tical::core::calendarData -year 2025 -month 10]

# Result:
{
  tz "Europe/Berlin"
  weekStart "mon"
  firstWeek "iso"
  range {2025-10-01 2025-10-31}
  days {
    {date 2025-10-01 dow 3 week 40 isHoliday 0 isToday 0 notes {} events {}}
    {date 2025-10-02 dow 4 week 40 isHoliday 0 isToday 0 notes {} events {}}
    {date 2025-10-03 dow 5 week 40 isHoliday 1 isToday 0 notes {} events {}}
    ...
    {date 2025-10-31 dow 5 week 44 isHoliday 0 isToday 0 notes {} events {}}
  }
}
```

---

## Usage

```tcl
package require tical::core

# Generate calendar data
set data [tical::core::calendarData \
    -year 2025 \
    -month 10 \
    -tz :Europe/Berlin \
    -weekStart mon]

# Access fields
set tz [dict get $data tz]
set days [dict get $data days]

# Iterate days
foreach day $days {
    set date [dict get $day date]
    set week [dict get $day week]
    puts "$date - Week $week"
}
```

---

## Design Principles

1. **Timezone-aware** - All date operations respect `tz`
2. **ISO 8601 compliance** - Dates and weeks follow standard
3. **No formatting** - Pure data, no display logic
4. **Complete metadata** - All info needed for any view
5. **Immutable** - Views transform but don't modify

---

## Related

- See `ViewSpec.md` for the view-specific format
- See `tical::core` API documentation
- See `examples.tcl` for usage examples

---

## Validation

```tcl
# Check if dict is valid CalendarData:
proc isValidCalendarData {data} {
    foreach key {tz weekStart firstWeek range days} {
        if {![dict exists $data $key]} {
            return 0
        }
    }
    
    # Check day records
    foreach day [dict get $data days] {
        foreach key {date dow week isHoliday isToday} {
            if {![dict exists $day $key]} {
                return 0
            }
        }
    }
    
    return 1
}
```

---

**Version:** 1.0  
**Last Updated:** 2025-10-13
