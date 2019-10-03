## Goal: Parse LEHD Origin-Destination Employment data for use in Urban GIS

# this document is fully reproducible - anyone with R can run this and get the data we're using for the project

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

# this section downloads all of the LODES files we want from the website

# here, we download data from 2010-2017 for people who live & work in Minnesota

years <- c('2010', '2011', '2012', '2013', '2014', '2015', '2016', '2017')

urls <- c()
for (y in years){
  url <- paste0('https://lehd.ces.census.gov/data/lodes/LODES7/mn/od/mn_od_main_JT00_', y, '.csv.gz') # live in state
  urls <- rbind(urls, url)
}

for (i in 1:length(urls)){
  dest <- paste0('data/gis-data/raw-', years[i], '.csv.gz')
  download.file(urls[i, ], dest)
}

# read files --------------------------
files <- list.files(path = 'data/gis-data/')
l <- lapply(paste0('data/gis-data/', files), fread)

for (i in 1:length(l)){
  l[[i]]$year <- years[i]
}

# saving it as one large object now so I can clean it all at once
dt <- rbindlist(l)

# save raw data since it's so big so we don't have to run this again
# you can also save as a csv or xlsx 
saveRDS(dt, 'data/gis-data/raw_data.RDS')

## cleaning ------------------------------------------------

# here, we'll use the tigris package to get census block groups

options(tigris_class = 'sf')
counties <- c('Anoka', 'Hennepin', 'Ramsey', 'Carver', 'Washington', 'Scott', 'Dakota')
bs <- blocks(state = 'MN', county = counties, year = 2016)

# this bit restricts to jobs in the 7 county metro (we'll focus mostly on Hennepin and Ramsey)
dt$GEOID10 <- as.character(dt$w_geocode)
dt <- dt[GEOID10 %in% bs$GEOID10] # this is data.table instead of dplyr but could also be done with %>% filter()

# this step also takes a long time so save here
saveRDS(dt, 'data/metro_area_jobs.RDS')

dt <- readRDS('data/metro_area_jobs.RDS')
setDT(dt)

# aggregate to block groups using data.table
dt[, w_bg := substr(as.character(w_geocode), 1, 12)]
dt[, h_bg := substr(as.character(h_geocode), 1, 12)]

# now we sum the columns by home block group, work block group and year

od_counts <- dt[, .(tot_workers = sum(S000), wage_1250 = sum(SE01), wage_1250_3333 = sum(SE02),
                    wage_333 = sum(SE03), age_29 = sum(SA01), age_30_54 = sum(SA02), 
                    age_55 = sum(SA03), ind_goods = sum(SI01), ind_trade = sum(SE02),
                    ind_other = sum(SI03)), by = c('w_bg', 'h_bg', 'year')]

saveRDS(od_counts, 'data/od_jobs.RDS')

# so od_jobs has counts of origin and destination for each block group in the metro area by year

# Export lots of csvs -------------------------------------

# export 1 csv per year (we can do spatial restrictions in GIS
# just change the date if you re-run

for (y in years){
  fwrite(od_counts[year == y], paste0('data/gis-data/od-jobs_mn_bgs_', y, '_092719_rm.csv'))
}


## get RAC data -------------------------------------------

# residence area characteristics
# segment = S000 are all workers, SA01 is workers under 29 (likely to be young parents)
# type = JT00 is all jobs
# year = most recent year

rac_urls <- c('https://lehd.ces.census.gov/data/lodes/LODES7/mn/rac/mn_rac_S000_JT00_2017.csv.gz',
              'https://lehd.ces.census.gov/data/lodes/LODES7/mn/rac/mn_rac_SA01_JT00_2017.csv.gz')

for(i in 1:length(rac_urls)){
  download.file(rac_urls[i], paste0('rac-data/mn_rac_2017_', i, '.csv.gz'))
}

rac_files <- list.files(path = 'rac-data/')
l <- lapply(paste0('rac-data/', rac_files), fread)

l[[1]]$type <- 'S000'
l[[2]]$type <- 'SA01'

colnames(l[[1]]) <- c('h_geocode', 'tot_jobs', 'age_29', 'age_30_54', 'age_55',
                      'wage_1250', 'wage_1250_3333', 'wage_3333', 'ag', 'mining',
                      'utils', 'construction', 'manuf', 'whole_trade', 'ret_trade',
                      'transp', 'info', 'finance', 'real_estate', 'prof_serv', 
                      'manage', 'admin', 'educ', 'health', 'arts', 'ac_food', 
                      'other', 'pub_admin', 'white_alone', 'black', 'amind', 
                      'asian', 'native', 'two_or_more', 'not_hisp', 'hisp', 
                      'less_than_hs', 'hs', 'some_college', 'degree', 'male', 'female', 
                      'createdate', 'type')

colnames(l[[2]]) <- c('h_geocode', 'tot_jobs', 'age_29', 'age_30_54', 'age_55',
                      'wage_1250', 'wage_1250_3333', 'wage_3333', 'ag', 'mining',
                      'utils', 'construction', 'manuf', 'whole_trade', 'ret_trade',
                      'transp', 'info', 'finance', 'real_estate', 'prof_serv', 
                      'manage', 'admin', 'educ', 'health', 'arts', 'ac_food', 
                      'other', 'pub_admin', 'white_alone', 'black', 'amind', 
                      'asian', 'native', 'two_or_more', 'not_hisp', 'hisp', 
                      'less_than_hs', 'hs', 'some_college', 'degree', 'male', 'female', 
                      'createdate', 'type')


fwrite(l[[1]], 'rac-data/mn_rac_S000_JT00_2017.csv')
fwrite(l[[2]], 'rac-data/mn_rac_SA01_JT00_2017.csv')
