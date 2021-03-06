library(plyr); library(here); library(sf); library(summarytools);
library(tidycensus); library(tidyverse); library(tigris)
disabled_universe                    <- "S1810_C01_001"
disabled_count                       <- "S1810_C02_001"
disabled_percent                     <- "S1810_C03_001"
ethnic_minority_universe             <- "B03002_001"
ethnic_minority_count                <- "B03002_012"
ethnic_minority_percent              <- NA
female_universe                      <- "S0101_C01_001"
female_count                         <- "S0101_C05_001"
female_percent                       <- "DP05_0003PE"
foreign_born_universe                <- "B05012_001"
foreign_born_count                   <- "B05012_003"
foreign_born_percent                 <- NA
limited_english_proficiency_universe <- "S1601_C01_001"
limited_english_proficiency_count    <- "S1601_C05_001"
limited_english_proficiency_percent  <- "S1601_C06_001"
low_income_universe                  <- "S1701_C01_001"
low_income_count                     <- "S1701_C01_042"
low_income_percent                   <- NA
older_adults_universe                <- "S0101_C01_001"
older_adults_count                   <- "S0101_C01_030"
older_adults_percent                 <- "S0101_C02_030"
racial_minority_universe             <- "B02001_001"
racial_minority_count                <- "B02001_002"
racial_minority_percent              <- NA
youth_universe                       <- "B03002_001"
youth_count                          <- "B09001_001"
youth_percent                        <- NA
ipd_year <- 2017
geo <- read_csv(here("outputs", "geo.csv"))
ipd_states <- unique(geo$state)
ipd_counties <- geo$fipscounty
# Functions
min <- function(i, ..., na.rm = TRUE) {
  base::min(i, ..., na.rm = na.rm)
}
mean <- function(i, ..., na.rm = TRUE) {
  base::mean(i, ..., na.rm = na.rm)
}
sd <- function(i, ..., na.rm = TRUE) {
  stats::sd(i, ..., na.rm = na.rm)
}
max <- function(i, ..., na.rm = TRUE) {
  base::max(i, ..., na.rm = na.rm)
}
st_dev_breaks <- function(x, i, na.rm = TRUE){
  half_st_dev_count <- c(-1 * rev(seq(1, i, by = 2)),
                         seq(1, i, by = 2))
  if((i %% 2) == 1) {
    half_st_dev_breaks <- sapply(half_st_dev_count,
                                 function(i) (0.5 * i * sd(x)) + mean(x))
    half_st_dev_breaks[[1]] <- 0
    half_st_dev_breaks[[2]] <- ifelse(half_st_dev_breaks[[2]] < 0,
                                      0.1,
                                      half_st_dev_breaks[[2]])
    half_st_dev_breaks[[i + 1]] <- ifelse(max(x) > half_st_dev_breaks[[i + 1]],
                                          max(x), half_st_dev_breaks[[i + 1]])
  } else {
    half_st_dev_breaks <- NA
  }
  return(half_st_dev_breaks)
}
move_last <- function(df, last_col) {
  match(c(setdiff(names(df), last_col), last_col), names(df))
}
description <- function(i) {
  des <- as.numeric(descr(i, na.rm = TRUE,
                          stats = c("min", "med", "mean", "sd", "max")))
  des <- c(des[1:4], des[4] / 2, des[5])
  return(des)
}
## VARIANCE REPLICATES
ipd_states_numeric <- fips_codes %>%
  filter(state %in% ipd_states) %>%
  select(state_code) %>% distinct(.) %>% pull(.)
var_rep <- NULL
for (i in 1:length(ipd_states)){
  url <- paste0("https://www2.census.gov/programs-surveys/acs/replicate_estimates/",
                ipd_year,
                "/data/5-year/140/B02001_",
                ipd_states_numeric[i],
                ".csv.gz")
  temp <- tempfile()
  download.file(url, temp)
  var_rep_i <- read_csv(gzfile(temp))
  var_rep <- rbind(var_rep, var_rep_i)
}
var_rep <- var_rep %>%
  mutate_at(vars(GEOID), funs(str_sub(., 8, 18))) %>%
  filter(str_sub(GEOID, 1, 5) %in% ipd_counties) %>%
  select(-TBLID, -NAME, -ORDER, -moe, -CME, -SE) %>%
  filter(TITLE %in% c("Black or African American alone",
                      "American Indian and Alaska Native alone",
                      "Asian alone",
                      "Native Hawaiian and Other Pacific Islander alone",
                      "Some other race alone",
                      "Two or more races:"))
