#===============================================================================
# Analysis of NHS winter sitrep data 2018/2019
# Purpose: import, clean and generate STP map of bed occupancy by month
# Authour: Fiona Grimm
# Date: 03/2019
#===============================================================================

# 1. Import packages ------------------------------------------------------

library(tidyverse)
library(readxl)
library(lubridate)
library(geojsonio)
library(broom)
library(maptools)


# 2. Downloading winter data from NHS Digital -----------------------------

filename <- "Winter-data-timeseries-20190307.xlsx"
url <- "https://www.england.nhs.uk/statistics/wp-content/uploads/sites/2/2019/03/Winter-data-timeseries-20190307.xlsx"


download.file(url, destfile = filename, mode = "wb")


# 3. Importing data from R-unfriendly spreadsheets ------------------------

### Exploring the double header problem

example_indicator <- "G&A beds"

# First line containes dates in merged cells (5 cells merged each in this case)
header_1 <- read_xlsx(path = filename, sheet = example_indicator, 
                      skip = 13, col_names = FALSE, 
                      n_max = 1)

# Second line contains variable names
header_2 <- read_xlsx(path = filename, sheet = example_indicator, 
                      skip = 14, col_names = FALSE, 
                      n_max = 1)

dim(header_1)
dim(header_2)

# Start of header 1
header_1[1:10]

# End of header 1
header_1[(ncol(header_1)-10):ncol(header_1)]


### A function to import sitrep data
import_sitrep <- function(file, indicator){
  
  data <- read_xlsx(path = file, sheet = indicator, skip = 15, col_names = FALSE) 
  
  # Extract first header line containing dates and fill the gaps: 
  # Read 2 lines but guess the data types only from the first row
  # R will be looking for dates and convert the second row
  # to NA but the right length will be preserved. 
  header_1 <- read_xlsx(path = file, sheet = indicator, skip = 13, col_names = FALSE, n_max = 2, guess_max = 1)
  
  # Convert to columns, fill in the gaps and convert into vector
  header_1 <- header_1 %>% 
    t() %>% 
    as.data.frame() %>% 
    fill(.,'V1') 
  header_1 <- as.character(header_1$V1)  
  
  # Extract second header and convert into vector
  header_2 <- read_xlsx(path = file, sheet = indicator, skip = 14, col_names = FALSE, n_max = 1)
  header_2 <- unname(unlist(header_2[1,]))
  
  # Concatenating headers to create column names
  # Replace NAs with a placeholder, otherwise concatenation fails
  column_names <- str_c(str_replace_na(header_1, "placeholder"), str_replace_na(header_2, "placeholder"), sep = "_")
  
  # Add column names to data and tidy
  names(data) <- tolower(column_names)
  names(data) <- gsub(" ", ".", names(data))
  names(data) <- gsub("placeholder_", "", names(data))
  names(data) <- gsub("'", "", names(data))
  names(data) <- gsub("<", "less.than", names(data))
  names(data) <- gsub(">", "more.than", names(data))
  
  # Tidy up table
  data_tidy <- data %>% 
    # remove empty column and line
    select(-placeholder) %>% 
    filter(!is.na(name)) %>%
    # Separate variables and dates
    gather(-1, -2, -3, key = "date_type", value = 'value') %>%
    separate(date_type, into = c("date", "type"), sep = "_") %>%
    spread(key = 'type', value = 'value') %>%
    # convert to the right variable types
    mutate(date = as.Date(date)) %>%
    mutate_at(vars(5:ncol(.)), funs(as.numeric))
  
  data_tidy
}


### Import and combine sheets
sheets_to_import <- c("G&A beds", "Beds Occ by long stay patients")

Sitrep_daily <- sheets_to_import %>% 
  map(import_sitrep, 
      file = filename) %>% 
  reduce(left_join, 
         by = c("nhs.england.region", "code", "name", "date"))

# What does our data look like now?
dim(Sitrep_daily)

head(Sitrep_daily)


# 4. Data cleaning --------------------------------------------------------

### Trust Exclusions

# children's hospitals to be exlcuded for aggregation by STP
trusts_to_exclude_for_aggregation <- c("RQ3", "RBS", "RCU")


### Finding  periods of missing data

