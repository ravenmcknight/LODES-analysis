# data & packages -------------------------------

library(data.table)
library(ggplot2)
library(tigris)
library(sf)
library(leaflet)
library(dplyr)
library(htmltools)

tot <- readRDS('data/tot_jobs.RDS')

tot_ys <- tot[, .(workers = sum(workers)), by = year]

ggplot(tot_ys, aes(x=year, y=workers, group = 1)) +
  geom_line() +
  geom_point(color = 'red') +
  theme_minimal() +
  labs(title = 'total jobs in 9 county metro area') +
  theme(plot.title = element_text(hjust = 0.5))

# general ts is about what i expected

# block groups ----------------------------------
options(tigris_class = 'sf')
counties <- c('Anoka', 'Carver', 'Dakota', 'Hennepin', 'Ramsey', 'Scott', 'Washington')
bgs <- block_groups('MN', counties, year = 2016)

bgs <- st_transform(bgs, 4326)

# total jobs in 2017 ------------------
tot_17 <- tot[year == 2017][, .(workers = sum(workers)), by = w_bg]

bg_tot_17 <- left_join(bgs, tot_17, by = c('GEOID' = 'w_bg'))

emp2017pal <- colorNumeric(palette = 'YlGnBu', domain = log(bg_tot_17$workers))
emp2017labs <- sprintf(
  "<strong> %s </strong> jobs in 2017",
  bg_tot_17$workers
) %>% lapply(htmltools::HTML)

leaflet(bg_tot_17) %>% addTiles() %>%
  addPolygons(weight = 1, color = 'grey', fillColor = ~emp2017pal(log(workers)), 
              fillOpacity = 0.7, label = emp2017labs)

# change 2010-2017
tot_10 <- tot[year == 2010][, .(workers10 = sum(workers)), by = w_bg]
change_10_17 <- tot_10[tot_17, on = 'w_bg']
change_10_17[, change := workers - workers10]
change_10_17[, logchange := sign(change)*log(abs(change))]

change_10_17 <- left_join(bgs, change_10_17, by = c('GEOID' = 'w_bg'))

change1017pal <- colorNumeric(palette = 'RdBu', domain = c(-10.1, 10.1))
change1017labs <- sprintf(
  "Block group ID: %s <br> Change in jobs 2010-2017: <strong> %s </strong>",
  change_10_17$GEOID, change_10_17$change
) %>% lapply(htmltools::HTML)

leaflet(change_10_17) %>% addTiles() %>%
  addPolygons(weight = 1, color = 'grey', fillColor = ~change1017pal(logchange),
              fillOpacity = 0.7, label = change1017labs)
# interesting that the biggest increase and biggest decrease are next door 
# wonder if some things were just re-assigned

summary(change_10_17$change)

# visualizing origins -------------------------------------
ods <- readRDS('data/od_jobs.RDS')
# test with one bg
dtw <- ods[year == 2017 & w_bg == '270531044002']

empcounties <- c('Sherburne', 'Wright', 'Chisago', 'Isanti', 'Le Sueur', 'Mille Lacs', 'Sibley County')
wicounties <- c('St. Croix', 'Pierce')

empbg <- block_groups('MN', county = empcounties, year = 2016)
wibg <- block_groups('WI', county = wicounties, year = 2016)

empbg <- st_transform(empbg, 4326)
wibg <- st_transform(wibg, 4326)

allbg <- rbind_tigris(empbg, wibg, bgs)
  
dtw_origins <- left_join(allbg, dtw, by = c('GEOID' = 'h_bg'))


originpal <- colorNumeric(palette = 'YlGnBu', domain = c(0, 5.4), na.color = 'transparent')
originlab <- sprintf(
  "<strong> %s </strong> workers in 2017",
  dtw_origins$workers
) %>% lapply(htmltools::HTML)

leaflet(dtw_origins) %>% addTiles() %>%
  addPolygons(weight = 1, color = 'grey', fillColor = ~originpal(log(workers)),
              fillOpacity = 0.8, label = originlab)

# next step -- back up and get bgs for the whole dtz