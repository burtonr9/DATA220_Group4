# scripts/01_extract.R -- P5: read every source file and keep an untouched copy.
# Reads: data/raw/        Writes: data/interim/<source>_raw.csv
source("config.R")
source("R/load_functions.R")
make_folders()
log_msg("01_extract: start")

# =============================================================================
# TASK P5 -- for every source: read its file, then save an untouched copy
# -----------------------------------------------------------------------------
# Pick the reading function by what the source is (your profile told you):
#   one CSV file              read_raw_csv(SOURCES$<name>$file)
#   a folder of CSV files     read_many_csv(SOURCES$<name>$file)
#   Excel, JSON (an API sample) or TSV     read_any_file(SOURCES$<name>$file)
# then save it:               save_csv(<data>, "data/interim/<name>_raw.csv")
# Example (a folder of monthly CSV files):
#   sales_raw <- read_many_csv(SOURCES$sales$file)
#   save_csv(sales_raw, "data/interim/sales_raw.csv")
# =============================================================================

# Both sources are folders of JSON answers, one game per file. read_any_file() cannot
# read them (each file is one object, not a list of rows; player counts sit inside
# "response"), so read_record_folder() in R/functions_read.R reads every file in the
# folder into one row and adds source_file, the file each row came from.

steamspy_games_raw <- read_record_folder(SOURCES$steamspy_games$file)   # folder of SteamSpy JSON
save_csv(steamspy_games_raw, "data/interim/steamspy_games_raw.csv")

player_counts_raw <- read_record_folder(SOURCES$player_counts$file)     # folder of Steam JSON
save_csv(player_counts_raw, "data/interim/player_counts_raw.csv")


log_msg("01_extract: done")
