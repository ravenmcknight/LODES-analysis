## packages -----------------------------------------------

# these lines make sure any user has all the necessary packages
packages <- c('data.table', 'tigris', 'sf', 'dplyr')

miss_pkgs <- packages[!packages %in% installed.packages()[,1]]

if(length(miss_pkgs) > 0){
  install.packages(miss_pkgs)
}

invisible(lapply(packages, library, character.only = TRUE))

rm(miss_pkgs, packages)

## data ---------------------------------------------------

# this section downloads all of the LODES files from the census website
# this way we don't have to download them individually 
# and any user can run this
# if we just want the most recent year, this step gets much simpler and we can look just at 2017

years <- c('2002', '2003', '2004', '2005', '2006', '2007', '2008', '2009', '2010', '2011', '2012', '2013', '2014', '2015', '2016', '2017')

urls <- c()
for (y in years){
  url1 <- paste0('https://lehd.ces.census.gov/data/lodes/LODES7/mn/od/mn_od_main_JT00_', y, '.csv.gz') # live in state
  url2 <- paste0('https://lehd.ces.census.gov/data/lodes/LODES7/mn/od/mn_od_aux_JT00_', y, '.csv.gz') # live out of state
  urls <- rbind(urls, url1, url2)
}

years2 <- rep(years, each = 2)

for (i in 1:length(urls)){
  if (urls[i] %like% 'main'){
    dest <- paste0('data/', years2[i], '.csv.gz')
    download.file(urls[i, ], dest)
  }
  else{
    dest <- paste0('data/', years2[i], '_aux.csv.gz')
    download.file(urls[i, ], dest)
  }
}

# read files --------------------------
files <- list.files(path = 'data/')
l <- lapply(paste0('data/', files), fread)  # this should be more elegant but alas

for (i in 1:length(l)){
  l[[i]]$year <- years2[i]
}

dt <- rbindlist(l)

# save raw data since it's so big so we don't have to run this again
# you can also save as a csv or xlsx 
saveRDS(dt, 'data/raw_data.RDS')

## cleaning ------------------------------------------------

# this is the part we might have to change to work better for the GIS project

# restrict to jobs in metro area
# if you haven't used tigris to work with census shapefiles i strongly recommend
options(tigris_class = 'sf')
counties <- c('Anoka', 'Hennepin', 'Ramsey', 'Carver', 'Washington', 'Scott', 'Sherburne', 'Wright', 'Dakota')
bs <- blocks(state = 'MN', county = counties, year = 2016)

dt$GEOID10 <- as.character(dt$w_geocode)
dt <- dt[GEOID10 %in% bs$GEOID10] # this is data.table instead of dplyr but could also be done with %>% filter()

# this step also takes a long time so save here
saveRDS(dt, 'data/metro_area_jobs.RDS')

dt <- readRDS('data/metro_area_jobs.RDS')

# aggregate to block groups using data.table
# easy to skip if we want more granularity
dt[, w_bg := substr(as.character(w_geocode), 1, 12)]
dt[, h_bg := substr(as.character(h_geocode), 1, 12)]

od_counts <- dt[, .(workers = sum(S000)), by = c('w_bg', 'h_bg', 'year')][order(-workers)]

saveRDS(od_counts, 'data/od_jobs.RDS')

# so od_jobs has counts of origin and destination for each block group in the metro area by year
# we can restrict to employees with origins in Saint Paul in R or GIS
