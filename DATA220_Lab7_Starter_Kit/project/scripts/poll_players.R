# scripts/poll_players.R -- ONE poll: how many people are playing each of the 100 games right
# now, plus today's store prices (on the first poll of each UTC day).
# Runs every 3 hours until November 30 from Windows Task Scheduler
# (set up once with scripts/setup_poll_task.ps1). Not numbered, so run_all.R skips it.
# To test by hand, from the project folder:   Rscript scripts/poll_players.R
# Needs: install.packages("httr2")
#
# Writes (never overwrites; every file is a raw answer, committed to Git):
#   data/raw/players/players_<UTC time>.csv   one row per game: poll_utc, appid, pulled_at_utc,
#                                             http_status, body (Steam's answer, exactly as received)
#   data/raw/prices/prices_<UTC date>.csv     one row per game, same columns: Steam's store
#                                             answer for price_overview, exactly as received
# A poll that cannot reach Steam at all leaves no file: missed polls stay missing; nothing is
# filled in later.

# When Task Scheduler starts Rscript, the working folder is not the project folder:
# move to the folder above scripts/ so every relative path below works.
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(script_arg) == 1) setwd(dirname(dirname(normalizePath(sub("^--file=", "", script_arg)))))

# Work in UTC: Git Bash passes a Windows time-zone name R does not know ("Alberta Standard
# Time"), and every time this script writes is UTC anyway.
Sys.setenv(TZ = "UTC")

source("config.R")
source("R/load_functions.R")
source("R/functions_steam.R")
make_folders()

# DECISION: settings for the polls (move them into config.R at M2)
PLAYERS_URL    <- "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/"
APPDETAILS_URL <- "https://store.steampowered.com/api/appdetails"
COUNTRY        <- "ca"                      # store prices in Canadian dollars
PLAYERS_FOLDER <- "data/raw/players"
PRICES_FOLDER  <- "data/raw/prices"
dir.create(PLAYERS_FOLDER, recursive = TRUE, showWarnings = FALSE)
dir.create(PRICES_FOLDER,  recursive = TRUE, showWarnings = FALSE)

appids   <- frozen_appids(SOURCES$most_played$file)    # the frozen top 100 (saved Nov 4)
now      <- Sys.time()
poll_utc <- format(now, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
stamp    <- format(now, "%Y-%m-%dT%H%MZ", tz = "UTC")
today    <- format(now, "%Y-%m-%d", tz = "UTC")
log_msg("poll ", stamp, ": start, ", length(appids), " games")

# One request per game; every answer is kept as received, whatever its status.
ask_each <- function(url, make_query, pause) {
  rows <- list()
  for (id in appids) {
    res <- tryCatch(steam_get(url, make_query(id)),
                    error = function(e) list(status = NA_integer_, raw = raw(0)))
    rows[[id]] <- data.frame(poll_utc      = poll_utc,
                             appid         = id,
                             pulled_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                             http_status   = res$status,
                             body          = rawToChar(res$raw))
    Sys.sleep(pause)
  }
  bind_rows(rows)
}

# ---- current players: ~100 requests, 1 s apart (~2 minutes) ------------------------------
players <- ask_each(PLAYERS_URL, function(id) list(appid = id), pause = 1)
if (all(is.na(players$http_status))) stop("poll ", stamp, ": Steam could not be reached -- no file saved")
save_csv(players, file.path(PLAYERS_FOLDER, paste0("players_", stamp, ".csv")))
log_msg("poll ", stamp, ": players -- ", sum(players$http_status == 200, na.rm = TRUE),
        " of ", nrow(players), " answered 200")

# ---- store prices: once per UTC day, ~100 requests, 1.5 s apart (~2.5 minutes) -------------
prices_file <- file.path(PRICES_FOLDER, paste0("prices_", today, ".csv"))
if (!file.exists(prices_file)) {
  prices <- ask_each(APPDETAILS_URL,
                     function(id) list(appids = id, cc = COUNTRY, filters = "price_overview"),
                     pause = 1.5)
  if (all(is.na(prices$http_status))) {
    log_msg("poll ", stamp, ": store could not be reached -- prices will be tried on the next poll")
  } else {
    save_csv(prices, prices_file)
    log_msg("poll ", stamp, ": prices -- ", sum(prices$http_status == 200, na.rm = TRUE),
            " of ", nrow(prices), " answered 200")
  }
}
log_msg("poll ", stamp, ": done")
