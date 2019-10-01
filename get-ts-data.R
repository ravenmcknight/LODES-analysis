# Goal: gather and clean LODES data 

library(data.table)
library(tigris)
library(sf)
library(dplyr)

# download LODES files ------------------------------------
years <- c('2002', '2003', '2004', '2005', '2006', '2007', '2008', '2009', '2010', '2011', '2012', '2013', '2014', '2015', '2016', '2017')

urls <- c()
for (y in years){
  url1 <- paste0('https://lehd.ces.census.gov/ts-data/lodes/LODES7/mn/od/mn_od_main_JT00_', y, '.csv.gz') # live in state
  url2 <- paste0('https://lehd.ces.census.gov/ts-data/lodes/LODES7/mn/od/mn_od_aux_JT00_', y, '.csv.gz') # live out of state
  urls <- rbind(urls, url1, url2)
}

years2 <- rep(years, each = 2)

for (i in 1:length(urls)){
  if (urls[i] %like% 'main'){
    dest <- paste0('ts-data/', years2[i], '.csv.gz')
    download.file(urls[i, ], dest)
  }
  else{
    dest <- paste0('ts-data/', years2[i], '_aux.csv.gz')
    download.file(urls[i, ], dest)
  }
}

# read files ----------------------------------------------
files <- list.files(path = 'ts-data/')
l <- lapply(paste0('ts-data/', files), fread)  # this should be more elegant

for (i in 1:length(l)){
  l[[i]]$year <- years2[i]
}

dt <- rbindlist(l)

# save raw dat
saveRDS(dt, 'ts-data/raw_data.RDS')

#dt <- readRDS('ts-data/raw_data.RDS')

# cleaning ------------------------------------------------

# restrict to jobs in metro area
options(tigris_class = 'sf')
counties <- c('Anoka', 'Hennepin', 'Ramsey', 'Carver', 'Washington', 'Scott', 'Sherburne', 'Wright', 'Dakota')
bs <- blocks(state = 'MN', county = counties, year = 2016)

dt$GEOID10 <- as.character(dt$w_geocode)
dt <- dt[GEOID10 %in% bs$GEOID10]

saveRDS(dt, 'ts-data/metro_area_jobs.RDS')
#dt <- readRDS('ts-data/metro_area_jobs.RDS')

# aggregate to block groups
# dt[, w_bg := substr(as.character(w_geocode), 1, 12)]
# dt[, h_bg := substr(as.character(h_geocode), 1, 12)]

od_counts <- dt[, .(tot_workers = sum(S000), wage_1250 = sum(SE01), wage_1250_3333 = sum(SE02),
                    wage_333 = sum(SE03), age_29 = sum(SA01), age_30_54 = sum(SA02), 
                    age_55 = sum(SA03), ind_goods = sum(SI01), ind_trade = sum(SE02),
                    ind_other = sum(SI03)), by = c('w_geocode', 'h_geocode', 'year')]
saveRDS(od_counts, 'ts-data/od_jobs.RDS')

# we can use this dt to look at where people are coming from
# let's create a simpler object to get total counts

tot_counts <- dt[, .(workers = sum(S000)), by = c('w_geocode', 'year')][order(-workers)]
saveRDS(tot_counts, 'ts-data/tot_jobs.RDS')
