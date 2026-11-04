# R/functions_steam.R -- OUR OWN functions for the Steam sources (not part of the course toolkit).
# Steam answers with nested JSON, which read_any_file() cannot read ("the records are inside
# another field"). These functions
#   1. request a Steam address and save the answer EXACTLY as received (steam_save()), and
#   2. turn a saved answer into a flat table of text columns (read_steam_file()), so the
#      rest of the pipeline works like it does for a CSV.
# Load them after the toolkit:   source("R/load_functions.R");  source("R/functions_steam.R")
# httr2 is only needed by steam_get()/steam_save(); reading saved files needs jsonlite only.
# Functions: steam_get(), steam_save(), read_steam_file(), profile_steam_file(),
#            frozen_appids()

STEAM_USER_AGENT <- "DATA220 student project (MacEwan University)"


# ============================================================================
# steam_get(url, query = list())
# PURPOSE   One HTTP GET to a Steam address. Returns the status and the body as raw bytes.
# HOW       httr2 (Lab 8): request() -> req_url_query() -> req_retry() -> req_perform().
#           req_retry() waits and tries again (up to 3 times) when Steam says 429 (too many
#           requests) or 5xx (busy). req_error(is_error = FALSE) lets US decide what a bad
#           status means, instead of stopping.
# ============================================================================
steam_get <- function(url, query = list()) {
  req <- httr2::request(url)
  if (length(query) > 0) req <- httr2::req_url_query(req, !!!query)
  req <- req |>
    httr2::req_user_agent(STEAM_USER_AGENT) |>
    httr2::req_timeout(30) |>
    httr2::req_retry(max_tries = 3,
                     is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503),
                     backoff = function(i) 30 * i) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)
  list(status = httr2::resp_status(resp), raw = httr2::resp_body_raw(resp))
}


# ============================================================================
# steam_save(url, query, dest, overwrite = FALSE)
# PURPOSE   Request a Steam address and save the answer to data/raw/ byte for byte.
# RULES     Never overwrites an existing file unless overwrite = TRUE (raw files are never
#           changed). Stops if Steam does not answer 200, so a bad answer is never saved as data.
# ============================================================================
steam_save <- function(url, query = list(), dest, overwrite = FALSE) {
  if (file.exists(dest) && !overwrite) {
    log_msg("kept existing ", dest, " (raw files are never overwritten)")
    return(invisible(dest))
  }
  res <- steam_get(url, query)
  if (res$status != 200) stop("Steam answered ", res$status, " for ", url)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeBin(res$raw, dest)
  log_msg("saved Steam answer (", length(res$raw), " bytes) -> ", dest)
  invisible(dest)
}


# Helpers: take one value out of a nested list; NA when any step is missing.
steam_value <- function(x, path) {
  for (p in path) {
    if (!is.list(x) || is.null(x[[p]])) return(NA_character_)
    x <- x[[p]]
  }
  if (length(x) == 0) return(NA_character_)
  as.character(x[[1]])
}
# A list of plain values -> one text value, "a | b | c"
steam_join <- function(x) {
  if (length(x) == 0) return(NA_character_)
  paste(unlist(x), collapse = " | ")
}


