# install.packages(c("ggplot2","dplyr","tidyr","patchwork","scales"))  # if needed
library(ggplot2); library(dplyr); library(tidyr); library(patchwork); library(scales); library(grid)

# --- DATA (same as before; truncated here for brevity) ---
df <- tibble::tribble(
  ~Series, ~Character,                 ~Actor,                   ~CharacterAge, ~ActorAge,
  "TOS","James T. Kirk","William Shatner",32,35,
  "TOS","Spock","Leonard Nimoy",35,35,
  "TOS","Leonard 'Bones' McCoy","DeForest Kelley",38,46,
  "TOS","Montgomery 'Scotty' Scott","James Doohan",43,46,
  "TOS","Nyota Uhura","Nichelle Nichols",26,33,
  "TOS","Hikaru Sulu","George Takei",28,29,
  "TOS","Pavel Chekov","Walter Koenig",22,31,
  "TOS","Christine Chapel","Majel Barrett",35,33,
  "TNG","Jean-Luc Picard","Patrick Stewart",59,47,
  "TNG","William T. Riker","Jonathan Frakes",29,35,
  "TNG","Data","Brent Spiner",26,38,
  "TNG","Geordi La Forge","LeVar Burton",29,30,
  "TNG","Worf","Michael Dorn",24,34,
  "TNG","Deanna Troi","Marina Sirtis",28,32,
  "TNG","Beverly Crusher","Gates McFadden",40,38,
  "TNG","Wesley Crusher","Wil Wheaton",16,15,
  "TNG","Tasha Yar","Denise Crosby",27,29,
  "TNG","Katherine Pulaski","Diana Muldaur",NA_real_,49,
  "DS9","Benjamin Sisko","Avery Brooks",37,44,
  "DS9","Kira Nerys","Nana Visitor",26,35,
  "DS9","Odo","René Auberjonois",NA_real_,52,
  "DS9","Jadzia Dax","Terry Farrell",28,29,
  "DS9","Julian Bashir","Alexander Siddig",28,27,
  "DS9","Miles O'Brien","Colm Meaney",41,39,
  "DS9","Quark","Armin Shimerman",36,43,
  "DS9","Jake Sisko","Cirroc Lofton",14,14,
  "DS9","Worf","Michael Dorn",32,42,
  "DS9","Ezri Dax","Nicole de Boer",27,28,
  "VOY","Kathryn Janeway","Kate Mulgrew",35,39,
  "VOY","Chakotay","Robert Beltran",42,41,
  "VOY","Tuvok","Tim Russ",107,38,
  "VOY","Tom Paris","Robert Duncan McNeill",25,30,
  "VOY","Harry Kim","Garrett Wang",22,26,
  "VOY","B'Elanna Torres","Roxann Dawson",25,36,
  "VOY","The Doctor (EMH)","Robert Picardo",0,41,
  "VOY","Neelix","Ethan Phillips",36,39,
  "VOY","Kes","Jennifer Lien",2,20,
  "VOY","Seven of Nine","Jeri Ryan",26,29
)

# Compute deltas
df <- df %>%
  filter(!is.na(CharacterAge), !is.na(ActorAge)) %>%
  mutate(Delta = ActorAge - CharacterAge,
         AbsDiff = abs(Delta))
  # color_guide <- guide_colorbar(title = "Age Difference between actor (◯) and character (▢)", ticks = TRUE)

# ---------- COLOR SCALING (choose one) ----------
color_mode <- "winsor75"        # "winsor75" (default) or "signedlog"
# color_mode <- "signedlog"        # "winsor75" (default) or "signedlog"

