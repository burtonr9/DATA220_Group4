# scripts/02_clean.R -- P6: your first cleaning steps, one decision at a time.
# Reads: data/interim/<source>_raw.csv      Writes: data/interim/<source>_clean.csv
# Lab 8 continues from here (more cleaning, joins, checks, the database, queries).
source("config.R")
source("R/load_functions.R")
log_msg("02_clean: start")

# =============================================================================
# TASK P6 -- clean ONE table (more if you have time), step by step
# -----------------------------------------------------------------------------
# For every step, write the three lines, then the code (see weather/scripts/02_clean.R):
#   - FOUND:    what an inspect function showed you          (the problem)
#   - DECISION: which toolkit function you use, and WHY it is the right fix
#   - CHECK:    how you know it worked (check_key(), find_text_variants() again, ...)
# End with check_key() on the key you planned in config.R, and save_csv().
# =============================================================================
# Example step (coffee-cart sales):
#   sales <- read_raw_csv("data/interim/sales_raw.csv") |> clean_names()
#   # FOUND:    find_text_variants(sales, "item") shows "Latte", "latte " and "LATTE".
#   # DECISION: standardize_text(case = "title"), because only spaces and capitals differ.
#   sales <- mutate(sales, item = standardize_text(item, case = "title"))
#   # CHECK:    find_text_variants(sales, "item") now finds nothing.

# =============================================================================
# Table 1: games  (from steamspy_games; planned key: appid)
# =============================================================================
games <- read_raw_csv("data/interim/steamspy_games_raw.csv") |> clean_names()

# --- Step 1: columns that are the same for every game ------------------------
# FOUND:    count_missing(games) shows score_rank empty in every row; count_values() shows
#           userscore, average_forever, average_2weeks, median_forever and median_2weeks
#           are "0" for every game (SteamSpy no longer publishes these).
# DECISION: drop them with select(), because a column with one value for every game
#           cannot answer any of our questions.
unused <- c("score_rank", "userscore", "average_forever", "average_2weeks",
            "median_forever", "median_2weeks")
print(count_missing(games))
print(count_values(games, "userscore"))
games <- select(games, -all_of(unused))
# CHECK:    none of the six columns is left.
stopifnot(!any(unused %in% names(games)))

# --- Step 2: numbers stored as text, prices in cents --------------------------
# FOUND:    the profile shows positive, negative, ccu, price, initialprice and discount
#           are numbers stored as text, and price is in US cents ("5999" = $59.99);
#           price, initialprice and discount are missing for 3 games.
# DECISION: to_number() on every number column; divide the two prices by 100 so they are
#           in dollars. Missing prices stay NA (unknown), not 0, because 0 means "free".
games <- mutate(games,
                across(c(appid, positive, negative, ccu, price, initialprice, discount), to_number),
                price = price / 100,
                initialprice = initialprice / 100)
# CHECK:    no price above $100 and no discount outside 0-100 %.
stopifnot(nrow(show_out_of_range(games, "price", 0, 100)) == 0,
          nrow(show_out_of_range(games, "discount", 0, 100)) == 0)

# --- Step 3: zeros that mean "SteamSpy has no data" ---------------------------
# FOUND:    show_out_of_range(games, "positive", 1, Inf) lists 6 of the 10 games
#           (Aion 2, Final Fantasy Resonance, Overwatch 2, The Finals, Zenless Zone Zero,
#           Call of Duty): positive = 0, negative = 0, ccu = 0 and owners "0 .. 20,000",
#           while Steam's own player_counts shows e.g. 60,170 people playing Overwatch 2.
#           These zeros mean SteamSpy has not tracked the game, not that nobody plays it.
# DECISION: add has_steamspy_data (any reviews at all) and set positive, negative, ccu and
#           owners to NA where it is FALSE, so medians and the review share (Q3) are not
#           pulled towards 0 by games SteamSpy does not know.
print(show_out_of_range(games, "positive", 1, Inf))
games <- mutate(games,
                has_steamspy_data = (positive + negative) > 0,
                across(c(positive, negative, ccu, owners), ~ if_else(has_steamspy_data, .x, NA)))
