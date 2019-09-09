# Goal: gather and clean LODES data 

library(data.table)

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
