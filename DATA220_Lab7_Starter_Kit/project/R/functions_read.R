# R/functions_read.R -- getting raw files into R without changing them.
# Functions: read_raw_csv(), read_many_csv(), read_any_file(), download_csv(), check_columns()


# ============================================================================
# read_raw_csv(path, na = c("", "NA", "N/A"))
# LEVEL     core
# PURPOSE   Read ONE CSV file exactly as delivered: every column stays text and
#           every column name stays as written. Nothing is converted yet --
#           converting is a cleaning decision you make later.
# USE WHEN  reading any raw CSV file.
# ARGUMENTS path : the file
#           na   : text that means "missing" in this source
# RETURNS   a data frame of text columns
# EXAMPLE
#   stations <- read_raw_csv("data/raw/stations.csv")
#   #> read 2 rows x 5 columns from data/raw/stations.csv
#   stations
#   #>   station_code climate_id       station_name elevation_m   site_type
#   #> 1        EDM-A  CLASS-A01 EDMONTON STATION A         723     airport
#   #> 2        EDM-B  CLASS-B02 EDMONTON STATION B         671 city centre
# HOW THE CODE WORKS
#   1. file.exists() + stop(): a clear message if the path is wrong (Week 9, Week 5).
#   2. read.csv() with na.strings (Week 7) and two more settings:
#      colClasses = "character" keeps every value as text (so "007" stays "007"),
#      check.names = FALSE keeps names like "Max Temp (°C)" exactly as written.
#   3. Before reading, readLines() takes the file as lines of text and validUTF8() checks
#      that every line is proper UTF-8 (both new). A file saved by Excel as
#      "CSV (Comma delimited)" with accents fails this test; stopping here is better than
#      read.csv() silently reading only part of it. fileEncoding = "UTF-8" then reads
#      accents correctly.
# ============================================================================
read_raw_csv <- function(path, na = c("", "NA", "N/A")) {
  if (!file.exists(path)) stop("File not found: ", path)
  if (!all(validUTF8(readLines(path, warn = FALSE)))) {
    stop(path, " is not UTF-8 text. In Excel use Save As > 'CSV UTF-8', then try again.")
  }
  df <- read.csv(path, na.strings = na, colClasses = "character", check.names = FALSE,
                 fileEncoding = "UTF-8")
  log_msg("read ", nrow(df), " rows x ", ncol(df), " columns from ", path)
  df
}


# ============================================================================
# read_many_csv(folder, rename = NULL, expected = NULL)
# LEVEL     core
# PURPOSE   Read EVERY .csv file in a folder (e.g. one file per month) and stack
#           them into one table, checking each file before stacking.
# USE WHEN  a source comes as several files with the same columns.
# ARGUMENTS folder   : the folder that holds the files
#           rename   : optional c(old = "new") for a column that one file names differently
#           expected : optional column names every file must have
# RETURNS   one data frame with every row, plus a column source_file
# EXAMPLE
#   w <- read_many_csv("data/raw/weather", rename = c("Snow (cm)" = "Total Snow (cm)"))
#   #> read 62 rows x 19 columns from data/raw/weather/weather_2026-01.csv
#   #> read 58 rows x 19 columns from data/raw/weather/weather_2026-02.csv
#   #> read 62 rows x 19 columns from data/raw/weather/weather_2026-03.csv
#   #>   renamed column 'Snow (cm)' -> 'Total Snow (cm)'
#   #> combined 3 files -> 182 rows
#   table(w$source_file)
#   #> 
#   #> weather_2026-01.csv weather_2026-02.csv weather_2026-03.csv 
#   #>                  62                  58                  62 
# HOW THE CODE WORKS
#   1. list.files(..., full.names = TRUE) finds the files (Week 8).
#   2. A for loop reads each one with read_raw_csv(), renames, checks the columns with
#      check_columns(), and records the file name with basename() (Weeks 5, 8).
#   3. Each file's data frame is kept in a list; bind_rows() stacks them (Week 8).
#      Checking BEFORE stacking matters: bind_rows() would fill a missing column with NA
#      and hide the problem (Week 8).
# ============================================================================
read_many_csv <- function(folder, rename = NULL, expected = NULL) {
  files <- list.files(folder, pattern = "\\.csv$", full.names = TRUE)
  if (length(files) == 0) stop("No .csv files in ", folder)
  parts <- list()
  for (f in files) {
    df <- read_raw_csv(f)
    if (!is.null(rename))   df <- rename_columns(df, rename)
    if (!is.null(expected)) check_columns(df, expected, basename(f))
    df$source_file <- basename(f)
    parts[[basename(f)]] <- df
  }
  out <- bind_rows(parts)
  log_msg("combined ", length(files), " files -> ", nrow(out), " rows")
  out
}