# CHECK:    every game without SteamSpy data now has NA reviews, and no game is left with 0.
stopifnot(all(is.na(games$positive[!games$has_steamspy_data])),
          !any(games$positive == 0, na.rm = TRUE))

# --- Step 4: owners is a text range -------------------------------------------
# FOUND:    count_values(games, "owners") shows ranges like "20,000,000 .. 50,000,000".
# DECISION: split into owners_low and owners_high with str_extract() and to_number()
#           (which removes the commas). SteamSpy only gives a range, so we keep both ends.
print(count_values(games, "owners"))
games <- mutate(games,
                owners_low  = to_number(str_extract(owners, "^[0-9,]+")),
                owners_high = to_number(str_extract(owners, "[0-9,]+$")))
# CHECK:    every range has a lower end below its upper end.
stopifnot(all(games$owners_low < games$owners_high, na.rm = TRUE))

# --- Step 5: missing and outdated game names ----------------------------------
# FOUND:    count_missing(games) shows name empty for 2 games (appid 3393110 from
#           spy_Aion_2.json, appid 4162040 from spy_Zenless_zone_zero.json), and
#           count_values(games, "name") lists Counter-Strike 2 under its old name
#           "Counter-Strike: Global Offensive".
# DECISION: game_label = the file name in lower case with standardize_text() (our own
#           label, also used to match player_counts below); fill a missing name from it,
#           and recode_values() the old Counter-Strike name. Names are for display only:
#           every join uses appid.
games <- mutate(games,
                game_label = standardize_text(str_remove_all(source_file, "^spy_|\\.json$"),
                                              case = "lower"),
                name = recode_values(name, c("Counter-Strike: Global Offensive" = "Counter-Strike 2")),
                name = coalesce(name, str_to_title(str_replace_all(game_label, "_", " "))))
# CHECK:    no name is missing, and the old name is gone.
stopifnot(sum(is.na(games$name)) == 0,
          !"Counter-Strike: Global Offensive" %in% games$name)

# --- Step 6: free or paid ------------------------------------------------------
# FOUND:    genre holds several values in one cell ("Action, Free To Play"); price is 0
#           for the two free games and missing for 3 games whose genre is also empty.
# DECISION: is_free = genre contains "Free To Play" (Steam's own label), because the price
#           alone cannot tell "free" from "unknown". It stays NA when genre is empty.
games <- mutate(games, is_free = str_detect(genre, "Free To Play"))
print(count_values(games, "is_free"))
# CHECK:    every game marked free has a price of 0 (or no price).
stopifnot(all(games$price[games$is_free %in% TRUE] == 0, na.rm = TRUE))

# --- Key and save ---------------------------------------------------------------
check_key(games, "appid", "games")
save_csv(games, "data/interim/steamspy_games_clean.csv")


# =============================================================================
# Table 2: player_counts  (planned key: appid + pulled_at_utc)
# =============================================================================
players <- read_raw_csv("data/interim/player_counts_raw.csv") |> clean_names()

# --- Step 1: no appid in the answer ---------------------------------------------
# FOUND:    the answers hold only player_count and result -- no appid. The file names are
#           the only link to a game, and they differ in capitals from the SteamSpy files:
#           players_Cyber_punK_2077.json but spy_Cyber_punk_2077.json.
# DECISION: build game_label the same way as in games (standardize_text(case = "lower")),
#           then look up appid from games with safe_left_join() on game_label.
players <- mutate(players,
                  game_label = standardize_text(str_remove_all(source_file, "^players_|\\.json$"),
                                                case = "lower"),
                  player_count = to_number(player_count))
players <- safe_left_join(players, select(games, game_label, appid), by = "game_label",
                          name = "player_counts -> games")
# CHECK:    every player count found its game.
stopifnot(nrow(find_unmatched(players, games, "game_label")) == 0, !any(is.na(players$appid)))

# --- Key and save ---------------------------------------------------------------
# The sample is a single poll, so appid alone is the key for now; pulled_at_utc is added
# in Lab 8 when the poll time is saved in the file name.
check_key(players, "appid", "player_counts")
save_csv(players, "data/interim/player_counts_clean.csv")


log_msg("02_clean: done")
