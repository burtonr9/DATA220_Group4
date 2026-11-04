# config.R -- YOUR project's data: the sources, what you found in them, and the tables
# you plan. Lab 7 starts it; Lab 8 builds on it. Write names exactly as in SUBMISSION.md.

PROJECT <- "What keeps steam's most-played games busy?"

# =============================================================================
# P1 -- Sources: one entry per data source
# -----------------------------------------------------------------------------
#   what   : one line -- what the data are
#   format : "csv", "several csv", "excel", "json", "api" or "other"
#   get    : "download" (a file from a portal or a person) or "api" (Lab 8 calls it)
#   link   : where it comes from: a web page, a portal, an API address
#   file   : the file or folder in data/raw/ -- for an API source, a saved SAMPLE
#            response (P2)
#   owner  : who looks after this source; several people: "Alex Example, Sam Example"
# Example (delete it and write your own):
#   sales = list(what = "Daily sales from the cart's till, one export per month",
#                format = "several csv", get = "download",
#                link = "emailed by Campus Food Services",
#                file = "data/raw/sales", owner = "Alex Example"),
# =============================================================================

SOURCES <- list(
  
  steamspy_games = list(
    what = "SteamSpy game details (name, developer, publisher, review counts, estimated owners, price, tags) for the 100 games in the frozen Most Played chart; 10 games saved as a sample",
    format = "json",
    get = "api",
    link = "https://steamspy.com/api.php?request=appdetails&appid=<appid>",
    file = "data/raw/steamspy_games",
    owner = "Riwaz Silwal"
  ),
  
  player_counts = list(
    what = "Steam's current player count for each of the 100 games, polled every 3 hours; 10 games saved as a sample",
    format = "json",
    get = "api",
    link = "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=<appid>",
    file = "data/raw/player_counts",
    owner = "Riwaz Silwal"
  ),

  most_played = list(
    what = "Steam's Most Played chart: the top 100 games by concurrent players (rank, appid, last week's rank, peak). The first file saved is the frozen game list.",
    format = "json",
    get = "api",
    link = "https://api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/",
    file = "data/raw/most_played.json",
    owner = "Mark Buban"
  ),

  store_details = list(
    what = "Steam store record for each of the 100 games: type, name, free or paid, price and discount (CAD), genres, release date, Metacritic, recommendations, achievement count",
    format = "json",
    get = "api",
    link = "https://store.steampowered.com/api/appdetails?appids=<appid>&cc=ca",
    file = "data/raw/store_details",
    owner = "Mark Buban"
  )
  
)

# =============================================================================
# P3 -- What you found (run scripts/00_inspect_sources.R first)
# -----------------------------------------------------------------------------
# One "# FOUND:" line per problem you will have to clean or decide -- at least two:
#   FOUND (example): sales Date is in 2 formats (2026-10-01, 10/15/2026) -> parse_dates_mixed()
#
# =============================================================================
#FOUND: steamspy_games:
# - Each JSON file contains Steam game metadata, including appid,
#   name, developer, publisher, pricing, ownership estimates,
#   player activity, languages, genre and tags.
# - appid is a numeric game identifier.
# - Some metadata fields may be empty or missing, depending on the game.
# - score_rank is empty in the inspected sample.
# - Pricing and descriptive fields may be missing for some games.
# - owners is stored as text containing estimated ownership ranges.
# - tags may contain multiple values and need consistent handling.
# - Each file represents one game, so appid can identify the game.

#FOUND:
# - Each JSON file contains a nested response object.
# - The response contains player_count and result.
# - player_count is numeric.
# - The API response does not include appid.
# - Each player-count file must be associated with its corresponding
#   game using an identifier or file mapping.
# - Player counts represent a snapshot at the time the API was queried.

# FOUND: most_played: 100 rows; rank and appid are never repeated; rollup_date is Unix time (1793664000 = 2026-11-03 UTC) -> convert with as.POSIXct(); this file is the frozen game list
# FOUND: most_played: last_week_rank is -1 for 2 games that are new to the chart -> -1 is not a rank: set to NA
# FOUND: store_details: all 100 answers have success = true, but type is "mod" (tModLoader) or "advertising" (FiveM) for 2 apps, and OBS Studio is a "game" whose genres are Utilities / Video Production -> keep games only (97)
# FOUND: store_details: price_overview is missing for 36 apps: the 31 free ones and 5 paid ones with no price shown (Deadlock, Call of Duty, Rocket League, FiveM, GTA V Legacy) -> price NA means unknown; 0 only when is_free
# FOUND: store_details: prices are Canadian cents (final 324 to 8999 = $3.24 to $89.99), SteamSpy's are US cents -> divide by 100; price questions use the store's CAD prices
# FOUND: store_details: 8 games were discounted on the day of the sample (10 % to 75 %) -> Q4 has discount cases to compare
# FOUND: store_details: is_free is TRUE for 31 apps but genre "Free To Play" for 30 (OBS Studio is free without it) -> free/paid comes from is_free, not from the genre
# FOUND: store_details: release_date is "16 May, 2011" style for 98 apps, "To be announced" (Deadlock) and "" (FiveM) -> parse with "%d %b, %Y"; the two stay NA
# FOUND: store_details: metacritic is missing for 64 apps, recommendations for 14, achievements for 17 -> no question uses them; kept as NA
# FOUND: store_details: names carry trademark signs ("Overwatch(R)", "Apex Legends(TM)") -> strip them for display; joins use appid only
# FOUND: store_details fills the SteamSpy gap: Overwatch 2, AION 2, Zenless Zone Zero, THE FINALS and FINAL FANTASY RESONANCE all have a name, is_free and genres here
# FOUND: the 10 hand-picked samples include appid 4435490 (Call of Duty: Modern Warfare 4), which is not in the frozen top 100 -> polls and pulls use frozen_appids() from now on
# =============================================================================
# P4 -- The tables you plan (preliminary: they may change once you know your data)
# -----------------------------------------------------------------------------
#   grain : what ONE row is ("one row per item per day")
#   key   : the column(s) that identify one row -- never repeated, never missing
#   owner : who builds it; a table can have several owners: "Alex Example, Sam Example"
# Example:
#   sales = list(grain = "one row per item per day", key = c("item", "date"), owner = "Alex Example"),
#   items = list(grain = "one row per menu item",    key = "item",            owner = "Sam Example"),
# =============================================================================
TABLES <- list(
  games         = list(grain = "one row per game in the frozen top 100 (from store_details, steamspy_games and most_played)",
                       key = "appid", owner = "Mark Buban"),
  player_counts = list(grain = "one row per game per poll (from player_counts)",
                       key = c("appid", "pulled_at_utc"), owner = "Mark Buban, Riwaz Silwal")
)
# NOTE: the player-count answers do not contain appid or a time. For now appid comes
# from the file name (players_<game>.json matched to spy_<game>.json); from Lab 8 on,
# save each poll as players_<appid>_<UTC time>.json so both key columns come from the file.

# How the tables link: child -> parent, through a shared key column. E.g.
#   list(child = "sales", parent = "items", key = "item")
LINKS <- list(
  list(child = "player_counts", parent = "games", key = "appid")
)
