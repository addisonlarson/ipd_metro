library(here); library(tidyverse)
library(sf); library(tigris)
options(tigris_class = "sf")

# By census tract
flat_ipd <- read_csv(here("outputs", "ipd.csv"))
phila_tracts <- tracts(state = 42, county = 101)

phila_tracts_2 <- left_join(phila_tracts, flat_ipd,
                            by = c("GEOID" = "GEOID10")) %>%
  mutate(Score = as.factor(cut(IPD_Score,
                               breaks = seq(0, 36, by = 6),
                               include.lowest = TRUE)))
ggplot() +
  theme(panel.background = element_blank()) +
  geom_sf(data = phila_tracts_2, aes(fill = Score), color = NA) +
  scale_fill_viridis_d("Residual", na.value = "gainsboro") +
  ggtitle("Tract-Level IPD Scores in the City of Philadelphia") +
  coord_sf(datum = NA)
ggsave(here("figures", "phila_tract.png"), width = 7, height = 7,
       units = "in", dpi = "screen")

# By county in each MSA
shp_ipd <- st_read(here("outputs", "ipd.shp"))

nyc <- filter(shp_ipd, msaname == "NEW YORK-NEWARK, NY-NJ-PA") %>%
  mutate(Score = as.factor(cut(Mean_IPD,
                               breaks = seq(0, 36, by = 6),
                               include.lowest = TRUE)))
ggplot() +
  theme(panel.background = element_blank()) +
  geom_sf(data = nyc, aes(fill = Score), color = NA) +
  scale_fill_viridis_d("Residual", na.value = "gainsboro") +
  ggtitle("County-Level IPD Scores in the New York-Newark MSA") +
  coord_sf(datum = NA)
ggsave(here("figures", "nyc_county.png"), width = 7, height = 7,
       units = "in", dpi = "screen")