# Only check variables that are not derived from other variables
cols_to_check <- c("core.beds.open", "total.beds.occd", 
                   "more.than.7.days", "more.than.14.days", "more.than.21.days")

# Find values that are 0 or NA
# within any trust/variable combination
Sitrep_missing_or_zero <- Sitrep_daily %>% 
  filter(name != 'ENGLAND') %>%
  gather(cols_to_check, key = 'variable', value = 'value') %>% 
  filter(value == 0 | is.na(value)) %>% 
  # Sort and assign a period ID to consecutive days
  arrange(code, variable, date) %>%
  group_by(code, variable) %>%
  mutate(diff = c(0, diff(date)),
         periodID = 1 + cumsum(diff > 1)) 

# Summarise consecutive days that variables are missing 
Days_missing <- Sitrep_missing_or_zero %>%
  # remove trusts we already decided to exclude
  filter(!is.element(code, trusts_to_exclude_for_aggregation)) %>%
  group_by(code, variable, periodID) %>%
  summarise(days = as.numeric((last(date) - first(date) + 1))) %>% 
  arrange(desc(days))

### Longer gaps (4 or more days)

print(Days_missing[Days_missing$days >= 4,])

trusts_to_exclude <- Days_missing %>% 
  filter(days >= 4) %>% 
  ungroup() %>% 
  # Extract column as vector
  pull(code) %>% 
  unique()

print(trusts_to_exclude)


Sitrep_daily <- Sitrep_daily %>% 
  filter(!is.element(code, trusts_to_exclude))

dim(Sitrep_daily)

### Dealing with shorter gaps

# How many 1,2 and 3-day gaps are there?
Days_missing %>% 
  filter(!is.element(code, trusts_to_exclude)) %>% 
  group_by(days) %>% 
  count()

# How are they distributed between trusts and variables?
Days_missing %>% 
  filter(!is.element(code, trusts_to_exclude)) %>% 
  group_by(code, variable) %>% 
  count() %>% 
  spread(key = "variable", value = "n")

# Extract and plot trusts with zeros in their data. 
Sitrep_daily_small_gaps <- Sitrep_daily %>% 
  select(code, date, cols_to_check) %>% 
  filter(code %in% Days_missing$code & !is.element(code, trusts_to_exclude)) %>% 
  gather(cols_to_check, key = 'variable', value = "value")

ggplot(Sitrep_daily_small_gaps, aes(x = date, y = value, group = code, color = code)) +
  theme_bw() +
  geom_line() +
  geom_point(size = 1) +
  facet_wrap("variable", scales = "free_y") 

# Create a 'clean' version where 0s were replaced with NA
Sitrep_daily[cols_to_check] <- na_if(Sitrep_daily[cols_to_check], 0)


### Validating derived variables

Sitrep_daily <- Sitrep_daily %>% 
  mutate(total.beds.open.check = core.beds.open + escalation.beds.open,
         occupancy.rate.check = total.beds.occd / (core.beds.open + escalation.beds.open))

# Are the newly derives values the same as the existing ones?
all(round(Sitrep_daily$occupancy.rate, 6) == round(Sitrep_daily$occupancy.rate.check, 6))

all(Sitrep_daily$total.beds.open == Sitrep_daily$total.beds.open.check)


# Where are the mismatches?
Sitrep_daily[Sitrep_daily$total.beds.open != Sitrep_daily$total.beds.open.check, 
             c("code", "date", "core.beds.open", "escalation.beds.open", "total.beds.open", 
               "total.beds.open.check")]

# Looks like we will have to re-derive both variables after all
Sitrep_daily <- Sitrep_daily %>% 
  mutate(total.beds.open = core.beds.open + escalation.beds.open,
         occupancy.rate = total.beds.occd / (core.beds.open + escalation.beds.open))


# 5. Feature engineering --------------------------------------------------

### Adding organisational information: Sustainability and Transformation Partnerships (STPs)

# ideally save this table as a csv for future use
STP_lookup <- read_csv("Trust-STP-lookup.csv")
Sitrep_daily <- Sitrep_daily %>%
  left_join(STP_lookup[c('code', 'STP', 'STP_code')], by = c("code"))


### Making read-outs comparable between trusts: from raw counts to rates

