# India boundary geometry: source and licence

`india_states_map.rds` in this directory is the India states/union-territories
boundary layer used by this package's mapping examples.

## Source

- **Provider:** SimpleMaps ([simplemaps.com/gis/country/in](https://simplemaps.com/gis/country/in))
- **File:** state/admin-1 level GeoJSON, free tier
  (`https://simplemaps.com/static/svg/country/in/admin1/in.json`)
- **Retrieved:** 2026-09-17
- **Licence:** Creative Commons Attribution 4.0 (CC BY 4.0) —
  <https://creativecommons.org/licenses/by/4.0/>

## Attribution

> Map geometry: SimpleMaps, used under CC BY 4.0; package-specific data and
> visualisation by Rahul Shukla.

SimpleMaps does not endorse this package. All renaming, crosswalking,
validation, and format conversion described below is the package author's
own work and is not reviewed or warranted by SimpleMaps.

## What was done to the source file

The build script, `region-codes/build_india_map.R`, is the single source of
truth for these steps and can be re-run at any time to regenerate
`india_states_map.rds`:

1. **Download.** Fetches the GeoJSON directly from the URL above.
2. **CRS.** Confirmed/set to EPSG:4326 (WGS84).
3. **Geometry validity.** `sf::st_make_valid()` applied; the result is
   checked to confirm every geometry is valid and non-empty.
4. **Simplification.** None applied by this package. SimpleMaps' free-tier
   file is already simplified upstream ("web-optimized... minimal loss of
   detail" per the source page); no further generalisation is layered on
   top of it here.
5. **Name crosswalk.** Two outdated names in the source are corrected to
   the names already used across ASI/ASUSE/PLFS:
   - `Orissa` → `Odisha`
   - `Uttaranchal` → `Uttarakhand`
   - The diacritic variant `Dādra and Nagar Haveli and Damān and Diu` is
     normalised to `Dadra and Nagar Haveli and Daman and Diu`.
6. **State-code crosswalk.** The existing numeric `state_code` scheme
   already used by ASI, ASUSE, and PLFS (`"01"`–`"37"`, with `"26"`
   intentionally retired) is preserved exactly. SimpleMaps' own alpha `id`
   codes (e.g. `INJK`, `INLA`) are **not** used or carried over.
7. **Validation.** The script asserts, and will error out if any of the
   following do not hold: exactly 36 administrative units; every source
   unit matched to a crosswalk entry with none left over in either
   direction; no duplicate `state_name` or `state_code`; no invalid or
   empty geometries; final CRS is EPSG:4326.

## Result

A single `sf` object with columns `state_name`, `state_code`, `geometry`,
36 rows, EPSG:4326, all geometries valid and non-empty — the same interface
the package's code has always used.

## Licence note

This CC BY 4.0 attribution applies specifically to the map geometry
component described above. It does not change the package's own overall
licence (see `LICENSE.md`), which continues to apply to the code and to the
package's own tidied survey data.