num <- var_rep %>% 
  group_by(GEOID) %>%
  summarize_if(is.numeric, funs(sum)) %>%
  select(-GEOID)
estim <- num %>% select(estimate)
individual_replicate <- num %>% select(-estimate)
id <- var_rep %>% select(GEOID) %>% distinct(.) %>% pull(.)
sqdiff_fun <- function(v, e) (v - e) ^ 2
sqdiff <- mapply(sqdiff_fun, individual_replicate, estim) 
sum_sqdiff <- rowSums(sqdiff)
variance <- 0.05 * sum_sqdiff
moe <- round(sqrt(variance) * 1.645, 0)
rm_moe <- cbind(id, moe) %>%
  as_tibble(.) %>%
  dplyr::rename(GEOID10 = id, RM_CntMOE = moe) %>%
  mutate_at(vars(RM_CntMOE), as.numeric)
## DOWNLOADS
# Counts and universes
counts <- c(disabled_count, disabled_universe,
            ethnic_minority_count, ethnic_minority_universe,
            female_count, female_universe,
            foreign_born_count, foreign_born_universe,
            limited_english_proficiency_count, limited_english_proficiency_universe,
            low_income_count, low_income_universe,
            older_adults_count, older_adults_universe,
            racial_minority_count, racial_minority_universe,
            youth_count, youth_universe)
counts_ids <- c("D_C", "D_U", "EM_C", "EM_U", "F_C", "F_U",
                "FB_C", "FB_U", "LEP_C", "LEP_U", "LI_C", "LI_U",
                "OA_C", "OA_U", "RM_C", "RM_U", "Y_C", "Y_U")
# Zip count API variables and their appropriate abbreviations together
counts_calls <- tibble(id = counts_ids, api = counts) %>%
  drop_na(.)
# Separate into different types of API requests
s_calls <- counts_calls %>%
  filter(str_sub(api, 1, 1) == "S")
d_calls <- counts_calls %>%
  filter(str_sub(api, 1, 1) == "B")
dp_calls <- counts_calls %>%
  filter(str_sub(api, 1, 1) == "D")
# Make requests; if variables exist for this type, dl and append
dl_counts <- NULL
if(length(s_calls$id > 0)){
  s_counts <- get_acs(geography = "tract",
                      state = ipd_states,
                      output = "wide",
                      year = ipd_year,
                      variables = s_calls$api) %>%
    select(-NAME)
  dl_counts <- bind_cols(dl_counts, s_counts)
}
if(length(d_calls$id > 0)){
  d_counts <- get_acs(geography = "tract",
                      state = ipd_states,
                      output = "wide",
                      year = ipd_year,
                      variables = d_calls$api) %>%
    select(-NAME)
  dl_counts <- left_join(dl_counts, d_counts)
}
if(length(dp_calls$id > 0)){
  dp_counts <- get_acs(geography = "tract",
                       state = ipd_states,
                       output = "wide",
                       year = ipd_year,
                       variables = dp_calls$api) %>%
    select(-NAME)
  dl_counts <- left_join(dl_counts, dp_counts)
}
dl_counts <- dl_counts %>%
  dplyr::rename(GEOID10 = GEOID)
# For DP downloads, make sure counts_calls and dl_counts match
counts_calls$api <- str_replace(counts_calls$api, "E$", "")
for(i in 1:length(counts_calls$id)){
  names(dl_counts) <- str_replace(names(dl_counts),
                                  counts_calls$api[i],
                                  counts_calls$id[i])
}
# Identify duplicate API columns and create if missing
duplicate_cols <- counts_calls %>% 
  group_by(api) %>% 
  filter(n()>1) %>%
  summarize(orig = id[1],
            duplicator = id[2])
e_paste <- function(i) paste0(i, "E")
m_paste <- function(i) paste0(i, "M")
e_rows <- apply(duplicate_cols, 2, e_paste)
m_rows <- apply(duplicate_cols, 2, m_paste)
combined_rows <- as_tibble(rbind(e_rows, m_rows)) %>%
  mutate_all(as.character)
for(i in 1:length(combined_rows$api)){
  dl_counts[combined_rows$duplicator[i]] <- dl_counts[combined_rows$orig[i]]
}
# Percentages
percs <- c(disabled_percent,
           ethnic_minority_percent,
           female_percent,
           foreign_born_percent,
           limited_english_proficiency_percent,
           low_income_percent,
           older_adults_percent,
           racial_minority_percent,
           youth_percent)
percs_ids <- c("D_P", "EM_P", "F_P", "FB_P", "LEP_P",
               "LI_P", "OA_P", "RM_P", "Y_P")