# rate of occupied beds that are occupied by long-stay patients
Sitrep_daily <- Sitrep_daily %>% 
  mutate(more.than.7.rate = more.than.7.days / total.beds.occd,
         more.than.14.rate = more.than.14.days / total.beds.occd,
         more.than.21.rate = more.than.21.days / total.beds.occd)


# 6. Aggregation: monthly averages by STP ---------------------------------

Sitrep_daily <- Sitrep_daily %>% 
  mutate(week_start = as.Date(cut(date, breaks = "week", start.on.monday = TRUE)), #can be used to aggregate by week
         month = format(date, format = "%B"))

Sitrep_daily_STP <- Sitrep_daily %>% 
  filter(!is.element(code, trusts_to_exclude_for_aggregation)) %>%
  group_by(STP, STP_code, date) %>%
  summarize(occupancy.rate.valid = sum(!is.na(occupancy.rate)),
            more.than.7.rate.valid = sum(!is.na(more.than.7.rate)),
            more.than.14.rate.valid = sum(!is.na(more.than.14.rate)),
            more.than.21.rate.valid = sum(!is.na(more.than.21.rate)),
            occupancy.rate = mean(occupancy.rate, na.rm=TRUE),
            more.than.7.rate = mean(more.than.7.rate, na.rm=TRUE),
            more.than.14.rate = mean(more.than.14.rate, na.rm=TRUE),
            more.than.21.rate = mean(more.than.21.rate, na.rm=TRUE))

# Weekly average on trust level
Sitrep_weekly_average_bytrust <- Sitrep_daily %>%
  group_by(nhs.england.region, code, name, STP, STP_code, week_start) %>%
  # Count the number of valid observations for each variable
  # BEFORE we overwrite the variables
  summarize(occupancy.rate.valid = sum(!is.na(occupancy.rate)),
            more.than.7.rate.valid = sum(!is.na(more.than.7.rate)),            
            more.than.14.rate.valid = sum(!is.na(more.than.14.rate)),
            more.than.21.rate.valid = sum(!is.na(more.than.21.rate)),
            occupancy.rate = mean(occupancy.rate, na.rm=TRUE),
            more.than.7.rate = mean(more.than.7.rate, na.rm=TRUE),
            more.than.14.rate = mean(more.than.14.rate, na.rm=TRUE),
            more.than.21.rate = mean(more.than.21.rate, na.rm=TRUE))


# Weekly average on STP level
Sitrep_weekly_average_bySTP <- Sitrep_weekly_average_bytrust %>%
  filter(!is.element(code, trusts_to_exclude_for_aggregation)) %>%
  group_by(STP, STP_code, week_start) %>%
  summarise(occupancy.rate.valid = sum(!is.na(occupancy.rate)),
            more.than.7.rate.valid = sum(!is.na(more.than.7.rate)),
            more.than.14.rate.valid = sum(!is.na(more.than.14.rate)),
            more.than.21.rate.valid = sum(!is.na(more.than.21.rate)),
            occupancy.rate = mean(occupancy.rate, na.rm=TRUE),
            more.than.7.rate = mean(more.than.7.rate, na.rm=TRUE),
            more.than.14.rate = mean(more.than.14.rate, na.rm=TRUE),
            more.than.21.rate = mean(more.than.21.rate, na.rm=TRUE))


# Monthly average on trust level
Sitrep_monthly_average_bytrust <- Sitrep_daily %>%
  group_by(nhs.england.region, code, name, STP, STP_code, month) %>%
  # Count the number of valid observations for each variable
  # BEFORE we overwrite the variables
  summarize(occupancy.rate.valid = sum(!is.na(occupancy.rate)),
            more.than.7.rate.valid = sum(!is.na(more.than.7.rate)),
            more.than.14.rate.valid = sum(!is.na(more.than.14.rate)),
            more.than.21.rate.valid = sum(!is.na(more.than.21.rate)),
            occupancy.rate = mean(occupancy.rate, na.rm=TRUE),
            more.than.7.rate = mean(more.than.7.rate, na.rm=TRUE),
            more.than.14.rate = mean(more.than.14.rate, na.rm=TRUE),
            more.than.21.rate = mean(more.than.21.rate, na.rm=TRUE))

