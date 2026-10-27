# ViewSpec Schema (MVP)

**Erzeuger:** `tical::view::*`  
**Konsument:** `tical::render::*`

## Gemeinsame Felder
- `type` – z. B. `"month-grid"`
- `grid` – `{cols INT rows INT gutter INT padding INT}`

## Month Grid
- `type` = `month-grid`
- `year` *(Integer)*
- `month` *(Integer, 1..12)*
- `cols` = 7
- `rows` = 6
- `cells` *(List von Dicts)*:
  - `date` *(YYYY-MM-DD|{})*
  - `inMonth` *(0|1)*
  - `dow`, `week` *(optional)*
  - `markers` *(List)*
  - `events` *(List)* – Termine (`getData ... -events`): Event-Dict wie
    `tical::event` plus `part` (`single|start|middle|end`) und `time`
    (`HH:MM` am Starttag, sonst leer)
- `weekStart` *(mon|sun)*, `firstWeek` *(iso|simple|us)*
- `legend` *(Dict)* – z. B. `{markers {{today ●} {holiday ▲}}}`

## Week Grid
- `type` = `week-grid`, `year`, `week` (ISO), `cols` = 7, `rows` = 1
- `cells`: `date`, `dow`, `week`, `markers`, `events` (wie Month Grid)

## Day Grid
- `type` = `day-grid`, `date`, `year`, `month`, `day`, `dow`, `week`,
  `hourStart`, `hourEnd`, `hours`, `rows`
- `events` – alle Termine des Tages (auch ganztägige)
- `cells`: `hour`, `time`, `date`, `markers`, `events` (Termine mit Uhrzeit,
  die in dieser Stunde laufen; `part` bezogen auf die Stunden)
