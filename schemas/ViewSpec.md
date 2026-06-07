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
  - `events` *(List)*
- `legend` *(Dict)* – z. B. `{markers {{today ●} {holiday ▲}}}`
