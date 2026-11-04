# What keeps Steam's most-played games busy?

## 1. Title, team, roles

**Project title:** What keeps Steam's most-played games busy? · **Team number:** 4

| Member | Looks after |
|---|---|
| Ryan Burton | the daily SteamSpy pull and table `price_snapshots`; `03_join.R`; `data_dictionary.md`; Q4 and Q5 |
| Riwaz Silwal | sources `steamspy_games` and `player_counts`, and running the 3-hour poll (`poll_players.R`); table `player_counts`; `04_checks.R`; `quality_report.md`; Q2 and Q6 |
| Mark Buban | table `games`; `01_extract.R` and `02_clean.R`; the database (`05_db.R`); assembling `report.qmd`; Q1 and Q3 |

Everyone writes the SQL for their own questions, the FOUND / DECISION / CHECK steps in `02_clean.R` for their own
tables, and their own slides.

## 2. Questions

The games are a fixed list of 60 appids taken from Steam's Most Played chart and written in `config.R` before the first
poll. "Concurrent players" always means Steam's own `player_count`, not SteamSpy's `ccu`.

1. How do free-to-play and paid games compare in concurrent players, and does the gap differ by genre?
2. How does concurrent play vary by hour of day (UTC) and day of week over the observation window, and which games
   swing most between weekdays and weekends?
3. Is a game's price band (free, under $20, $20–$40, over $40 USD) related to its share of positive reviews?
4. Did games that went on discount during the window have more concurrent players while discounted than in the days
   before?
5. How does concurrent play compare with SteamSpy's estimated number of owners: which games keep the largest share
   of their owners playing?
6. What share of all concurrent players in the list do the five most-played games (highest median player count over
   the window) hold at each poll, and how much does that share change by hour, by day of week and across the window?

## 3. Sources

Both sources are public addresses called from R with httr2. Neither needs a key or a login, and neither returns data
about individual players: only game-level, aggregated numbers are requested. Every answer is saved untouched in
`project/data/raw/`.

| # | Source (config name) · owner | What it is | Address | Sample in `data/raw/` |
|---|---|---|---|---|
| 1 | SteamSpy game details (`steamspy_games`) · Riwaz Silwal | One game per request: appid, name, developer, publisher, positive and negative review counts, estimated owners (a range), price, initial price, discount, genre, languages, tags. Pulled once for the game list, then once a day for prices and discounts (Q4). | `steamspy.com/api.php?request=appdetails&appid=<appid>` | `steamspy_games/spy_<game>.json` (10 games, saved November 3, 2026) |
| 2 | Current players (`player_counts`) · Riwaz Silwal | Steam's count of people playing one game right now. No history exists, so we build it by polling every 3 hours. | `api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=<appid>` | `player_counts/players_<game>.json` (10 games, one poll, November 3, 2026) |

**Format:** both are JSON with one game per file, which `read_any_file()` cannot read (each file is one object, not a
list of rows, and the player count sits inside `response`). `read_record_folder()` in `R/functions_read.R` (our own,
explained in the file) reads a folder of answers into one row per file and records which file each row came from.

**Terms.** SteamSpy is a third-party site, not Valve; it publishes estimates derived from Steam and states no open
licence. The player-count address falls under the Steam Web API Terms of Use. Neither is an open licence, so we are
emailing the instructor to confirm the sources are acceptable; the answer goes in `config.R`. If redistribution is not
allowed, only samples stay in Git and `config.R` says how the full data are obtained.

**Limits and size.** Both addresses return one game per request.

- SteamSpy allows about 1 request per second; 60 games take about a minute. Daily pulls to November 30: about 1,600
  rows.
- Players: 60 requests per poll, 1 s apart, 8 polls a day → about 480 requests and 480 rows a day, about 13,000 rows by
  November 30. The poll runs on Riwaz Silwal's computer with Windows Task Scheduler. A missed poll stays missing; nothing
  is filled in.
- `config.R` sets `USE_SAVED_SAMPLE`, so the pipeline runs from the saved answers when either site is down. Polls
  cannot be re-pulled later, so every poll file is committed.

## 4. Data audit

Samples saved on November 3, 2026, for 10 games; profiles from `scripts/00_inspect_sources.R` (in `output/`), the
inspect functions, and the first cleaning run (`02_clean.R`).