percs_calls <- tibble(id = percs_ids, api = percs) %>%
  drop_na(.)
s_calls <- percs_calls %>%
  filter(str_sub(api, 1, 1) == "S")
d_calls <- percs_calls %>%
  filter(str_sub(api, 1, 1) == "B")
dp_calls <- percs_calls %>%
  filter(str_sub(api, 1, 1) == "D")
dl_percs <- NULL
if(length(s_calls$id > 0)){
  s_percs <- get_acs(geography = "tract",
                     state = ipd_states,
                     output = "wide",
                     year = ipd_year,
                     variables = s_calls$api) %>%
    select(-NAME)
  dl_percs <- bind_cols(dl_percs, s_percs)
}
if(length(d_calls$id > 0)){
  d_percs <- get_acs(geography = "tract",
                     state = ipd_states,
                     output = "wide",
                     year = ipd_year,
                     variables = d_calls$api) %>%
    select(-NAME)
  dl_percs <- left_join(dl_percs, d_percs)
}
if(length(dp_calls$id > 0)){
  dp_percs <- get_acs(geography = "tract",
                      state = ipd_states,
                      output = "wide",
                      year = ipd_year,
                      variables = dp_calls$api) %>%
    select(-NAME)
  dl_percs <- left_join(dl_percs, dp_percs)
}
dl_percs <- dl_percs %>%
  dplyr::rename(GEOID10 = GEOID)
# For DP downloads, make sure percs_calls and dl_percs match
percs_calls$api <- str_replace(percs_calls$api, "PE", "")
names(dl_percs) <- str_replace(names(dl_percs), "PE", "E")
names(dl_percs) <- str_replace(names(dl_percs), "PM", "M")
for(i in 1:length(percs_calls$id)){
  names(dl_percs) <- str_replace(names(dl_percs),
                                 percs_calls$api[i],
                                 percs_calls$id[i])
}
# Subset for region
dl_counts <- dl_counts %>%
  filter(str_sub(GEOID10, 1, 5) %in% ipd_counties)
dl_percs <- dl_percs %>%
  filter(str_sub(GEOID10, 1, 5) %in% ipd_counties)
## CALCULATIONS
# Exception 1: RM_CE = RM_UE - RM_CE
dl_counts <- dl_counts %>% mutate(x = RM_UE - RM_CE) %>%
  select(-RM_CE) %>%
  dplyr::rename(RM_CE = x)
# Exception 2: Substitute in RM_CntMOE
if(exists("rm_moe")){
  dl_counts <- dl_counts %>%
    select(-RM_CM) %>%
    left_join(., rm_moe) %>%
    dplyr::rename(RM_CM = RM_CntMOE) %>%
    mutate_at(vars(RM_CM), as.numeric)
}
# Exception 3: Slice low-population tracts
slicer <- dl_counts %>% filter(F_UE < 100) %>%
  select(GEOID10) %>% pull(.)
dl_counts <- dl_counts %>% filter(!(GEOID10 %in% slicer))
dl_percs <- dl_percs %>% filter(!(GEOID10 %in% slicer))
# Split `dl_counts` into list for processing
# Sort column names for consistency
# `comp` = "component parts"
comp <- list()
comp$uni_est <- dl_counts %>% select(ends_with("UE")) %>% select(sort(current_vars()))
comp$uni_moe <- dl_counts %>% select(ends_with("UM")) %>% select(sort(current_vars()))
comp$count_est <- dl_counts %>% select(ends_with("CE")) %>% select(sort(current_vars()))
comp$count_moe <- dl_counts %>% select(ends_with("CM")) %>% select(sort(current_vars()))
# Compute percentages and associated MOEs
pct_matrix <- NULL
pct_moe_matrix <- NULL
for (c in 1:length(comp$uni_est)){
  pct <- unlist(comp$count_est[,c] / comp$uni_est[,c])
  pct_matrix <- cbind(pct_matrix, pct)
  moe <- NULL
  for (r in 1:length(comp$uni_est$LI_UE)){
    moe_indiv <- as.numeric(moe_prop(comp$count_est[r,c],
                                     comp$uni_est[r,c],
                                     comp$count_moe[r,c],
                                     comp$uni_moe[r,c]))
    moe <- append(moe, moe_indiv)
  }
  pct_moe_matrix <- cbind(pct_moe_matrix, moe)
}
# Result: `pct` and `pct_moe` have percentages and associated MOEs
pct <- as_tibble(pct_matrix) %>% mutate_all(funs(. * 100)) %>% mutate_all(round, 1)
names(pct) <- str_replace(names(comp$uni_est), "_UE", "_PctEst")
pct_moe <- as_tibble(pct_moe_matrix) %>% mutate_all(funs(. * 100)) %>% mutate_all(round, 1)
names(pct_moe) <- str_replace(names(comp$uni_est), "_UE", "_PctMOE")
# Exception 4: If MOE == 0; MOE = 0.1
pct_moe <- pct_moe %>% replace(., . == 0, 0.1)
# Exception 5: Substitute percentages and associated MOEs when available from AFF
pct <- pct %>% mutate(D_PctEst = dl_percs$D_PE,
                      OA_PctEst = dl_percs$OA_PE,
                      LEP_PctEst = dl_percs$LEP_PE,
                      F_PctEst = dl_percs$F_PE)
