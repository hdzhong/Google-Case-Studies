library(tidyverse)  #helps wrangle data
library(lubridate)  #helps wrangle date attributes
library(ggplot2)  #helps visualize data
library(skimr) # for quickly taking a look at the data

install.packages("directlabels")
install.packages("kableExtra")
install.packages("ggshadow")
install.packages("formattable")

library("ggshadow")
library("formattable")
library(kableExtra)
library(directlabels)

# Load all the csvs at once
myfiles = list.files(path="Data", pattern="*.csv", full.names=TRUE)
all_trips <- sapply(myfiles, read_csv, simplify=FALSE)
str(myfiles)
# I noticed that for some months start_station_id and end_station_id were doubles, and sometimes they were characters. I converted all of those types to characters to combine all the dataframes together

all_trips_v2 <- all_trips_v2 %>%
  map(~mutate(., start_station_id = as.character(start_station_id), end_station_id = as.character(end_station_id))) %>%
  bind_rows()

# Remove lat and long as this data was dropped beginning in 2020
all_trips_v2 <- all_trips_v2 %>%
  select(-c(start_lat, start_lng, end_lat, end_lng))

# Inspect the new table that has been created
colnames(all_trips_v2)  #List of column names
nrow(all_trips_v2)  #How many rows are in data frame?
dim(all_trips_v2)  #Dimensions of the data frame?
head(all_trips_v2)  #See the first 6 rows of data frame.  Also tail(qs_raw)
str(all_trips_v2)  #See list of columns and data types (numeric, character, etc)
summary(all_trips_v2)  #Statistical summary of data. Mainly for numerics

all_trips_v2$date <- as.Date(all_trips_v2$started_at) #The default format is yyyy-mm-dd
all_trips_v2$month <- format(as.Date(all_trips_v2$date), "%m")
all_trips_v2$day <- format(as.Date(all_trips_v2$date), "%d")
all_trips_v2$year <- format(as.Date(all_trips_v2$date), "%Y")
all_trips_v2$day_of_week <- format(as.Date(all_trips_v2$date), "%A")

# Add a "ride_length" calculation to all_trips (in seconds)
all_trips_v2$ride_length <- difftime(all_trips_v2$ended_at,all_trips_v2$started_at)

# Noticed that a lot of end station names were missing
# Created 3 separate data frames, one with complete data only, one with the trips that have no end station, and one with ALL trips
all_trips_missing_end <- filter(all_trips_v2, is.na(end_station_name))
all_trips_no_na <- filter(all_trips_v2, !is.na(end_station_name))

# Convert "ride_length" from Factor to numeric so we can run calculations on the data
is.factor(all_trips_v2$ride_length)
all_trips_v2$ride_length <- as.numeric(as.character(all_trips_v2$ride_length))
is.numeric(all_trips_v2$ride_length)

# Remove "bad" data
# The dataframe includes a few hundred entries when bikes were taken out of docks and checked for quality by Divvy or ride_length was negative
# We will create a new version of the dataframe (v2) since data is being removed
# https://www.datasciencemadesimple.com/delete-or-drop-rows-in-r-with-conditions-2/
all_trips_v2 <- all_trips_v2[!(all_trips_v2$start_station_name == "HQ QR" | all_trips_v2$ride_length<0),]


all_trips_v2 <- filter(all_trips_v2, !is.na(ride_length))

# You can condense the four lines above to one line using summary() on the specific attribute

summary(all_trips_v2$ride_length)

# Compare members and casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = mean)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = median)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = max)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = min)

# See the average ride time by each day for members vs casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual + all_trips_v2$day_of_week, FUN = mean)

# Notice that the days of the week are out of order. Let's fix that.
all_trips_v2$day_of_week <- ordered(all_trips_v2$day_of_week, levels=c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))

# Now, let's run the average ride time by each day for members vs casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual + all_trips_v2$day_of_week, FUN = mean)

# analyze ridership data by type and weekday
all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%  #creates weekday field using wday()
  group_by(member_casual, weekday) %>%  #groups by usertype and weekday
  summarise(number_of_rides = n()                            #calculates the number of rides and average duration
            ,average_duration = mean(ride_length)) %>%         # calculates the average duration
  arrange(member_casual, weekday)                                # sorts


# Let's visualize the number of rides by rider type
all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, weekday) %>%
  summarise(number_of_rides = n()
            ,average_duration = mean(ride_length)) %>%
  arrange(member_casual, weekday)  %>%
  ggplot(aes(x = weekday, y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge")

# Let's create a visualization for average duration
all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, weekday) %>%
  summarise(number_of_rides = n()
            ,average_duration = mean(ride_length)) %>%
  arrange(member_casual, weekday)  %>%
  ggplot(aes(x = weekday, y = average_duration, fill = member_casual)) +
  geom_col(position = "dodge") +
  labs(title = "Number of Rides per Weekday", x = "# of Rides", y = "Weekday")

# Most popular starting points (members + casual top 5 for each)
all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, start_station_name) %>%
  summarise(counts = n()) %>%
  top_n(5) %>%
  ggplot(aes(x = start_station_name, y = counts, fill = member_casual)) +
  geom_col(position = "dodge")

# Most popular starting points (casuals)
all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  filter(member_casual == "casual") %>%
  group_by(start_station_name) %>%
  summarise(counts = n()) %>%
  top_n(10) %>%
  ggplot(aes(x = start_station_name, y = counts)) +
  geom_col(position = "dodge") + theme(axis.text.x = element_text(angle = 45, vjust = 0.65))

