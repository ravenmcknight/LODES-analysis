# Goal: gather and clean LODES data 

library(data.table)
library(tigris)
library(sf)
library(dplyr)

# download LODES files ------------------------------------
years <- c('2002', '2003', '2004', '2005', '2006', '2007', '2008', '2009', '2010', '2011', '2012', '2013', '2014', '2015', '2016', '2017')

urls <- c()
for (y in years){
  url <- paste0('https://lehd.ces.census.gov/data/lodes/LODES7/mn/od/mn_od_aux_JT00_', y, '.csv.gz')
  urls <- rbind(urls, url)
}

for (i in 1:length(urls)){
  dest <- paste0('data/', years[i], '.csv.gz')
  download.file(urls[i, ], dest)
}

# read files ----------------------------------------------
files <- list.files(path = 'data/')
l <- lapply(paste0('data/', files), fread)  # this should be more elegant

for (i in 1:length(l)){
  print(i)
  l[[i]]$year <- years[i]
}

dt <- rbindlist(l)

# save raw dat
saveRDS(dt, 'data/raw_data.RDS')


# cleaning ------------------------------------------------

# restrict to metro area
options(tigris_class = 'sf')
counties <- c('Anoka', 'Hennepin', 'Ramsey', 'Carver', 'Washington', 'Scott', 'Sherburne', 'Wright', 'Dakota')
bs <- blocks(state = 'MN', county = counties, year = 2016)

dt$GEOID10 <- as.character(dt$w_geocode)
dt_sf <- merge(bs, dt, by = 'GEOID10')

# just dt zone
# near target field
tf <- dt_sf %>% 
  filter(w_geocode == '270531261003001')

tf
