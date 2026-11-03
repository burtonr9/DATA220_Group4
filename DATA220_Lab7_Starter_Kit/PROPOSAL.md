<!-- PROTOTYPE (November 1). Items marked *(to confirm)* get their numbers from 00_inspect_sources.R before November 4. -->

# What keeps Steam's most-played games busy?

## 1. Title, team, roles

**Project title:** What keeps Steam's most-played games busy? · **Team number:** 4

| Member | Looks after |
|---|---|
| Ryan Burton | sources `most_played` and `store_details`; table `games`; `R/functions_steam.R` and `01_extract.R`; `data_dictionary.md`; Q1 and Q3 |
| Riwaz Silwal | sources `players` and `prices`, and running the 3-hour poll (`poll_players.R`); tables `player_snapshots` and `price_snapshots`; `03_join.R` and `04_checks.R`; `quality_report.md`; Q2 and Q5 |
| Mark Buban | sources `achievements` and `reviews`; tables `game_genres` and `achievements`; the database (`05_db.R`); assembling `report.qmd`; Q4 and Q6 |

Everyone writes the SQL for their own questions, the FOUND / DECISION / CHECK steps in `02_clean.R` for their own tables, and their own slides.

## 2. Questions

1. Among Steam's 100 most-played games (list frozen on November 2, 2026, UTC), how do free-to-play and paid games compare in
   concurrent players, and does the gap differ by genre?
2. How does concurrent play vary by hour of day (UTC) and day of week from November 2 to November 30, 2026, and
   which genres swing most between weekdays and weekends?
3. Is a game's price band (free, under $20, $20–$40, over $40 CAD) related to its share of positive reviews?
4. Which genres have the hardest achievements (the lowest median global unlock rate), and do games with more
   achievements have lower unlock rates?
5. Did games that went on discount during the observation window have more concurrent players while discounted
   than in the days before?
6. Do games with more concurrent players have higher or lower median achievement unlock rates than games with
   fewer players?

## 3. Sources

All six sources are Valve's own public addresses, called from R with httr2. None needs a key or a login, and none
returns data about individual players: only game-level, aggregated data are requested. Every answer is saved
untouched in `project/data/raw/` by `scripts/fetch_samples.R` (samples) and `scripts/poll_players.R` (polls).

**Terms (all sources):** Steam Web API Terms of Use (steamcommunity.com/dev/apiterms) for `api.steampowered.com`;
Steam Subscriber Agreement for `store.steampowered.com`. Neither is an open licence, so we are emailing the instructor
before November 4 to confirm the sources are acceptable. If redistribution is not allowed, only samples stay in Git and
`config.R` says how the full data are obtained.