# Most popular starting points (members)

all_trips_v2 %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  filter(member_casual == "member") %>%
  group_by(start_station_name) %>%
  summarise(counts = n()) %>%
  top_n(10) %>%
  ggplot(aes(x = start_station_name, y = counts)) +
  geom_col(position = "dodge") + theme(axis.text.x = element_text(angle = 45, vjust = 0.65))

# Table borrowed from another project, shows number of rides using multiple lines

order_week <- c('Sunday', 'Monday', 'Tuesday', 'Wednesday','Thursday','Friday','Saturday')

table9 <- all_trips_v2 %>%
  group_by( day_of_week,member_casual, month, year) %>%
  dplyr::summarise(totals=n(), .groups = 'drop')


table9$month_name <- recode(table9$month,
                            "01" = "Jan",
                            "02" = "Feb",
                            "03" = "Mar",
                            "04" = "Apr",
                            "05" = "May",
                            "06" = "Jun",
                            "07" = "Jul",
                            "08" = "Aug",
                            "09" = "Sep",
                            "10" = "Oct",
                            "11" = "Nov",
                            "12" = "Dec")


ggplot(table9, aes(x = factor(day_of_week, level = order_week), y = totals, group = month, colour = month)) +
  geom_line() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)) +
  facet_wrap(~member_casual) +
  scale_colour_discrete(guide = 'none') +
  scale_x_discrete(expand=c(0, 1)) +
  geom_dl(aes(label = month_name), method = list('last.bumpup', cex = 0.6, hjust = -0.2)) +
  labs( x = "Day of the week", y = "Number of Rides",
        title ="Number of rides per day of the week,month and member type") +

  geom_rect(data = data.frame(member_casual = "casual"), aes( xmin = "Sunday", xmax = "Saturday", ymin = 0, ymax = 10000), linejoin = "mitre",alpha = 0.2, fill="blue", inherit.aes = FALSE)

# Calender style plot (avg # of rides per day of the week and member type)

table6 <- all_trips_v2 %>%
  group_by(member_casual, year, month, day_of_week) %>%
  dplyr::summarise(number_of_rides = n() ,average_duration = mean(ride_length), .groups = 'drop')

ggplot(table6,aes(x = factor(day_of_week, level = order_week), y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)) +
  labs( x = "Day of the week", y = "Average Duration",
        title ="Average Number of rides per day of the week and Member Type", fill = "Member Type")  +
  facet_wrap(~year+month)

# Calender style plot (avg duration per day of the week and member type)

table7 <- all_trips_v2 %>%
  group_by(member_casual, year, month, day_of_week) %>%
  dplyr::summarise(number_of_rides = n() ,average_duration = mean(ride_length), .groups = 'drop')

ggplot(table7,aes(x = factor(day_of_week, level = order_week), y = average_duration, fill = member_casual)) +
  geom_col(position = "dodge") +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)) +
  labs( x = "Day of the week", y = "Average Duration",
        title ="Average Number of rides per day of the week and Member Type", fill = "Member Type")  +
  facet_wrap(~year+month)

# Table with rides grouped by length

# Assign ride length groups with context
all_trips_v2$group_length <- dplyr::case_when(all_trips_v2$ride_length <900 ~ "Less 15 minutes",
                                           all_trips_v2$ride_length <3600 ~"Less 1 hour",
                                           all_trips_v2$ride_length <7200 ~"Less 2 hour",
                                           all_trips_v2$ride_length <28800 ~"Less 8 hour",
                                           all_trips_v2$ride_length <86400 ~"Less 1 day",
                                           all_trips_v2$ride_length >=86400 ~"More than 1 day")

# Preliminary count of all trips grouped by year and months
divvy_count <- all_trips_v2 %>%
  group_by(year,month) %>%
  dplyr::summarise(totals=n())

table3 <- all_trips_v2 %>%
  group_by( group_length,member_casual) %>%
  dplyr::summarise(totals=n(), .groups = 'drop') %>%
  pivot_wider(names_from = member_casual, values_from = totals) %>%
  mutate (Total =casual+member)%>%
  mutate (casual_perc = (casual/ nrow(all_trips_v2)))%>%
  mutate (member_perc = (member/ nrow(all_trips_v2)))

func <- function(z) if (is.numeric(z)) sum(z) else ''
sumrowtable3 <- as.data.frame(lapply(table3, func))
sumrowtable3[1] <- "Total"


table3$casual_perc <- percent(table3$casual_perc)
table3$member_perc <- percent(table3$member_perc)
table3$total_perc <- percent(table3$total_perc)


table3 <- data.frame(table3)

table3total <- rbind(table3, sumrowtable3)

kbl(table3total, escape = F,caption = "Number of rides group by length",
    col.names = c("Group","Casual","Member","Total","Casual","Member")) %>%
  row_spec(dim(table3total)[1], bold = T) %>% # format last row
  column_spec(1, bold = T)  %>%
  kable_material(c("striped", "hover", "responsive"), full_width = F) %>%
  add_header_above(c(" "=1, "Rows" = 3, "Percentage" = 2))

# Create a csv file that we will visualize in Excel, Tableau, or my presentation software
counts <- aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual + all_trips_v2$day_of_week, FUN = mean)

write.csv(counts, file = 'avg_ride_length.csv')
write.csv(all_trips_v2, file = 'all_trips.csv')
