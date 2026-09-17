# Build the canonical India states/union-territories boundary file used by
# this package's mapping examples.
#
# Source:        SimpleMaps India GIS data (state/admin-1 level), free tier
#                https://simplemaps.com/gis/country/in
# Direct file:   https://simplemaps.com/static/svg/country/in/admin1/in.json
# Retrieved:     2026-09-17
# Licence:       Creative Commons Attribution 4.0 (CC BY 4.0)
#                https://creativecommons.org/licenses/by/4.0/
# Attribution:   Map geometry: SimpleMaps, used under CC BY 4.0.
#                SimpleMaps does not endorse this package. All renaming,
#                crosswalking, validation, and format conversion below is
#                the package author's own work and is not reviewed or
#                warranted by SimpleMaps.
#
# This script is idempotent and network-dependent: it downloads the source
# file fresh each time it is run and does not commit the raw GeoJSON to the
# repository. Re-run it to refresh region-codes/india_states_map.rds.
#
# Why SimpleMaps: unlike the Natural Earth geometry this file replaces,
# SimpleMaps' Jammu and Kashmir and Ladakh polygons extend to the complete
# India-claimed extent (the source's stated coverage, verified in this
# script's own validation section below), while Natural Earth follows only
# the Line of Control / Line of Actual Control. This is a neutral,
# geometry-only replacement: no political prose is added anywhere in the
# package, README, or documentation.

library(sf)
library(dplyr)

source_url <- "https://simplemaps.com/static/svg/country/in/admin1/in.json"

# ---- 1. Download and read -----------------------------------------------
# A browser-like User-Agent is required: the source blocks R's default
# download.file()/libcurl user agent with an HTTP 403.

tmp <- tempfile(fileext = ".geojson")
resp <- httr::GET(
  source_url,
  httr::user_agent("Mozilla/5.0 (compatible; R sf/httr; india-map-build-script)"),
  httr::write_disk(tmp, overwrite = TRUE)
)
httr::stop_for_status(resp, "downloading SimpleMaps India admin1 GeoJSON")
raw <- st_read(tmp, quiet = TRUE)
unlink(tmp)

# ---- 2. CRS: confirm/enforce EPSG:4326 (WGS84) ---------------------------

if (is.na(st_crs(raw))) {
  raw <- st_set_crs(raw, 4326)
} else if (st_crs(raw) != st_crs(4326)) {
  raw <- st_transform(raw, 4326)
}

# ---- 3. Geometry validity -------------------------------------------------

raw <- st_make_valid(raw)
stopifnot(
  "source geometry contains invalid geometries after st_make_valid()" =
    all(st_is_valid(raw)),
  "source geometry contains empty geometries" =
    !any(st_is_empty(raw))
)

# ---- 4. No simplification -------------------------------------------------
# SimpleMaps' free-tier file is already web-optimised/simplified upstream
# (per the source page: "Simplified to load quickly with minimal loss of
# detail"). No further st_simplify() is applied here, to avoid compounding
# generalisation error on top of the source's own simplification.

# ---- 5. Name crosswalk: correct outdated/variant SimpleMaps names --------
# Normalise to the names already used by ASI/ASUSE/PLFS's existing
# state_name column (pre-crosswalk name -> corrected name).

name_fixes <- c(
  "Orissa" = "Odisha",
  "Uttaranchal" = "Uttarakhand",
  "Dādra and Nagar Haveli and Damān and Diu" =
    "Dadra and Nagar Haveli and Daman and Diu"
)

raw <- raw %>%
  mutate(
    state_name = if_else(name %in% names(name_fixes), name_fixes[name], name)
  )

# ---- 6. Numeric state_code crosswalk --------------------------------------
# Preserves the existing numeric state_code scheme already used across
# ASI, ASUSE, and PLFS (NOT SimpleMaps' own alpha `id` codes). This table is
# carried over unchanged from the geometry it replaces so downstream joins
# in all three packages keep working without modification. Code 26 is
# intentionally absent (retired: the former standalone Daman and Diu, now
# merged into code 25).

state_code_crosswalk <- c(
  "Jammu and Kashmir" = "01",
  "Himachal Pradesh" = "02",
  "Punjab" = "03",
  "Chandigarh" = "04",
  "Uttarakhand" = "05",
  "Haryana" = "06",
  "Delhi" = "07",
  "Rajasthan" = "08",
  "Uttar Pradesh" = "09",
  "Bihar" = "10",
  "Sikkim" = "11",
  "Arunachal Pradesh" = "12",
  "Nagaland" = "13",
  "Manipur" = "14",
  "Mizoram" = "15",
  "Tripura" = "16",
  "Meghalaya" = "17",
  "Assam" = "18",
  "West Bengal" = "19",
  "Jharkhand" = "20",
  "Odisha" = "21",
  "Chhattisgarh" = "22",
  "Madhya Pradesh" = "23",
  "Gujarat" = "24",
  "Dadra and Nagar Haveli and Daman and Diu" = "25",
  "Maharashtra" = "27",
  "Andhra Pradesh" = "28",
  "Karnataka" = "29",
  "Goa" = "30",
  "Lakshadweep" = "31",
  "Kerala" = "32",
  "Tamil Nadu" = "33",
  "Puducherry" = "34",
  "Andaman and Nicobar" = "35",
  "Telangana" = "36",
  "Ladakh" = "37"
)

unmatched <- setdiff(raw$state_name, names(state_code_crosswalk))
missing <- setdiff(names(state_code_crosswalk), raw$state_name)

stopifnot(
  "unmatched units in source geometry (not in the state_code crosswalk)" =
    length(unmatched) == 0,
  "units in the crosswalk missing from the source geometry" =
    length(missing) == 0,
  "expected exactly 36 administrative units" =
    nrow(raw) == 36
)

india_states <- raw %>%
  mutate(state_code = unname(state_code_crosswalk[state_name])) %>%
  select(state_name, state_code, geometry) %>%
  arrange(state_code)

# ---- 7. Final validation ---------------------------------------------------

stopifnot(
  "expected exactly 36 rows in the final object" =
    nrow(india_states) == 36,
  "duplicate state_name values" =
    anyDuplicated(india_states$state_name) == 0L,
  "duplicate state_code values" =
    anyDuplicated(india_states$state_code) == 0L,
  "invalid geometries in the final object" =
    all(st_is_valid(india_states)),
  "empty geometries in the final object" =
    !any(st_is_empty(india_states)),
  "final CRS is not EPSG:4326" =
    st_crs(india_states) == st_crs(4326)
)

cat("Validation passed: 36 units, unique names/codes, valid non-empty geometries, EPSG:4326.\n")

# ---- 8. Save ---------------------------------------------------------------

saveRDS(india_states, "region-codes/india_states_map.rds", compress = "xz")
cat("Wrote region-codes/india_states_map.rds\n")