| # | Source (config name) · owner | What it is | Address | Sample in `data/raw/` |
|---|---|---|---|---|
| 1 | Most Played chart (`most_played`) · Ryan Burton | Valve's live top 100 by concurrent players: rank, appid, last week's rank, 24-hour peak. Saved once; that file is the frozen game list. | `api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/` | `most_played.json` (7 KB, 100 games, saved 2026-11-02 01:21 UTC) |
| 2 | Store details (`store_details`) · Ryan Burton | One game's store record: type, name, free or paid, price, genres, release date, developer, Metacritic, recommendations. One request per game. | `store.steampowered.com/api/appdetails?appids=<id>&cc=ca` | `appdetails_730.json` (19 KB) |
| 3 | Daily prices (`prices`) · Riwaz Silwal | Canadian price and discount for every game, once a day; 50 games per request (`filters=price_overview`). | same address, `&filters=price_overview` | `prices/prices_<date>_<n>.json` |
| 4 | Current players (`players`) · Riwaz Silwal | Number of people playing each game right now; one request per game, every 3 hours. No history exists, so we build it. | `api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=<id>` | `players/players_<UTC time>.csv` (one row per game; Steam's answer kept as received in `body`) |
| 5 | Achievement percentages (`achievements`) · Mark Buban | Global unlock percentage of every achievement in a game, aggregated over all players. | `api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=<id>` | `achievements_440.json` (29 KB) |
| 6 | Review totals (`reviews`) · Mark Buban | Positive and negative review counts and the score label. `num_per_page=0`: no review text, no reviewer IDs. | `store.steampowered.com/appreviews/<id>?json=1&language=all&purchase_type=all&num_per_page=0` | `reviews_730.json` *(to confirm: the first request returned Steam's HTML home page, so the address is being corrected)* |

**Format:** all JSON. The answers are nested, which `read_any_file()` cannot read, so `R/functions_steam.R` (our
own, explained in the file) flattens each shape to text columns before profiling and cleaning.

**Limits and size.** Most addresses return one game per request, so the project is limited to the frozen 100
games, not the whole catalogue.

- Store addresses allow about 200 requests per 5 minutes per IP; we pause 1.5 s between store requests.
- Players: 100 requests per poll, 1 s apart, 8 polls a day → about 800 requests a day and about 23,000 rows by
  November 30. The poll runs on Riwaz Silwal's computer with Windows Task Scheduler. A missed poll stays missing; nothing
  is filled in.
- Prices: 2 requests a day → about 30 rows per game. Store details, achievements and reviews: 100 requests each,
  pulled once at M2.
- `config.R` sets `USE_SAVED_SAMPLE`, so the pipeline runs from the saved answers when Steam is down. The polls
  cannot be re-pulled later, so every poll file is committed.

## 4. Data audit

Samples saved on November 2, 2026 (UTC) with `scripts/fetch_samples.R`; profiles from `scripts/00_inspect_sources.R`
(in `output/profile_*.csv`). Counts marked *(to confirm)* are filled in from those profiles before submission.

**most_played** · 100 rows (one per game)

- FOUND: appid and rank but no game name → names come from `store_details`; join on `appid` only, never on names.
- FOUND: the chart changes daily (`last_week_rank` differs from `rank` for some games; count *(to confirm)*) → the first saved file is the frozen list.
- FOUND: some of the 100 appids may not be `type = "game"` (count *(to confirm)* in the full store pull) → keep games only; report how many were dropped.

**store_details** · sample appid 730 · 19 columns after flattening

- FOUND: the answer is keyed by the appid with a `success` flag → an appid with `success = false` (count *(to confirm)* in the full pull) is listed and excluded.
- FOUND: prices are whole cents (2999 = $29.99) and absent for free games → divide by 100; price 0 when `is_free` is true, not NA.
- FOUND: `release_date` is text like "21 Aug, 2012", which `DATE_FORMATS` does not cover → parse with "%d %b, %Y"; list values that fail ("Coming soon", year only).
- FOUND: several genres in one cell ("1:Action | 37:Free To Play") → split into `game_genres`; a game counts in every genre it lists (a limitation for Q1, Q2 and Q4).
- FOUND: `metacritic_score` is missing for many games, mostly free ones (count *(to confirm)*) → not used by any question; kept as NA.

**prices** · first day saved November 2, 2026

- FOUND: `data` is empty for free games → price columns NA there; NA means "no price", and free comes from `store_details`.
- FOUND: `discount_percent` range and number of discounted games *(to confirm)* → a discount day is `discount_percent > 0`.

**players** · first poll November 2, 2026 (100 games)

- FOUND: `result` is not 1 (or `http_status` not 200) for some rows (count *(to confirm)*) → dropped and counted.
- FOUND: `pulled_at_utc` is our clock, in UTC, and differs by a few seconds within a poll → round to the poll's hour for Q2; hours are reported in UTC.
- FOUND: polls can be missed (computer asleep or offline) → no filling in; Q2 reports how many polls each hour has.
- FOUND: `player_count` spans several orders of magnitude (range *(to confirm)*) → medians and a log scale, because a few games dominate.

**achievements** · sample appid 440 · achievement count *(to confirm)*

- FOUND: `achievement_name` is an internal code (display names need a key) → kept as the key; not shown in charts.
- FOUND: `percent` type (text or number) and range *(to confirm)* → `to_number()`, then `show_out_of_range(0, 100)`.
- FOUND: some of the 100 games have no achievements (count *(to confirm)*) → excluded from Q4 and Q6 and listed.

**reviews** · sample appid 730

- FOUND: the first request to the reviews address returned Steam's HTML home page, not JSON → `steam_save()` now refuses anything that is not JSON, and the address is being corrected.
- FOUND: the totals change with `language` and `purchase_type` → fixed at `all` / `all` in `fetch_samples.R`.
- FOUND: positive share = `total_positive / total_reviews`, range *(to confirm)* → Q3 uses the share, not the score label; games with 0 reviews excluded.

**Concerns**

- **Terms.** Steam's terms are not an open licence; the instructor's answer goes in `config.R`.
- **Short window.** Player and price history start on November 2, 2026: four weeks. If no game is discounted in that window, Q5 becomes a comparison of discounted and full-price games on the same days.
- **Undocumented store addresses** can change shape without notice; the saved answers keep the pipeline running.
- **Top 100 only.** The list favours long-running free-to-play games; findings do not describe Steam as a whole.

## 5. Table plan (preliminary)

| Table | Grain (one row is…) | Key | Built from | Owner |
|---|---|---|---|---|
| `games` | one game in the frozen top 100 | `appid` | most_played, store_details, reviews | Ryan Burton |
| `game_genres` | one game × genre | `appid`, `genre_id` | store_details | Mark Buban |
| `player_snapshots` | one game × poll | `appid`, `pulled_at_utc` | players | Riwaz Silwal |
| `price_snapshots` | one game × day | `appid`, `price_date` | prices | Riwaz Silwal |
| `achievements` | one game × achievement | `appid`, `achievement_name` | achievements | Mark Buban |

**Links:** `game_genres`, `player_snapshots`, `price_snapshots` and `achievements` each link to `games` through `appid`.

**Possible changes at M2:** a `genres` lookup (one row per `genre_id` with its name) if genre names repeat; an
`on_discount` column in `player_snapshots` from `price_snapshots`, for Q5.