# ============================================================================
# read_any_file(path, sheet = 1)
# LEVEL     project
# PURPOSE   Read a CSV, Excel, JSON or tab-separated file with every column as
#           text, so you can look at a new source before deciding anything.
# USE WHEN  a source is not a plain CSV file.
# ARGUMENTS path  : the file (.csv, .xlsx, .xls, .json, .tsv, .txt)
#           sheet : Excel only -- the sheet number or name
# RETURNS   a data frame of text columns
# EXAMPLE
#   counters <- read_any_file("data/raw/counters.csv")
#   #> read 4 rows x 4 columns from data/raw/counters.csv
#   names(counters)
#   #> [1] "counter_id" "location"   "trail_type" "installed" 
# HOW THE CODE WORKS
#   1. tools::file_ext() gives the ending of the file name (new: e.g. "xlsx").
#   2. if / else if picks the reader (Week 5): read_raw_csv() for CSV;
#      readxl::read_excel() for Excel (new: the readxl package reads workbooks);
#      jsonlite::fromJSON() for JSON (new here; Week 10 explains JSON);
#      read.delim() for tab-separated text (read.csv()'s partner).
#   3. A for loop turns every column into text with as.character() (Weeks 5, 7).
# ============================================================================
read_any_file <- function(path, sheet = 1) {
  if (!file.exists(path)) stop("File not found: ", path)
  type <- str_to_lower(tools::file_ext(path))
  if (type == "csv") {
    return(read_raw_csv(path))
  } else if (type %in% c("xlsx", "xls")) {
    df <- readxl::read_excel(path, sheet = sheet, col_types = "text")
  } else if (type == "json") {
    df <- jsonlite::fromJSON(path, flatten = TRUE)
    if (!is.data.frame(df)) {
      stop(path, ": the records are inside another field of this JSON file. Ask your instructor, or wait for Lab 8.")
    }
  } else if (type %in% c("tsv", "txt")) {
    df <- read.delim(path, colClasses = "character", check.names = FALSE, fileEncoding = "UTF-8")
  } else {
    stop("Cannot read .", type, " files. Save the data as CSV, or ask your instructor.")
  }
  df <- as.data.frame(df)
  for (col in names(df)) {
    df[[col]] <- as.character(df[[col]])
  }
  log_msg("read ", nrow(df), " rows x ", ncol(df), " columns from ", path)
  df
}


# ============================================================================
# download_csv(url, dest)
# LEVEL     project
# PURPOSE   Download a file from the web into data/raw/ and keep it untouched.
# USE WHEN  a portal gives you an "Export CSV" link. (Lab 8 replaces this with API requests.)
# ARGUMENTS url  : the address of the file
#           dest : where to save it, e.g. "data/raw/requests_2026.csv"
# RETURNS   dest, invisibly
# EXAMPLE
#   # download_csv("https://data.example.org/export.csv", "data/raw/example.csv")   (not run)
# HOW THE CODE WORKS
#   1. dir.create() makes sure the folder exists (Week 8).
#   2. download.file() copies the file from the web to your computer (new);
#      mode = "wb" copies it byte for byte, so nothing is changed on the way.
#   3. log_msg() records where it came from (Week 8).
# ============================================================================
download_csv <- function(url, dest) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  download.file(url, dest, mode = "wb", quiet = TRUE)
  log_msg("downloaded ", url, " -> ", dest)
  invisible(dest)
}


# ============================================================================
# check_columns(df, expected, name = "table")
# LEVEL     project
# PURPOSE   Stop if any column you rely on is missing (the Week 8 check).
# USE WHEN  right after reading a file, before any step that uses those columns.
# ARGUMENTS df       : a data frame
#           expected : the column names it must have
#           name     : a name for the message
# RETURNS   TRUE invisibly; stops with the missing names otherwise
# EXAMPLE
#   d <- data.frame(id = 1:2, day = c("Mon", "Tue"))
#   check_columns(d, c("id", "day"), "d")
#   try(check_columns(d, c("id", "trips"), "d"))
#   #> Error in check_columns(d, c("id", "trips"), "d") : 
#   #>   d is missing column(s): trips
# HOW THE CODE WORKS
#   1. setdiff(expected, names(df)) lists the expected names that are not there (Week 8).
#   2. If that list is not empty, stop() names them (Week 5); paste(collapse =) joins them (Week 8).
# ============================================================================
check_columns <- function(df, expected, name = "table") {
  missing <- setdiff(expected, names(df))
  if (length(missing) > 0) {
    stop(name, " is missing column(s): ", paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

read_one_record <- function(f) {
  x <- jsonlite::fromJSON(f)
  if (!is.null(x$response)) x <- x$response        # player-count files: the record is inside "response"
  for (n in names(x)) {
    v <- x[[n]]
    if (length(v) == 0) {
      x[[n]] <- NA                                   # null or [] -> NA (missing, not 0)
    } else if (!is.null(names(v))) {
      x[[n]] <- paste(names(v), collapse = ", ")     # tags {"MOBA": 20000, ...} -> "MOBA, ..."
    } else {
      x[[n]] <- paste(v, collapse = ", ")
    }
  }
  df <- as.data.frame(x)
  df$source_file <- basename(f)                      # which file each row came from
  df
}

read_record_folder <- function(folder) {
  files <- list.files(folder, pattern = "\\.json$", full.names = TRUE)
  if (length(files) == 0) stop("No .json files in ", folder)
  parts <- list()
  for (f in files) parts[[length(parts) + 1]] <- read_one_record(f)
  bind_rows(parts)
}
