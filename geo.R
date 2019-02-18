library(tidyverse); library(here)
url <- "https://www.nber.org/cbsa-msa-fips-ssa-county-crosswalk/cbsatocountycrosswalk.csv"
temp <- tempfile()
download.file(url, temp)
xwalk <- read_csv(temp) %>%
  select(fipscounty, state, msa, msaname, y2017) %>%
  drop_na(y2017) %>%
  filter(!(state %in% c("AK", "HI", "PR"))) %>%
  filter(nchar(msa) != 2) %>%
  write_csv(here("outputs", "geo.csv"))
