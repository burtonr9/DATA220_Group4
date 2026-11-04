# What keeps Steam's most-played games busy?

## 1. Title, team, roles

**Project title:** What keeps Steam's most-played games busy? · **Team number:** 4

| Member | Looks after |
|---|---|
| Mark Buban | sources `most_played` and `store_details` (`fetch_store_details.R`); table `games`; `01_extract.R` and `02_clean.R`; the database (`05_db.R`); assembling `report.qmd`; Q1 and Q3 |
| Ryan Burton | the daily price pull and table `price_snapshots`; `03_join.R`; `data_dictionary.md`; Q4 and Q5 |
| Riwaz Silwal | sources `steamspy_games` and `player_counts`, and running the 3-hour poll (`poll_players.R`); table `player_counts`; `04_checks.R`; `quality_report.md`; Q2 and Q6 |

Everyone writes the SQL for their own questions, the FOUND / DECISION / CHECK steps in `02_clean.R` for their own
tables, and their own slides.

## 2. Questions

The games are the 100 in Steam's Most Played chart saved on November 4, 2026 (chart date November 3, UTC), less
the apps that are not games (3, see the audit): 97 games. "Concurrent players" always means Steam's own
`player_count`, not SteamSpy's `ccu`. Prices are the Steam store's, in Canadian dollars.

1. How do free-to-play and paid games compare in concurrent players, and does the gap differ by genre?
2. How does concurrent play vary by hour of day (UTC) and day of week over the observation window, and which games
   swing most between weekdays and weekends?
3. Is a game's price band (free, under $20, $20–$40, over $40 CAD) related to its share of positive reviews?
4. Did games that went on discount during the window have more concurrent players while discounted than in the days
   before?
5. How does concurrent play compare with SteamSpy's estimated number of owners: which games keep the largest share
   of their owners playing?
6. What share of all concurrent players in the list do the five most-played games (highest median player count over
   the window) hold at each poll, and how much does that share change by hour, by day of week and across the window?

## 3. Sources

All four sources are public addresses called from R with httr2. None needs a key or a login, and none returns data
about individual players: only game-level, aggregated numbers are requested. Every answer is saved untouched in
`project/data/raw/`.

| # | Source (config name) · owner | What it is | Address | Sample in `data/raw/` |
|---|---|---|---|---|
| 1 | Most Played chart (`most_played`) · Mark Buban | Steam's top 100 games by concurrent players: rank, appid, last week's rank, peak. Saved once; that file is the frozen game list. | `api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/` | `most_played.json` (100 games, saved November 4, 2026) |
| 2 | Store details (`store_details`) · Mark Buban | One game's store record: type, name, free or paid, price and discount (CAD), genres, release date, developer. One request per game; pulled once for the list, then daily for prices (Q4). | `store.steampowered.com/api/appdetails?appids=<appid>&cc=ca` | `store_details/store_<appid>.json` (all 100 games, saved November 4, 2026) |
| 3 | SteamSpy game details (`steamspy_games`) · Riwaz Silwal | Positive and negative review counts and estimated owners (a range), which the store does not give. | `steamspy.com/api.php?request=appdetails&appid=<appid>` | `steamspy_games/spy_<game>.json` (10 games, saved November 3, 2026) |
| 4 | Current players (`player_counts`) · Riwaz Silwal | Steam's count of people playing one game right now. No history exists, so we build it by polling every 3 hours. | `api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=<appid>` | `player_counts/players_<game>.json` (10 games, one poll, November 3, 2026) |

**How they are saved and read.** `scripts/fetch_store_details.R` saves the chart and the 100 store answers;
`steam_save()` in `R/functions_steam.R` (our own, explained in the file) keeps each answer byte for byte, never
overwrites a saved file, and refuses an answer that is not JSON. All four answers are nested JSON that
`read_any_file()` cannot read, so `read_steam_file()` (chart, store) and `read_record_folder()` (SteamSpy, players)
flatten them to text columns before profiling and cleaning.

**Terms.** Sources 1, 2 and 4 are Valve's: the Steam Web API Terms of Use for `api.steampowered.com` and the Steam
Subscriber Agreement for `store.steampowered.com`. SteamSpy is a third-party site that publishes estimates derived
from Steam and states no licence. None is an open licence, so we are emailing the instructor to confirm the sources
are acceptable; the answer goes in `config.R`. If redistribution is not allowed, only samples stay in Git and
`config.R` says how the full data are obtained.

**Limits and size.** Every address returns one game per request, except the chart.

- Store: about 200 requests per 5 minutes per IP; we pause 1.5 s, so 100 games take 2.5 minutes. The daily price
  pull adds 100 rows a day: about 2,700 rows by November 30.
- Players: 100 requests per poll, 1 s apart, 8 polls a day → 800 requests and 800 rows a day, about 21,600 rows by
  November 30. The poll runs on Riwaz Silwal's computer with Windows Task Scheduler. A missed poll stays missing;
  nothing is filled in.
- SteamSpy: about 1 request per second; 100 requests, pulled once at M2.
- `config.R` sets `USE_SAVED_SAMPLE`, so the pipeline runs from the saved answers when a site is down. Polls cannot
  be re-pulled later, so every poll file is committed.

## 4. Data audit

Profiles from `scripts/00_inspect_sources.R` (in `output/`), the inspect functions, and the first cleaning run
(`02_clean.R`).