# ============================================================================
# read_steam_file(path)
# PURPOSE   Read one saved Steam answer and return a flat data frame of TEXT columns
#           (like read_raw_csv(): nothing is converted; cleaning decides that).
# KNOWS     the six shapes this project saves, recognised by their top-level fields:
#   most_played.json         {"response": {"rollup_date", "ranks": [{rank, appid, ...}]}}
#   appdetails_<id>.json     {"<appid>": {"success", "data": {...one game...}}}
#   prices/prices_*.json     the same, many appids, data = price_overview only ([] for free games)
#   achievements_<id>.json   {"achievementpercentages": {"achievements": [{name, percent}]}}
#   reviews_<id>.json        {"success", "query_summary": {...totals...}, "reviews": []}
#   players/players_*.csv    our poll file: appid, pulled_at_utc, http_status, body (JSON text)
# ============================================================================
read_steam_file <- function(path) {
  if (!file.exists(path)) stop("File not found: ", path)
  if (tolower(tools::file_ext(path)) == "csv") {
    # a players poll: keep the poll columns, take player_count and result out of each body
    poll <- read_raw_csv(path)
    bodies <- lapply(poll$body, function(b) tryCatch(jsonlite::fromJSON(b, simplifyVector = FALSE),
                                                    error = function(e) list()))
    poll$player_count <- vapply(bodies, steam_value, "", path = c("response", "player_count"))
    poll$result       <- vapply(bodies, steam_value, "", path = c("response", "result"))
    poll$body <- NULL
    poll$source_file <- basename(path)
    return(poll)
  }

  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  if (!is.null(j$response$ranks)) {                                   # Most Played chart
    df <- bind_rows(lapply(j$response$ranks, function(r) lapply(r, as.character)))
    df$rollup_date <- steam_value(j, c("response", "rollup_date"))
  } else if (!is.null(j$achievementpercentages)) {                    # achievements
    a <- j$achievementpercentages$achievements
    df <- data.frame(achievement_name = vapply(a, steam_value, "", path = "name"),
                     percent          = vapply(a, steam_value, "", path = "percent"))
    df$appid <- sub("^achievements_([0-9]+).*$", "\\1", basename(path))
  } else if (!is.null(j$query_summary)) {                             # review summary
    df <- as.data.frame(lapply(j$query_summary, as.character))
    df$success <- steam_value(j, "success")
    df$appid <- sub("^reviews_([0-9]+).*$", "\\1", basename(path))
  } else if (length(j) > 0 && all(grepl("^[0-9]+$", names(j)))) {     # appdetails (one or many)
    rows <- list()
    for (id in names(j)) {
      d <- j[[id]]$data
      if (!is.list(d)) d <- list()
      rows[[id]] <- data.frame(
        appid            = id,
        success          = steam_value(j[[id]], "success"),
        type             = steam_value(d, "type"),
        name             = steam_value(d, "name"),
        is_free          = steam_value(d, "is_free"),
        required_age     = steam_value(d, "required_age"),
        release_date     = steam_value(d, c("release_date", "date")),
        coming_soon      = steam_value(d, c("release_date", "coming_soon")),
        developers       = steam_join(d$developers),
        publishers       = steam_join(d$publishers),
        genres           = steam_join(lapply(d$genres, function(g) paste0(g$id, ":", g$description))),
        currency         = steam_value(d, c("price_overview", "currency")),
        price_initial    = steam_value(d, c("price_overview", "initial")),
        price_final      = steam_value(d, c("price_overview", "final")),
        discount_percent = steam_value(d, c("price_overview", "discount_percent")),
        metacritic_score = steam_value(d, c("metacritic", "score")),
        recommendations  = steam_value(d, c("recommendations", "total")),
        achievements_total = steam_value(d, c("achievements", "total")))
    }
    df <- bind_rows(rows)
  } else {
    stop(path, ": not one of the Steam answers this project knows (see read_steam_file())")
  }
  df <- as.data.frame(df)
  for (col in names(df)) df[[col]] <- as.character(df[[col]])
  df$source_file <- basename(path)
  log_msg("read ", nrow(df), " rows x ", ncol(df), " columns from ", path)
  df
}


# ============================================================================
# profile_steam_file(path)
# PURPOSE   profile_raw_file() for a Steam answer: the same table (column, looks_like,
#           missing, distinct, examples), built with the toolkit's own helpers
#           guess_type() and show_examples(), after read_steam_file() has flattened it.
# ============================================================================
profile_steam_file <- function(path) {
  df <- read_steam_file(path)
  rows <- list()
  for (col in names(df)) {
    v <- df[[col]]
    filled <- v[!is.na(v) & str_squish(v) != ""]
    rows[[col]] <- data.frame(column     = col,
                              looks_like = guess_type(filled),
                              missing    = length(v) - length(filled),
                              distinct   = length(unique(filled)),
                              examples   = show_examples(filled))
  }
  message("profile: ", nrow(df), " rows x ", ncol(df), " columns")
  bind_rows(rows)
}


# ============================================================================
# frozen_appids(path = "data/raw/most_played.json")
# PURPOSE   The project's fixed list of games: the appids in the Most Played chart that
#           was saved first. Every poll uses this list, so the games never change.
# ============================================================================
frozen_appids <- function(path = "data/raw/most_played.json") {
  if (!file.exists(path)) stop(path, " is missing: run scripts/fetch_samples.R first")
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  vapply(j$response$ranks, function(r) as.character(r$appid), "")
}