if (color_mode == "winsor75") {
  q <- quantile(abs(df$Delta), 0.75, na.rm = TRUE)
  df <- df %>% mutate(Delta_col = pmin(pmax(Delta, -q), q))
  col_limits <- c(-q, q)
  
  # Legend endpoints + center
  legend_breaks  <- c(col_limits[1], 0, col_limits[2])
  legend_labels  <- c("Older Character", "", "Older Actor")
  
  # Helper to cap linewidth consistently with winsor
  line_map <- function(x) pmin(x, q)
  
  # >>> REPLACE your existing fill scale with this:
  fill_scale <- scale_fill_gradient2(
    low = "#2b8cbe", mid = "#f7f7f7", high = "#d7301f",
    midpoint = 0, limits = col_limits, oob = scales::squish,
    breaks = legend_breaks, labels = legend_labels,
    guide = guide_colorbar(
      title = "Age Difference between actor (◯) and character (▢)",
      title.position = "top",               # title above the bar
      direction = "horizontal",             # horizontal bar
      label.position = "bottom",            # labels under the bar
      barwidth = unit(12, "lines"),
      barheight = unit(0.8, "lines")
    )
  )
  
} else if (color_mode == "signedlog") {
  sgnlog <- function(x) sign(x) * log1p(abs(x))
  inv_sgnlog <- function(y) sign(y) * (exp(abs(y)) - 1)
  
  df <- df %>% mutate(Delta_col = sgnlog(Delta))
  col_limits <- c(-max(abs(df$Delta_col)), max(abs(df$Delta_col)))
  
  # Use symmetric raw Δ end points for labels, then transform to legend breaks
  M <- max(abs(df$Delta), na.rm = TRUE)
  legend_breaks_raw <- c(-M, 0, M)
  legend_breaks_col <- sgnlog(legend_breaks_raw)
  legend_labels     <- c("Older Character", "", "Older Actor")
  
  line_map <- identity
  
  # >>> REPLACE your existing fill scale with this:
  fill_scale <- scale_fill_gradient2(
    low = "#2b8cbe", mid = "#f7f7f7", high = "#d7301f",
    midpoint = 0, limits = col_limits,
    breaks = legend_breaks_col, labels = legend_labels,
    guide = guide_colorbar(
      title = "Age Difference between actor (◯) and character (▢)",
      title.position = "top",
      direction = "horizontal",
      label.position = "bottom",
      barwidth = unit(12, "lines"),
      barheight = unit(0.8, "lines")
    )
  )
}
  
# ---------- PANEL PLOTTER ----------
make_panel <- function(series_code) {
  d <- df %>%
    filter(Series == series_code) %>%
    arrange(desc(AbsDiff)) %>%
  #   mutate(Label = sprintf("%s  (Δ=%+d)", Character, Delta),
  #          Label = factor(Label, levels = Label))
  mutate(Label = sprintf("%s | %s", Character, Actor),
           Label = factor(Label, levels = Label))
  
  char_pts  <- d %>% select(Label, x = CharacterAge, Delta_col, AbsDiff)
  actor_pts <- d %>% select(Label, x = ActorAge,     Delta_col, AbsDiff)
  
  ggplot() +
    geom_segment(
      data = d,
      aes(x = CharacterAge, xend = ActorAge,
          y = Label, yend = Label,
          color = Delta_col, linewidth = line_map(AbsDiff)),
      alpha = 0.4
    ) +
    geom_point(data = char_pts,
               aes(x = x, y = Label, fill = Delta_col),
               shape = 22, size = 3.6, stroke = 0.7) +
    geom_point(data = actor_pts,
               aes(x = x, y = Label, fill = Delta_col),
               shape = 21, size = 5.2, stroke = 0.7) + 
    fill_scale +
    scale_color_gradient2(
      low = "#2b8cbe", mid = "#f7f7f7", high = "#d7301f",
      midpoint = 0, limits = col_limits, oob = scales::squish,
      guide = "none"
    ) +
    scale_linewidth(range = c(1.5, 5), guide = "none") +
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.06))) +
    labs(title = series_code, x = "Age (years)", y = NULL) +
    theme_minimal(base_size = 12) +
    # xlim(c(-1,110)) +
    theme(
      # panel.grid.major.y = element_blank(),
      # panel.grid.minor.y = element_blank(),
      plot.title = element_text(face = "bold", size=18, hjust=0.5),
      plot.title.position = "plot",
      axis.text.y = element_text(face = "bold", size=11),
      legend.position = "bottom"
    )
}

series_order <- c("TOS","TNG","DS9","VOY")
plots <- lapply(series_order, make_panel)

# Combine 2x2 with shared legend (patchwork will keep per-panel legends identical)
multi <- wrap_plots(plots, ncol = 2, guides = "collect") &
  theme(legend.position = "bottom")

# multi
# plotly::ggplotly(multi)
ggsave("~/Downloads/trek_multipanel_delta_winsor.png", multi, width = 15, height = 7, dpi = 300, bg = "white")

# Save if you like:
# ggsave("~/Downloads/trek_multipanel_delta.png", multi, width = 12, height = 9, dpi = 300, bg = "white")
# ggsave("~/Downloads/trek_multipanel_delta.pdf", multi, width = 12, height = 9, device = cairo_pdf)


# plot_one_series(df[,setdiff(colnames(df), "Series")])
plot_one_series(df,"All Series")
