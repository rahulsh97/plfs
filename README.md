
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R-CMD-check](https://github.com/rahulsh97/plfs/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pachadotdev/rahulsh97/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

# Periodic Labour Force Survey (PLFS)

The goal of plfs is to provide a long dataset of the Periodic Labour
Force Survey (PLFS) from India.

## Example

Install the package from GitHub and load it:

``` r
# install.packages("devtools")
devtools::install_github("rahulsh97/plfs")
```

``` r
library(plfs)
```

Because of the datasets size, the package provides a function to
download the datasets and create a local DuckDB database. This results
in a CRAN-compliant package.

Here is how to get the plfs database ready for use:

``` r
plfs_download()
```

Check the proportion of observations by Social Group (b3q4_hhv1) in the
survey (See
<https://microdata.gov.in/NADA/index.php/catalog/213/data-dictionary/F5>):

``` r
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(duckdb)
#> Loading required package: DBI

con <- dbConnect(duckdb(), plfs_file_path())

dbListTables(con)
#>  [1] "2021-22-hhrv"  "2021-22-hhv1"  "2021-22-perrv" "2021-22-perv1"
#>  [5] "2022-23-hhrv"  "2022-23-hhv1"  "2022-23-perrv" "2022-23-perv1"
#>  [9] "2023-24-hhrv"  "2023-24-hhv1"  "2023-24-perrv" "2023-24-perv1"

tbl(con, "2021-22-hhrv") %>%
  count()
#> # Source:   SQL [?? x 1]
#> # Database: DuckDB 1.4.0 [pacha@Linux 6.12.48-1-MANJARO:R 4.5.1//home/pacha/.local/share/R/plfs/plfs_duckdb_v140.sql]
#>        n
#>    <dbl>
#> 1 132376

tbl(con, "2021-22-hhrv") %>%
  count(b3q4_hhrv) %>%
  mutate(
    b3q4_hhrv = case_when(
      b3q4_hhrv == 1L ~ "scheduled tribe",
      b3q4_hhrv == 2L ~ "scheduled caste",
      b3q4_hhrv == 3L ~ "other backward class",
      b3q4_hhrv == 9L ~ "other",
      TRUE ~ NA_character_
    ),
    pct = n / sum(n)
  ) %>%
  collect()
#> Warning: Missing values are always removed in SQL aggregation functions.
#> Use `na.rm = TRUE` to silence this warning
#> This warning is displayed once every 8 hours.
#> # A tibble: 4 × 3
#>   b3q4_hhrv                n    pct
#>   <chr>                <dbl>  <dbl>
#> 1 scheduled tribe      10927 0.0825
#> 2 scheduled caste      17566 0.133 
#> 3 other backward class 54162 0.409 
#> 4 other                49721 0.376

# what happened from 2021 to 2022

d <- tbl(con, "2021-22-hhrv") %>%
  count(b3q4_hhrv) %>%
  mutate(
    b3q4_hhrv = case_when(
      b3q4_hhrv == 1L ~ "scheduled tribe",
      b3q4_hhrv == 2L ~ "scheduled caste",
      b3q4_hhrv == 3L ~ "other backward class",
      b3q4_hhrv == 9L ~ "other",
      TRUE ~ NA_character_
    ),
    pct = n / sum(n)
  ) %>%
  left_join(
    tbl(con, "2022-23-hhrv") %>%
      count(b3q4_hhrv) %>%
      mutate(
        b3q4_hhrv = case_when(
          b3q4_hhrv == 1L ~ "scheduled tribe",
          b3q4_hhrv == 2L ~ "scheduled caste",
          b3q4_hhrv == 3L ~ "other backward class",
          b3q4_hhrv == 9L ~ "other",
          TRUE ~ NA_character_
        ),
        pct = n / sum(n)
      ),
      by = "b3q4_hhrv"
  ) %>%
  collect()

dbDisconnect(con, shutdown = TRUE)
```

Create a map showing the average household expenditure by state:

**This example was particularly challenging to implement because of the
lack of documentation, fragmented data files, and inconsistent state
naming conventions. The details on how to create the datasets for this
example are in the script `region-codes/organize-codes.R`.**

``` r
library(dplyr)
library(duckdb)
library(sf)
#> Linking to GEOS 3.13.1, GDAL 3.11.3, PROJ 9.6.0; sf_use_s2() is TRUE
library(ggplot2)

con <- dbConnect(duckdb(), plfs_file_path())

dbListTables(con)
#>  [1] "2021-22-hhrv"  "2021-22-hhv1"  "2021-22-perrv" "2021-22-perv1"
#>  [5] "2022-23-hhrv"  "2022-23-hhv1"  "2022-23-perrv" "2022-23-perv1"
#>  [9] "2023-24-hhrv"  "2023-24-hhv1"  "2023-24-perrv" "2023-24-perv1"

# average household expenditure by state

mean_expenditure <- tbl(con, "2023-24-hhv1") %>%
  group_by(state_code = state_hhv1) %>%
  summarise(
    avg_expenditure = mean(b3q5pt1_hhv1, na.rm = TRUE)
  ) %>%
  collect()

dbDisconnect(con, shutdown = TRUE)

# merge data with map of India states

india_states <- readRDS("region-codes/india_states_map.rds")

mean_expenditure <- mean_expenditure %>%
  left_join(india_states)
#> Joining with `by = join_by(state_code)`

ggplot(mean_expenditure) +
  geom_sf(aes(fill = avg_expenditure, geometry = geometry), colour = "grey30", size = 0.2) +
  scale_fill_viridis_c(option = "D", begin = 0.5, end = 0.8, na.value = "grey95", name = "Avg expenditure") +
  labs(title = "Mean household expenditure by state (PLFS)") +
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    legend.position = "top"
  )
```

<img src="man/figures/README-avg_expenditure-1.png" width="100%" />

# Adding older/newer years

Be sure to use the yearly survey (e.g., Jul 23 - Jun 24,
<https://microdata.gov.in/NADA/index.php/catalog/PLFS/?page=1&sort_order=desc&ps=15&repo=PLFS>)

1.  Install the Nesstar Explorer (e.g. plfs 2023-24 includes it)
2.  Extract the RAR/ZIP files downloaded from the microdata website to
    data-raw/202324 or what year you are adding
3.  Export the .Nesstar file to Stata (SAV) format with “Export
    Datasets” and the metadata with “Export DDI” using the Nesstar
    Explorer
4.  Update `00-tidy-data.r` and run it
5.  Update the available datasets in `R/available_datasets.R`
6.  Update the new RDS files in the ‘Releases’ section of the GitHub
    repository
7.  Regenerate the database with `plfs_delete()` and `plfs_download()`