# Monthly average on STP level
Sitrep_monthly_average_bySTP <- Sitrep_monthly_average_bytrust %>%
  filter(!is.element(code, trusts_to_exclude_for_aggregation)) %>%
  group_by(STP, STP_code, month) %>%
  summarise(occupancy.rate.valid = sum(!is.na(occupancy.rate)),
            more.than.7.rate.valid = sum(!is.na(more.than.7.rate)),
            more.than.14.rate.valid = sum(!is.na(more.than.14.rate)),
            more.than.21.rate.valid = sum(!is.na(more.than.21.rate)),
            occupancy.rate = mean(occupancy.rate, na.rm=TRUE),
            more.than.7.rate = mean(more.than.7.rate, na.rm=TRUE),
            more.than.14.rate = mean(more.than.14.rate, na.rm=TRUE),
            more.than.21.rate = mean(more.than.21.rate, na.rm=TRUE))


# 7. Visualisation: creating maps in R ------------------------------------

# Download and read file containing STP shapes from the ONS website
# We will use the smaller, generalised version for mapping rather than the full boundaries

STP_geojson_filename <- "Sustainability_and_Transformation_Partnerships_February_2017_Ultra_Generalised_Clipped_Boundaries_in_England.geojson.json"
STP_geojson_url <- "http://geoportal1-ons.opendata.arcgis.com/datasets/571bd4512165461fad70a0ccc36450e4_4.geojson"

download.file(STP_geojson_url, STP_geojson_filename)
data_json <- geojson_read(STP_geojson_filename, what = "sp")

plot(data_json)


# to use ggplot for maps, we first need to turn sp data into a dataframe
# make sure the region argument so as not to lose the STP identiers
data_json_df <- tidy(data_json, region = "stp17cd")

# Join with the winter indicator data aggregated by month
STP_shape_monthly <- data_json_df %>% 
  left_join(Sitrep_monthly_average_bySTP, by = c("id" = "STP_code"))

STP_shape_monthly <- STP_shape_monthly %>%
  # Divide variable into invervals and turn into factors
  mutate(occupancy.rate.cut = cut(occupancy.rate, breaks = c(0, 0.85, 0.9, 0.95, 1), 
                                  labels=c("85% or less", "85-90%", "90-95%", "over 95%")),
         occupancy.rate.cut = factor(as.character(occupancy.rate.cut),
                                     levels = rev(levels(occupancy.rate.cut)))) %>% 
  # Remove lines relating England as a whole
  filter(!is.na(STP)) %>% 
  # Turn STPs and months into factors (ignoring March)
  mutate(id = factor(id, levels = unique(id)),
         month = factor(month, levels = c("December", "January", "February"))) %>% 
  filter(!is.na(month))

# Plot and save the map
map_monthly_bedocc <- ggplot() + 
  geom_polygon(data = STP_shape_monthly, 
               aes(x = long, y = lat, group = group, fill = occupancy.rate.cut), 
               colour = "white") +
  # Remove grid lines
  theme_void() +
  # Ensure correct aspect ratio
  coord_map() +
  # Facet by month
  facet_grid(.~month, switch = "x") +
  # Define colour palette
  scale_fill_manual(values = c("#dd0031", '#ee7074', '#f2a0a2', '#aad3e5'), drop = FALSE) +
  guides(fill = guide_legend(ncol = 2, byrow = FALSE, label.hjust = 0)) +
  labs(title = "Mean bed occupancy during winter 2018/19") +
  # Other design choices
  theme(plot.title = element_text(size = 25*ggplot2:::.pt, colour = "#005078", margin = margin(b = 15, unit = "mm")),
        plot.margin = margin(t = 30, l = 22, b = 30, r = 22, unit = "mm"),
        legend.background = element_rect(fill = NA),
        legend.justification= c(1,0),
        legend.key = element_blank(),
        legend.margin = margin(b = 10, l = 20, unit = "mm"), 
        legend.text = element_text(size = 16*ggplot2:::.pt, colour = "#524c48"), 
        legend.title = element_blank(),
        legend.position = "top",
        legend.spacing.x = unit(10, "mm"),
        legend.spacing.y = unit(10, "mm"),
        legend.key.size = unit(18, "mm"),
        strip.text = element_text(size = 16*ggplot2:::.pt, colour = "#524c48", margin = margin(b = 10))) 


ggsave("Bedocc_monthly_map.png", map_monthly_bedocc, device = "png",  width = 650, height = 400, units = c("mm"))