**most_played** · 100 rows · 4 fields plus `rollup_date`

- FOUND: rank and appid are never repeated; `rollup_date` is Unix time (1793664000 = 2026-11-03 UTC) → converted to a
  date; this saved file is the frozen list and is never re-fetched.
- FOUND: `last_week_rank` is -1 for 2 games new to the chart, and differs from `rank` for 91 of 100 → -1 is not a
  rank: set to NA; the chart moves daily, which is why it is frozen.
- FOUND: `peak_in_game` ranges from 6,518 to 1,127,912 → a few games dominate: medians and a log scale in charts.

**store_details** · 100 answers · one game each

- FOUND: every answer has `success = true`, but 2 apps are not games (`type` "mod": tModLoader; "advertising":
  FiveM) and OBS Studio is listed as a game with genres Utilities / Video Production → keep games only: 97.
- FOUND: `price_overview` is missing for 36 apps: the 31 free ones and 5 paid ones with no price shown (Deadlock,
  Call of Duty, Rocket League, FiveM, GTA V Legacy) → price NA means "unknown"; 0 only when `is_free` is true.
- FOUND: prices are Canadian cents (final 324 to 8999 = $3.24 to $89.99), while SteamSpy's are US cents → divide by
  100; price questions use the store's CAD prices only.
- FOUND: 8 games were discounted on the sample day (10 % to 75 %) → Q4 will have discount cases to compare.
- FOUND: `is_free` is true for 31 apps, genre "Free To Play" for 30 (OBS Studio is free without it) → free or paid
  comes from `is_free`, not the genre.
- FOUND: several genres per game ("Action, Adventure, RPG"; Action in 66 games) → a `game_genres` table; a game
  counts in every genre it lists (a limitation for Q1).
- FOUND: `release_date` is "16 May, 2011" style for 98 apps; "To be announced" (Deadlock) and "" (FiveM) → parse with
  "%d %b, %Y"; those two stay NA.
- FOUND: Metacritic is missing for 64 apps, recommendations for 14, achievements for 17 → no question uses them.
- FOUND: names carry trademark signs ("Overwatch®", "Apex Legends™") → stripped for display; joins use appid only.

**steamspy_games** · 10 rows (hand-picked sample) · 20 fields plus `source_file`

- FOUND: 6 of 10 games (Aion 2, Final Fantasy Resonance, Overwatch 2, The Finals, Zenless Zone Zero, Call of Duty:
  Modern Warfare 4) have positive = 0, negative = 0, ccu = 0 and owners "0 .. 20,000", while Steam reports 60,170
  people playing Overwatch 2 → SteamSpy has not tracked these games; the zeros are set to NA. The store details
  have name, `is_free` and genres for all five that are in the top 100, so only Q3 and Q5 lose these games.
- FOUND: score_rank is empty in all 10 rows; userscore and the four playtime columns are 0 in all 10 → dropped.
- FOUND: owners is a text range ("20,000,000 .. 50,000,000") → split into `owners_low` and `owners_high`; Q5 reports
  both ends, never one number.
- FOUND: SteamSpy's ccu (1,013,936 for Counter-Strike 2) is a daily peak and differs from Steam's player_count
  (1,164,756) → not used.

**player_counts** · 10 rows (one poll of the hand-picked sample)

- FOUND: the answer holds only `player_count` and `result` — no appid and no time → from the first real poll,
  `poll_players.R` writes `appid` and `pulled_at_utc` into every row.
- FOUND: `result` is 1 in all 10; player_count ranges from 0 (Call of Duty: Modern Warfare 4) to 1,164,756
  (Counter-Strike 2) → a 0 is checked before it is kept; medians and a log scale.
- FOUND: the hand-picked sample includes appid 4435490 (Call of Duty: Modern Warfare 4), which is not in the frozen
  top 100 → polls and pulls use the frozen list (`frozen_appids()`) from now on.

**Concerns**

- **SteamSpy coverage.** Recent releases are untracked, so Q3 (reviews) and Q5 (owners) may rest on fewer games than
  the other questions; the report says how many. Fallback for reviews: Steam's review totals
  (`store.steampowered.com/appreviews/<appid>?json=1&num_per_page=0`).
- **Undocumented store address.** Valve does not document `appdetails`; it can change shape without notice. The
  saved answers keep the pipeline running.
- **Terms.** No source has an open licence; the instructor's answer goes in `config.R`.
- **Short window.** Player and price history start with the first poll: about four weeks. If no game changes its
  discount in that window, Q4 becomes a comparison of discounted and full-price games on the same days.
- **Top 100 only.** The list favours long-running free-to-play games; findings do not describe Steam as a whole.

## 5. Table plan (preliminary)

| Table | Grain (one row is…) | Key | Built from | Owner |
|---|---|---|---|---|
| `games` | one game in the frozen top 100 | `appid` | most_played, store_details, steamspy_games | Mark Buban |
| `player_counts` | one game × poll | `appid`, `pulled_at_utc` | player_counts | Mark Buban, Riwaz Silwal |
| `price_snapshots` | one game × day | `appid`, `price_date` | store_details (daily pulls) | Ryan Burton |

**Links:** `player_counts` and `price_snapshots` each link to `games` through `appid`.

**Possible changes at M2:** a `game_genres` table (one row per game × genre) for Q1; an `on_discount` column in
`player_counts` from `price_snapshots`, for Q4.
