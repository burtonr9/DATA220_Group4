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
    what = "Game metadata for 60 Steam games ; currently includes 10 as a sample, including app ID, name, developer, publisher, reviews, price and tags",
    format = "json",
    get = "api",
    link = "https://steamspy.com/api.php?request=appdetails&appid=<appid>",
    file = "data/raw/steamspy_games",
    owner = "Riwaz Silwal"
  ),
  
  player_counts = list(
    what = "Current player-count responses for the same 60 Steam games; currently includes 10 as a sample.",
    format = "json",
    get = "api",
    link = "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=<appid>",
    file = "data/raw/player_counts",
    owner = "Riwaz Silwal"
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
  games         = list(grain = "one row per game (from steamspy_games)",
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
