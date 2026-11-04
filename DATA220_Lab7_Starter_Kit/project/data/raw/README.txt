# Raw Data Sources

This folder contains original raw data samples from Steam and SteamSpy for the DATA 220 project.

## 1. SteamSpy Game Details

- Folder: `steamspy_games/`
- Source: SteamSpy API
- Data: JSON responses containing information about selected Steam games.
- Collection method: API requests using individual Steam App IDs.
- Sample files: Original JSON responses for selected games.

## 2. Steam Player Counts

- Folder: `player_counts/`
- Source: Steam Web API (GetNumberOfCurrentPlayers)
- Data: JSON responses containing player count information for selected Steam games.
- Collection method: API requests using individual Steam App IDs.
- Sample files: Original JSON responses for selected games.

## 3. Steam Most Played Chart

- File: `most_played.json`
- Source: Steam Web API (ISteamChartsService/GetMostPlayedGames)
- Data: the top 100 games by concurrent players, saved once on November 4, 2026. This file is the frozen game list.
- Collection method: `scripts/fetch_store_details.R`

## 4. Steam Store Details

- Folder: `store_details/` (one file per game: `store_<appid>.json`)
- Source: Steam store (`store.steampowered.com/api/appdetails`, cc=ca)
- Data: type, name, free or paid, price and discount (CAD cents), genres, release date for all 100 games.
- Collection method: `scripts/fetch_store_details.R`

## Data Handling

The files in this folder are original samples from the API. They have not been edited or converted into another format.

The full datasets are stored separately. The source URLs and retrieval information are documented in `config.R`.

These raw samples are included to document the original data sources and support reproducible data processing.