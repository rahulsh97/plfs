# Regenerates man/figures/README-data_coverage-1.png.
#
# This chart shows which PLFS survey years are included in the tidied
# database, using only this package's own exported `available_datasets`
# object. It requires no download and no external data: everything shown
# is already part of the package's source code.
#
# It intentionally does NOT show a state-level substantive indicator (e.g.
# labour-force participation, unemployment, earnings): computing those
# requires the downloaded survey database via plfs_download(), and at the
# time this script was last run, this repository had no published GitHub
# Release for plfs_download() to fetch. See README.Rmd/"Map geometry" and
# "Data coverage" for the current state.

library(ggplot2)

years <- available_datasets

accent <- "#009E73"
pkg_name <- "plfs"
survey_label <- "Periodic Labour Force Survey"

df <- data.frame(year = factor(years, levels = years), included = "Included in the tidied database")

caption_text <- paste0(
  "Source: ", pkg_name, "'s own available_datasets (package code), ", format(Sys.Date(), "%Y"), ". ",
  "State-level substantive indicators require the downloaded survey database, which has no published GitHub Release for this repository at the time of writing."
)
caption_wrapped <- paste(strwrap(caption_text, width = 95), collapse = "\n")

p <- ggplot(df, aes(x = year, y = 1, fill = included)) +
  geom_col(width = 0.72, colour = "grey30", linewidth = 0.3) +
  scale_fill_manual(values = setNames(accent, "Included in the tidied database"), name = NULL) +
  scale_y_continuous(breaks = NULL, limits = c(0, 1.15)) +
  labs(
    title = paste0(pkg_name, ": survey years currently included"),
    subtitle = paste0(survey_label, ", by survey year — data coverage, not a computed indicator"),
    x = "Survey year",
    y = NULL,
    caption = caption_wrapped
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    legend.position = "top",
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(colour = "grey30"),
    plot.caption = element_text(hjust = 0, colour = "grey40", size = 8, lineheight = 1.2),
    plot.caption.position = "plot",
    plot.margin = margin(t = 10, r = 16, b = 10, l = 10)
  )

ggsave("man/figures/README-data_coverage-1.png", p, width = 8, height = 4.4, dpi = 120, bg = "white")