**steamspy_games** · 10 rows · 20 fields plus `source_file`

- FOUND: 6 of 10 games (Aion 2, Final Fantasy Resonance, Overwatch 2, The Finals, Zenless Zone Zero, Call of Duty: Modern
  Warfare 4) have positive = 0, negative = 0, ccu = 0 and owners "0 .. 20,000", while Steam reports 60,170 people
  playing Overwatch 2 at the same time → SteamSpy has not tracked these games; the zeros are set to NA and a
  `has_steamspy_data` flag is kept. Q3 and Q5 use only tracked games and say how many that is.
- FOUND: price, initialprice and discount are text in US cents ("5999" = $59.99) and missing for 3 games → `to_number()`,
  divide by 100; missing stays NA ("unknown"), because 0 means free.
- FOUND: score_rank is empty in all 10 rows; userscore, average_forever, average_2weeks, median_forever and
  median_2weeks are 0 in all 10 (SteamSpy no longer publishes them) → dropped.
- FOUND: owners is a text range ("20,000,000 .. 50,000,000") → split into `owners_low` and `owners_high`; Q5 reports
  both ends, never one number.
- FOUND: name is empty for 2 games and developer/publisher for 3; Counter-Strike 2 still carries its old name
  "Counter-Strike: Global Offensive" → names are filled from our file label and recoded; names are for display only,
  every join uses appid.
- FOUND: genre holds several values in one cell ("Action, Free To Play") and is empty for 3 games → `is_free` = genre
  contains "Free To Play" (2 free, 5 paid, 3 unknown); for Q1 a game counts in every genre it lists (a limitation).
- FOUND: SteamSpy's ccu (1,013,936 for Counter-Strike 2) is a daily peak, not a live count, and differs from Steam's
  player_count (1,164,756) → not used; concurrent players always come from source 2.
- FOUND: appid is present and different in all 10 rows → `check_key(games, "appid")` passes.

**player_counts** · 10 rows (one poll)

- FOUND: the answer holds only `player_count` and `result` — no appid and no time → for the sample, the game is matched
  through the file name; from the first real poll, files are named `players_<appid>_<UTC time>.json`, so both key
  columns come from the file name.
- FOUND: the file names differ in capitals from the SteamSpy files (`players_Cyber_punK_2077` vs
  `spy_Cyber_punk_2077`) → both are lower-cased before matching; all 10 match.
- FOUND: `result` is 1 in all 10 answers; player_count ranges from 0 (Call of Duty: Modern Warfare 4) to 1,164,756
  (Counter-Strike 2) → a 0 is checked against the appid before it is kept; medians and a log scale, because a few
  games dominate.

**Concerns**

- **SteamSpy coverage.** 6 of the 10 sample games have no SteamSpy data — mostly recent releases. If that share holds
  for the 60 games, Q3 and Q5 rest on fewer games. Fallback: Steam's own store and review addresses
  (`store.steampowered.com/api/appdetails`, `/appreviews`) for price, genre and review counts.
- **Appids to verify.** SteamSpy returned no name for appids 3393110 (Aion 2) and 4162040 (Zenless Zone Zero), and
  4435490 (Call of Duty) has 0 players → each appid is checked on its Steam store page before the list is frozen.
- **Terms.** Neither source has an open licence; the instructor's answer goes in `config.R`.
- **Short window.** Player history starts with the first poll: about four weeks. If no game is discounted in that
  window, Q4 becomes a comparison of discounted and full-price games on the same days.
- **A fixed list.** The 60 games favour long-running free-to-play titles; findings do not describe Steam as a whole.

## 5. Table plan (preliminary)

| Table | Grain (one row is…) | Key | Built from | Owner |
|---|---|---|---|---|
| `games` | one game in the fixed list | `appid` | steamspy_games (first pull) | Mark Buban |
| `player_counts` | one game × poll | `appid`, `pulled_at_utc` | player_counts | Mark Buban, Riwaz Silwal |
| `price_snapshots` | one game × day | `appid`, `price_date` | steamspy_games (daily pulls) | Ryan Burton |

**Links:** `player_counts` and `price_snapshots` each link to `games` through `appid`.

**Possible changes at M2:** a `game_genres` table (one row per game × genre) if Q1 needs genres counted separately; an
`on_discount` column in `player_counts` from `price_snapshots`, for Q4.
