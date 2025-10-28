if (!require("shiny")) install.packages("shiny", repos = "https://cran.r-project.org")
if (!require("d3po")) install.packages("d3po", repos = "https://pachadotdev.r-universe.dev")
if (!require("tabler")) install.packages("tabler", repos = "https://pachadotdev.r-universe.dev")
if (!require("dplyr")) install.packages("dplyr", repos = "https://cran.r-project.org")
if (!require("duckdb")) install.packages("duckdb", repos = "https://cran.r-project.org")
if (!require("sf")) install.packages("sf", repos = "https://cran.r-project.org")

library(shiny)
library(d3po)
library(tabler)
library(dplyr)
library(duckdb)
library(sf)
library(plfs)

# Simplified menu for the top navbar (just labels, no icons for simplicity)
top_nav <- navbar_menu(
  menu_item("Mean consumption", icon = "currency-dollar")
)

# Combine both for combo layout
main_navbar <- list(top = top_nav)

ui <- page(
  theme = "light",
  color = "orange",
  title = "PLFS Examples",
  layout = "boxed",
  show_theme_button = FALSE,
  navbar = main_navbar,
  body = list(
    # Page header
    page_header(
      title_text = "PLFS Examples",
      pretitle_text = "Using D3po + Tabler"
    ),
    # Page body content
    shiny::tags$div(
      class = "page-body",
      shiny::tags$div(
        class = "container-xl",
        column(
          12,
          card(
            title = "Average Household Expenditure by State in India (2023-24)",
            # footer = "Footer.",
            d3po_output("plot", width = "100%", height = "650px")
          )
        )
      )
    )
  ),
  footer = footer(
    left = "Based on the Periodic Labour Force Survey"
    # right = shiny::tags$span("v1.4.0")
  )
)

server <- function(input, output, session) {
  output$plot <- render_d3po({
    con <- dbConnect(duckdb(), plfs_file_path())

    dbListTables(con)

    # average household expenditure by state

    mean_expenditure <- tbl(con, "2023-24-hhv1") %>%
        group_by(state_code = state_hhv1) %>%
        summarise(avg_expenditure = mean(b3q5pt1_hhv1, na.rm = TRUE)) %>%
        collect()

    dbDisconnect(con, shutdown = TRUE)

    # merge data with map of India states

    india_states <- readRDS("region-codes/india_states_map.rds")

    mean_expenditure <- mean_expenditure %>%
        left_join(
            india_states %>%
                as.data.frame() %>%
                select(-geometry)
        )

    map_india <- d3po::maps$asia$india
    labels_india <- map_ids(d3po::maps$asia$india)

    mean_expenditure <- mean_expenditure %>%
        # state_name -> name
        # Uttarakhand -> Uttaranchal
        # Dadra and Nagar Haveli and Daman and Diu -> Daman and Diu
        # Odisha -> Orissa
        # Telangana -> Andhra Pradesh ?
        # Ladakh ->
        # Andaman and Nicobar -> ?
        mutate(
            state_name = case_when(
                state_name == "Uttarakhand" ~ "Uttaranchal",
                state_name == "Dadra and Nagar Haveli and Daman and Diu" ~ "Daman and Diu",
                state_name == "Odisha" ~ "Orissa",
                state_name == "Telangana" ~ "Andhra Pradesh",
                state_name == "Ladakh" ~ "Jammu and Kashmir",
                TRUE ~ state_name
            )
        ) %>%
        left_join(labels_india, by = c("state_name" = "name"))

    # add a color column with a gradient based on avg_expenditure
    mean_expenditure <- mean_expenditure %>%
        mutate(
            color = ifelse(
                is.na(avg_expenditure),
                "#e0e0e0",
                scales::col_numeric(
                    palette = "YlOrRd",
                    domain = range(mean_expenditure$avg_expenditure, na.rm = TRUE)
                )(avg_expenditure)
            )
        )

    # mean_expenditure %>%
    #     filter(is.na(id))

    # sort(labels_india$name)

    # for light theme
    axis_color <- "#000"
    tooltip_color <- "#fff"

    d3po(mean_expenditure) %>%
      po_geomap(daes(group = id, color = color, size = avg_expenditure, tooltip = state_name), map = map_india) %>%
      # po_labels(title = "Average Household Expenditure by State in India (2023-24)") %>%
      po_background("transparent") %>%
      po_theme(axis = axis_color, tooltips = tooltip_color)
  })
}

shinyApp(ui, server)