pct_moe <- pct_moe %>% mutate(D_PctMOE = dl_percs$D_PM,
                              OA_PctMOE = dl_percs$OA_PM,
                              LEP_PctMOE = dl_percs$LEP_PM,
                              F_PctMOE = dl_percs$F_PM)
# Compute percentile
# Add percentages to `comp`; sort column names for consistency
comp$pct_est <- pct %>% select(sort(current_vars()))
percentile_matrix <- NULL
for (c in 1:length(comp$uni_est)){
  p <- unlist(comp$pct_est[,c])
  rank <- ecdf(p)(p)
  percentile_matrix <- cbind(percentile_matrix, rank)
}
# Result: `percentile` has rank
percentile <- as_tibble(percentile_matrix) %>% mutate_all(round, 2)
names(percentile) <- str_replace(names(comp$uni_est), "_UE", "_Pctile")
# Compute IPD score and classification
score_matrix <- NULL
class_matrix <- NULL
for (c in 1:length(comp$uni_est)){
  p <- unlist(comp$pct_est[,c])
  breaks <- st_dev_breaks(p, 5, na.rm = TRUE)
  score <- case_when(p < breaks[2] ~ 0,
                     p >= breaks[2] & p < breaks[3] ~ 1,
                     p >= breaks[3] & p < breaks[4] ~ 2,
                     p >= breaks[4] & p < breaks[5] ~ 3,
                     p >= breaks[5] ~ 4)
  class <- case_when(score == 0 ~ "Well Below Average",
                     score == 1 ~ "Below Average",
                     score == 2 ~ "Average",
                     score == 3 ~ "Above Average",
                     score == 4 ~ "Well Above Average")
  score_matrix <- cbind(score_matrix, score)
  class_matrix <- cbind(class_matrix, class)
}
# Result: `score` and `class` have IPD scores and associated descriptions
score <- as_tibble(score_matrix)
names(score) <- str_replace(names(comp$uni_est), "_UE", "_Score")
class <- as_tibble(class_matrix)
names(class) <- str_replace(names(comp$uni_est), "_UE", "_Class")
# Compute total IPD score
score <- score %>% mutate(IPD_Score = rowSums(.))
## CLEANING
# Merge all information into a single df
ipd <- bind_cols(dl_counts, pct) %>%
  bind_cols(., pct_moe) %>%
  bind_cols(., percentile) %>%
  bind_cols(., score) %>%
  bind_cols(., class)
# Rename columns
names(ipd) <- str_replace(names(ipd), "_CE", "_CntEst")
names(ipd) <- str_replace(names(ipd), "_CM", "_CntMOE")
ipd <- ipd %>% mutate(STATEFP10 = str_sub(GEOID10, 1, 2),
                      COUNTYFP10 = str_sub(GEOID10, 3, 5),
                      NAME10 = str_sub(GEOID10, 6, 11),
                      U_TPopEst = F_UE,
                      U_TPopMOE = F_UM,
                      U_Pop6Est = LEP_UE,
                      U_Pop6MOE = LEP_UM,
                      U_PPovEst = LI_UE,
                      U_PPovMOE = LI_UM,
                      U_PNICEst = D_UE,
                      U_PNICMOE = D_UM) %>%
  select(-ends_with("UE"), -ends_with("UM"))
# Reorder columns
ipd <- ipd %>% select(GEOID10, STATEFP10, COUNTYFP10, NAME10, sort(current_vars())) %>%
  select(move_last(., c("IPD_Score", "U_TPopEst", "U_TPopMOE",
                        "U_Pop6Est", "U_Pop6MOE", "U_PPovEst",
                        "U_PPovMOE", "U_PNICEst", "U_PNICMOE")))
# Append low-population tracts back onto dataset
slicer <- enframe(slicer, name = NULL, value = "GEOID10")
ipd <- plyr::rbind.fill(ipd, slicer)
# Drop NA rows 
ipd <- ipd %>% drop_na(.)

