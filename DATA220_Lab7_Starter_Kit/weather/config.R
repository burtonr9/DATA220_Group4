# config.R -- the settings and decisions of the weather pipeline, in one place.
# The scripts read these values, so changing a decision means editing ONE line here.

# The analysis question: do people use the river-valley trails less on cold or snowy days?

# ---- the database --------------------------------------------------------------------
DB_PATH <- "data/db/weather.sqlite"            # built by scripts/05_load_db.R

# ---- decisions -----------------------------------------------------------------------
# DECISION: the weather files name stations by climate ID; we use short station codes.
STATION_CODES <- c("CLASS-A01" = "EDM-A", "CLASS-B02" = "EDM-B")

# DECISION: trail use is compared with ONE station (EDM-A), so each day has one weather row.
ANALYSIS_STATION <- "EDM-A"

# DECISION: a "snow day" has at least 5 cm of new snow (edited from 2).
SNOW_DAY_CM <- 5
