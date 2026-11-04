# scripts/poll_players.R -- one poll: how many people are playing each game right now,
# plus today's prices (once a day). Run it every 3 hours until November 30 (Windows Task
# Scheduler -- see the README note in PROPOSAL.md). Not numbered, so run_all.R skips it.
# Needs: install.packages("httr2"), and data/raw/most_played.json (scripts/fetch_samples.R).
#
# Writes (never overwrites):
#   data/raw/players/players_<UTC time>.csv   one row per game: appid, pulled_at_utc,
#                                             http_status, body (Steam's answer, exactly as received)
#   data/raw/prices/prices_<UTC date>_<n>.json  Steam's answer for 50 games at a time, as received
# A poll that fails leaves no file: missed polls stay missing; nothing is filled in later.

# When Task Scheduler starts Rscript, the working folder is not the project folder:
# move to the folder above scripts/ so every relative path below works.
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(script_arg) == 1) setwd(dirname(dirname(normalizePath(sub("^--file=", "", script_arg)))))

source("config.R")
source("R/load_functions.R")
source("R/functions_steam.R")
make_folders()

appids <- frozen_appids(SOURCES$most_played$file)
now <- as.POSIXct(Sys.time(), tz = "UTC")
stamp <- format(now, "%Y-%m-%dT%H%MZ", tz = "UTC")
log_msg("poll ", stamp, ": start, ", length(appids), " games")

# ---- current players: one request per game, 1 s apart (~100 requests per poll)
rows <- list()
for (id in appids) {
  res <- tryCatch(steam_get(STEAM$players_url, list(appid = id)),
                  error = function(e) list(status = NA_integer_, raw = raw(0)))
  rows[[id]] <- data.frame(appid = id,
                           pulled_at_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
                           http_status = res$status,
                           body = rawToChar(res$raw))
  Sys.sleep(1)
}
poll <- bind_rows(rows)
if (all(is.na(poll$http_status))) stop("poll ", stamp, ": Steam could not be reached -- no file saved")
save_csv(poll, file.path(SOURCES$players$file, paste0("players_", stamp, ".csv")))
log_msg("poll ", stamp, ": ", sum(poll$http_status == 200, na.rm = TRUE), " of ", nrow(poll), " answered 200")

# ---- prices: once per UTC day; Steam allows many appids per request only with
#      filters=price_overview, so 50 games per request
today <- format(now, "%Y-%m-%d", tz = "UTC")
if (length(list.files(SOURCES$prices$file, pattern = paste0("^prices_", today))) == 0) {
  groups <- split(appids, ceiling(seq_along(appids) / 50))
  for (n in seq_along(groups)) {
    steam_save(STEAM$appdetails_url,
               list(appids = paste(groups[[n]], collapse = ","), cc = STEAM$country,
                    filters = "price_overview"),
               dest = file.path(SOURCES$prices$file, paste0("prices_", today, "_", n, ".json")))
    Sys.sleep(1.5)
  }
}
log_msg("poll ", stamp, ": done")
