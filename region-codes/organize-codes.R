library(dplyr)
library(duckdb)
library(readxl)
library(rnaturalearth)
library(sf)
library(stringr)
library(ggplot2)

load_all()

con <- dbConnect(duckdb(), plfs_file_path())

dbListTables(con)

# average household expenditure by state

state_codes <- read_excel("region-codes/District_codes_PLFS_Panel_4_202324_2024.xlsx", range = "A4:D698")

state_codes <- state_codes %>%
  select(state_name = `State Name`, state_code = `State Code`) %>%
  distinct()

sort(state_codes$state_name)

mean_expenditure <- tbl(con, "2023-24-hhv1") %>%
  group_by(state_code = state_hhv1) %>%
  summarise(
    avg_expenditure = mean(b3q5pt1_hhv1, na.rm = TRUE)
  ) %>%
  collect()

dbDisconnect(con, shutdown = TRUE)

mean_expenditure <- mean_expenditure %>%
  left_join(state_codes, by = "state_code")

india_states <- rnaturalearth::ne_states(country = "India", returnclass = "sf") %>%
  select(geom_name = name, geometry) %>%
  st_as_sf()

# simplify map geometry
india_states <- st_simplify(india_states, dTolerance = 0.1)

# normalize names
norm <- function(x) {
  x %>%
    toupper() %>%
    str_replace_all("&", "AND") %>%
    str_replace_all("&", "AND") %>%
    str_replace_all("[^A-Z0-9]", "") %>%
    str_squish()
}

india_states <- india_states %>%
  mutate(name_norm = norm(geom_name))

mean_expenditure <- mean_expenditure %>%
  mutate(state_name_norm = norm(state_name))

match_idx <- stringdist::amatch(mean_expenditure$state_name_norm,
  india_states$name_norm, method = "jw", maxDist = 0.18)

unmatched <- which(is.na(match_idx))

if (length(unmatched) > 0) {
  message("Unmatched rows in mean_expenditure (no fuzzy match found). Print them to fix manually:")
  print(mean_expenditure[unmatched, "state_name_norm"])
}

sort(india_states$geom_name)
sort(india_states$name_norm)

# AANDNISLANDS -> A & N ISLANDS -> "Andaman and Nicobar"
# DAMANANDDIUANDDANDNHAVELI -> DADRAANDNAGARHAVELIANDDAMANANDDIU
mean_expenditure <- mean_expenditure %>%
  mutate(
    state_name_norm = case_when(
      state_name_norm == "AANDNISLANDS" ~ "ANDAMANANDNICOBAR",
      state_name_norm == "DAMANANDDIUANDDANDNHAVELI" ~
        "DADRAANDNAGARHAVELIANDDAMANANDDIU",
      TRUE ~ state_name_norm
    )
  ) %>%
  left_join(
    india_states,
    by = c("state_name_norm" = "name_norm")
  )

mean_expenditure %>%
  filter(is.na(geom_name))

india_states <- india_states %>%
  inner_join(
    mean_expenditure %>%
      as.data.frame() %>%
      select(state_code, geom_name)
  ) %>%
  select(-name_norm) %>%
  rename(state_name = geom_name)

saveRDS(india_states, "region-codes/india_states_map.rds", compress = "xz")

mean_expenditure <- mean_expenditure %>%
    as.data.frame() %>%
    select(state_name = geom_name, state_code, avg_expenditure) %>%
    as_tibble()

mean_expenditure_map <- mean_expenditure %>%
  left_join(india_states)

ggplot(mean_expenditure_map) +
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
