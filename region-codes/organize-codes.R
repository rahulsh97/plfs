library(dplyr)
library(duckdb)
library(readxl)
library(sf)
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

# The boundary layer itself is built and validated by
# region-codes/build_india_map.R (source: SimpleMaps, CC BY 4.0; see
# region-codes/MAP_SOURCE.md). Re-run that script to refresh
# region-codes/india_states_map.rds; this script only consumes it.
india_states <- readRDS("region-codes/india_states_map.rds")

mean_expenditure_map <- mean_expenditure %>%
  select(state_code, avg_expenditure) %>%
  left_join(india_states, by = "state_code")

unmatched <- mean_expenditure_map %>%
  filter(is.na(state_name))

if (nrow(unmatched) > 0) {
  message("Unmatched state_code values (no boundary found). Fix the state_code crosswalk before continuing:")
  print(unmatched)
}

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