## SUMMARY TABLES
# Population-weighted metro means for each indicator
export_means_metro <- dl_counts %>% select(GEOID10, ends_with("UE"), ends_with("CE")) %>%
  mutate(stcty = str_sub(GEOID10, 1, 5)) %>%
  left_join(., geo, by = c("stcty" = "fipscounty")) %>%
  select(-GEOID10, -stcty, -state, -msa, -y2017) %>%
  group_by(msaname) %>%
  summarize(D_PctEst = sum(D_CE) / sum(D_UE),
            EM_PctEst = sum(EM_CE) / sum(EM_UE),
            F_PctEst = sum(F_CE) / sum(F_UE),
            FB_PctEst = sum(FB_CE) / sum(FB_UE),
            LEP_PctEst = sum(LEP_CE) / sum(LEP_UE),
            LI_PctEst = sum(LI_CE) / sum(LI_UE),
            OA_PctEst = sum(OA_CE) / sum(OA_UE),
            RM_PctEst = sum(RM_CE) / sum(RM_UE),
            Y_PctEst = sum(Y_CE) / sum(Y_UE)) %>%
  mutate_if(is.numeric, funs(. * 100)) %>%
  mutate_if(is.numeric, round, 1)
export_meanscore_metro <- ipd %>% select(GEOID10, IPD_Score) %>%
  mutate(stcty = str_sub(GEOID10, 1, 5)) %>%
  left_join(., geo, by = c("stcty" = "fipscounty")) %>%
  select(-GEOID10,-stcty, -state, -msa, -y2017) %>%
  group_by(msaname) %>%
  summarize(Mean_IPD = mean(IPD_Score)) %>%
  mutate_if(is.numeric, round, 0)
export_means_metro <- full_join(export_means_metro, export_meanscore_metro)
# County-level scores and shapefiles
export_means_cty <- dl_counts %>% select(GEOID10, ends_with("UE"), ends_with("CE")) %>%
  mutate(stcty = str_sub(GEOID10, 1, 5)) %>%
  left_join(., geo, by = c("stcty" = "fipscounty")) %>%
  select(-GEOID10, -state, -msa, -y2017) %>%
  group_by(stcty) %>%
  summarize(D_PctEst = sum(D_CE) / sum(D_UE),
            EM_PctEst = sum(EM_CE) / sum(EM_UE),
            F_PctEst = sum(F_CE) / sum(F_UE),
            FB_PctEst = sum(FB_CE) / sum(FB_UE),
            LEP_PctEst = sum(LEP_CE) / sum(LEP_UE),
            LI_PctEst = sum(LI_CE) / sum(LI_UE),
            OA_PctEst = sum(OA_CE) / sum(OA_UE),
            RM_PctEst = sum(RM_CE) / sum(RM_UE),
            Y_PctEst = sum(Y_CE) / sum(Y_UE)) %>%
  mutate_if(is.numeric, funs(. * 100)) %>%
  mutate_if(is.numeric, round, 1)
export_meanscore_cty <- ipd %>% select(GEOID10, IPD_Score) %>%
  mutate(stcty = str_sub(GEOID10, 1, 5)) %>%
  left_join(., geo, by = c("stcty" = "fipscounty")) %>%
  select(-GEOID10, -state, -msa, -y2017) %>%
  group_by(stcty, msaname) %>%
  summarize(Mean_IPD = mean(IPD_Score)) %>%
  mutate_if(is.numeric, round, 0)
export_means_cty <- full_join(export_means_cty, export_meanscore_cty)
## EXPORT
options(tigris_use_cache = TRUE, tigris_class = "sf")
st <- str_sub(ipd_counties, 1, 2)
cty <- str_sub(ipd_counties, 3, 5)
all_cty <- map(st, ~{counties(state = .x,
                              cb = TRUE,
                              year = ipd_year)}) %>%
  rbind_tigris() %>%
  st_transform(., 102003) %>%
  select(GEOID) %>%
  left_join(., export_means_cty, by = c("GEOID" = "stcty")) %>%
  rename(GEOID10 = GEOID) %>%
  group_by(GEOID10) %>%
  slice(., 1)
all_cty <- drop_na(all_cty)
st_write(all_cty, here("outputs", "ipd.shp"), delete_dsn = TRUE, quiet = TRUE)
write_csv(ipd, here("outputs", "ipd.csv"))
write_csv(export_means_metro, here("outputs", "mean_by_metro.csv"))
write_csv(export_means_cty, here("outputs", "mean_by_county.csv"))
