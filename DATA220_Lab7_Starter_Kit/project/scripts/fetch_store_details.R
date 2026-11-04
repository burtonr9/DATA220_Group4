# scripts/fetch_store_details.R -- freeze the game list, then save Steam's store details
# for every game on it, each answer exactly as received, in data/raw/.
# Run it from the project folder (open project.Rproj, then source("scripts/fetch_store_details.R")).
# Not numbered, so run_all.R skips it. Needs: install.packages("httr2")
#
# Safe to run again: steam_save() never overwrites a file that is already there, so a second
# run only fetches the games that are still missing (e.g. after a network error).
#
# Writes:
#   data/raw/most_played.json                  the Most Played chart -- the FROZEN game list
#   data/raw/store_details/store_<appid>.json  one store answer per game

source("config.R")
source("R/load_functions.R")
source("R/functions_steam.R")
make_folders()
log_msg("fetch_store_details: start")

# DECISION: settings for this pull (move them into config.R when the team agrees)
N_GAMES          <- 100                   # the whole chart: the top 100 snapshot
COUNTRY          <- "ca"                  # store prices in Canadian dollars
PAUSE_SECONDS    <- 1.5                   # store addresses allow ~200 requests per 5 minutes
MOST_PLAYED_URL  <- "https://api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/"
APPDETAILS_URL   <- "https://store.steampowered.com/api/appdetails"
MOST_PLAYED_FILE <- "data/raw/most_played.json"
STORE_FOLDER     <- "data/raw/store_details"

# 1. The Most Played chart. The FIRST file saved is the frozen list; later runs keep it.
steam_save(MOST_PLAYED_URL, dest = MOST_PLAYED_FILE)
appids <- head(frozen_appids(MOST_PLAYED_FILE), N_GAMES)
log_msg("frozen list: ", length(appids), " games")

# 2. Store details, one request per game.
failed <- character(0)
for (id in appids) {
  dest <- file.path(STORE_FOLDER, paste0("store_", id, ".json"))
  if (file.exists(dest)) next                                  # already saved: skip, no request
  ok <- tryCatch({
    steam_save(APPDETAILS_URL, list(appids = id, cc = COUNTRY), dest = dest)
    TRUE
  }, error = function(e) {
    log_msg("FAILED ", id, ": ", conditionMessage(e))
    FALSE
  })
  # CHECK: the answer must be JSON, not a web page (the reviews address once sent HTML).
  if (ok && !startsWith(trimws(readLines(dest, n = 1, warn = FALSE)), "{")) {
    file.remove(dest)
    log_msg("FAILED ", id, ": answer was not JSON -- file removed")
    ok <- FALSE
  }
  if (!ok) failed <- c(failed, id)
  Sys.sleep(PAUSE_SECONDS)
}

# 3. Summary: which games have a file, and which do not.
saved <- sub("^store_([0-9]+)\\.json$", "\\1", list.files(STORE_FOLDER, pattern = "^store_[0-9]+\\.json$"))
log_msg("store details saved for ", sum(appids %in% saved), " of ", length(appids), " games")
if (length(failed) > 0) log_msg("not saved (run the script again to retry): ", paste(failed, collapse = ", "))
log_msg("fetch_store_details: done")
