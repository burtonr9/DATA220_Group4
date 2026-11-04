# scripts/fetch_samples.R -- P2: save one sample answer from every Steam source into data/raw/.
# Run it ONCE, from the project folder (open project.Rproj, then source("scripts/fetch_samples.R"),
# or in a terminal: Rscript scripts/fetch_samples.R). It is not numbered, so run_all.R skips it.
# Needs: install.packages("httr2")
#
# It never overwrites a file that is already there, so running it again is safe.
# most_played.json is the FROZEN game list: the first one saved is the project's top 100.
# At the end it runs one poll (scripts/poll_players.R) so players/ and prices/ get their
# first files too.
source("config.R")
source("R/load_functions.R")
source("R/functions_steam.R")
make_folders()
log_msg("fetch_samples: start")

# 1. Most Played chart -- the frozen list of games
steam_save(STEAM$most_played_url, dest = SOURCES$most_played$file)
Sys.sleep(1)

# 2. Store details for one game (the full 100-game pull is in 01_extract.R at M2)
steam_save(STEAM$appdetails_url, list(appids = STEAM$sample_appid, cc = STEAM$country),
           dest = SOURCES$store_details$file)
Sys.sleep(1.5)

# 3. Global achievement percentages for one game
steam_save(STEAM$achievements_url, list(gameid = STEAM$sample_achievements_appid),
           dest = SOURCES$achievements$file)
Sys.sleep(1)

# 4. Review totals for one game -- num_per_page = 0: totals only, no review text, no reviewer IDs
steam_save(paste0(STEAM$reviews_url, STEAM$sample_appid),
           list(json = 1, language = "all", purchase_type = "all", num_per_page = 0),
           dest = SOURCES$reviews$file)

log_msg("fetch_samples: ", length(frozen_appids()), " games in the frozen list")

# 5. The first poll: current players for every game, and today's prices
source("scripts/poll_players.R")
log_msg("fetch_samples: done -- now run scripts/00_inspect_sources.R")
