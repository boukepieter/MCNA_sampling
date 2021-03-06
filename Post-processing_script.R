library(rJava)
library(xlsx)
library(sp)
library(rgdal)
library(raster)
library(dismo)
library(plotKML)
library(rgeos)
library(dplyr)

source("functions.R")
WGS84 <- crs("+init=epsg:4326")
UTM38N <- crs("+init=epsg:32638")

output_folder <- "output/20190619_final_sampling_new_shapes"

##### Stratification #####
# IAU shapes:
stratification <- readOGR("input/irq_admbnda_adm3_cso_20190603.shp","irq_admbnda_adm3_cso_20190603")

# Generating ID's
results <- c("script_Host","script_IDP_out_of_camp","script_Returnee")
h_samples <- read.csv(sprintf("%s/sampling_frame_%s.csv",output_folder,results[1]), stringsAsFactors = F)
idp_samples <- read.csv(sprintf("%s/sampling_frame_%s.csv",output_folder,results[2]), stringsAsFactors = F)
r_samples <- read.csv(sprintf("%s/sampling_frame_%s.csv",output_folder,results[3]), stringsAsFactors = F)
names(r_samples) <- sub("Location_name","Location.Name",names(r_samples))
combined_sample <- rbind(h_samples[,c("Governorate", "strata","psu","Location.Name")],
                         idp_samples[,c("Governorate", "strata", "psu","Location.Name")],
                         r_samples[,c("Governorate", "strata", "psu","Location.Name")])

tab <- table(combined_sample$psu)
psu <- data.frame(psu = names(tab), n = as.vector(tab))
psu$new_ID <- sprintf("%04d",seq(1,nrow(psu)))
psu$governorate <- tolower(combined_sample$Governorate[match(psu$psu,combined_sample$psu)])
psu$district <- to_alphanumeric_lowercase(combined_sample$strata[match(psu$psu,combined_sample$psu)])
psu$name <- combined_sample$Location.Name[match(psu$psu,combined_sample$psu)]
psu$label <- sprintf("%s (%s)", psu$new_ID, psu$name)
psu$new_ID <- sprintf("cluster_location_id_%04d",seq(1,nrow(psu)))

h_samples$new_ID <- psu$new_ID[match(h_samples$psu,psu$psu)]
idp_samples$new_ID <- psu$new_ID[match(idp_samples$psu,psu$psu)]
r_samples$new_ID <- psu$new_ID[match(r_samples$psu,psu$psu)]

combined_sample$new_ID <- psu$new_ID[match(combined_sample$psu,psu$psu)]

write.csv(psu, sprintf("%s/%s.csv",output_folder, "combined_sample_ids"),row.names = F)

districts <- read.csv("c:/Users/REACH-IRQ-GIS/Documents/201905 MCNA KoBo/districts_tolower.csv", 
                      stringsAsFactors=F, check.names=F)

##### Summarizing output #####
h <- read.csv(sprintf("%s/sampling_summary_%s.csv",output_folder,results[1]))
h$Stratification <- as.character(h$Stratification)
idp <- read.csv(sprintf("%s/sampling_summary_%s.csv",output_folder,results[2]))
idp$Stratification <- as.character(idp$Stratification)
r <- read.csv(sprintf("%s/sampling_summary_%s.csv",output_folder,results[3]))
r$Stratification <- as.character(r$Stratification)

# Summary 
dist_names <- unique(c(h$Stratification,idp$Stratification,r$Stratification))
df <- data.frame(District=dist_names, IDP_population=NA, IDP_surveys=NA, Returnees_population=NA,
                 Returnees_surveys=NA, Host_population=NA, Host_surveys=NA)
df$IDP_population[match(idp$Stratification,dist_names)] <- idp$Population
df$IDP_surveys[match(idp$Stratification,dist_names)] <- idp$X..surveys
df$Returnees_population[match(r$Stratification,dist_names)] <- r$Population
df$Returnees_surveys[match(r$Stratification,dist_names)] <- r$X..surveys
df$Host_population[match(h$Stratification,dist_names)] <- h$Population
df$Host_surveys[match(h$Stratification,dist_names)] <- h$X..surveys
df <- df[order(df$District),]
write.csv(df, sprintf("%s/Total_Summary_%s.csv",output_folder,output_folder),row.names=F)


### Sampling areas
military_areas <- readOGR("input/osm_landuse_military_iraq.shp","osm_landuse_military_iraq")
mil_UTM <- spTransform(military_areas,UTM38N)
mil_buffer <- gBuffer(mil_UTM, width=200,byid=T)
remove_ids <- c("w393892097", "w393892109", "w290490545", "w393892106", "w393892110", "w393892122", "w393892108")
mil_buffer_filt <- mil_buffer[!mil_buffer$full_id %in% remove_ids,]

idp_areas <- create.sample.area(idp_samples, mil_buffer_filt)
h_areas <- create.sample.area(h_samples, mil_buffer_filt)
r_areas <- create.sample.area(r_samples, mil_buffer_filt)

psu <- read.csv(sprintf("%s/%s.csv",output_folder, "combined_sample_ids"), stringsAsFactors = F)

idp_areas$label <- psu$label[match(idp_areas$psu,psu$psu)]
h_areas$label <- psu$label[match(h_areas$psu,psu$psu)]
r_areas$label <- psu$label[match(r_areas$psu,psu$psu)]

# filter host districts for the selected ones
host_districts <- read.csv("input/host_districts.csv")
h_areas <- h_areas[which(h_areas$strata %in% host_districts$district),] 

##### Sample to maps.me input #####
sample_points_host <- sample.to.kml(h_areas[1,], "Host", color="green", output_folder = output_folder)
for (i in 2: nrow(h_areas)){
  sample_points_host <- rbind(sample_points_host,
                              sample.to.kml(h_areas[i,], "Host", color="green", output_folder = output_folder))
}
save(sample_points_host, file=sprintf("%s/kml_files/sample_points_host.R",output_folder))

sample_points_idp <- sample.to.kml(idp_areas[1,], "IDP", color="blue", output_folder = output_folder)
for (i in 2: nrow(idp_areas)){
  sample_points_idp <- rbind(sample_points_idp,
                              sample.to.kml(idp_areas[i,], "IDP", color="blue", output_folder = output_folder))
}
save(sample_points_idp, file=sprintf("%s/kml_files/sample_points_idp.R",output_folder))

sample_points_r <- sample.to.kml(r_areas[1,], "Returnee", color="brown", output_folder = output_folder)
for (i in 2: nrow(r_areas)){
  sample_points_r <- rbind(sample_points_r,
                             sample.to.kml(r_areas[i,], "Returnee", color="brown", output_folder = output_folder))
}
save(sample_points_r, file=sprintf("%s/kml_files/sample_points_r.R",output_folder))









