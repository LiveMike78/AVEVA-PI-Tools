# Asset Framework

XML configuration files that can be imported into AVEVA Asset Framework (AF).

---

## How to Import

1. Open **PI System Explorer**
2. For **Enumeration Sets**: Navigate to **Library** > **Enumeration Sets** > right-click > **Import**
3. For **Shift Patterns / Time Rules**: Navigate to **Library** > **Time Rules** > right-click > **Import**
4. Select the relevant XML file and follow the prompts

---

## Enumerations (`enumerations/`)

### ISO-3166_Country_Names.xml

An AF enumeration set containing country names as defined by the ISO 3166-1 standard. Useful as a drop-down attribute on AF elements that need to record a country (e.g. site location).

---

## Shift Patterns (`shift-patterns/`)

Shift pattern time rule templates. Once imported, these can be referenced by AF analyses or used to align data to operational shift boundaries.

### Shift_Pattern_None-Odd-Even.xml

A shift pattern with three schedule options:

| Value | Description |
|-------|-------------|
| None  | No shift assigned |
| Odd   | Odd shift (e.g. shift 1, 3, 5…) |
| Even  | Even shift (e.g. shift 2, 4, 6…) |

### Shift_Pattern_Daily_Schedule.xml

A daily shift schedule template. Provides a standard 24-hour shift breakdown that can be customised to match site-specific shift times after import.
