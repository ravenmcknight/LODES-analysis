# Goal: gather and clean LODES data 

library(data.table)
library(tigris)
library(sf)
library(dplyr)

# download LODES files ------------------------------------
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

# read files ----------------------------------------------
files <- list.files(path = 'data/')
l <- lapply(paste0('data/', files), fread)  # this should be more elegant

for (i in 1:length(l)){
  l[[i]]$year <- years2[i]
}

dt <- rbindlist(l)

# save raw dat
#saveRDS(dt, 'data/raw_data.RDS')

#dt <- readRDS('data/raw_data.RDS')

# cleaning ------------------------------------------------

# restrict to jobs in metro area
options(tigris_class = 'sf')
counties <- c('Anoka', 'Hennepin', 'Ramsey', 'Carver', 'Washington', 'Scott', 'Sherburne', 'Wright', 'Dakota')
bs <- blocks(state = 'MN', county = counties, year = 2016)

dt$GEOID10 <- as.character(dt$w_geocode)
dt <- dt[GEOID10 %in% bs$GEOID10]

#saveRDS(dt, 'data/metro_area_jobs.RDS')
dt <- readRDS('data/metro_area_jobs.RDS')

# aggregate to block groups
dt[, w_bg := substr(as.character(w_geocode), 1, 12)]
dt[, h_bg := substr(as.character(h_geocode), 1, 12)]

od_counts <- dt[, .(workers = sum(S000)), by = c('w_bg', 'h_bg', 'year')][order(-workers)]
saveRDS(od_counts, 'data/od_jobs.RDS')

# we can use this dt to look at where people are coming from
# let's create a simpler object to get total counts

tot_counts <- dt[, .(workers = sum(S000)), by = c('w_bg', 'year')][order(-workers)]
saveRDS(tot_counts, 'data/tot_jobs.RDS')
