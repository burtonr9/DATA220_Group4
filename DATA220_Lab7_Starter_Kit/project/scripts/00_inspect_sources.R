# scripts/00_inspect_sources.R -- P3: what is in each source? (given: just run it)
# Reads: the files listed in SOURCES (config.R)
# Writes: output/profile_<source>.csv -- one row per column: what the values look like,
#         how many are missing, how many different values, examples.
# Then use the inspect functions on the columns that look suspicious, e.g.
#   d <- read_any_file("data/raw/sales/sales_2026-10.csv")
#   find_text_variants(d, "Item");  show_date_formats(d, "Date");  count_values(d, "Item")
source("config.R")
source("R/load_functions.R")
make_folders()
log_msg("00_inspect: start")

for (name in names(SOURCES)) {
  s <- SOURCES[[name]]
  if (name %in% c("steamspy_games", "player_counts")) next
  if (!file.exists(s$file)) {
    log_msg(name, ": no file at ", s$file, " -- put a sample in data/raw/ (P2)")
    next
  }
  # a folder of files: profile every file in it (problems often start in one month)
  files <- s$file
  if (dir.exists(s$file)) files <- list.files(s$file, full.names = TRUE)
  for (f in files) {
    p <- profile_raw_file(f)
    print(p, right = FALSE)
    part <- ""
    if (length(files) > 1) part <- paste0("_", tools::file_path_sans_ext(basename(f)))
    save_csv(p, paste0("output/profile_", name, part, ".csv"))
  }
}
# Inspect the two JSON record folders as whole tables
# Inspect the two JSON record folders
for (name in c("steamspy_games", "player_counts")) {
  folder <- SOURCES[[name]]$file
  
  d <- read_record_folder(folder)
  
  p <- bind_rows(lapply(names(d), function(col) {
    v <- d[[col]]
    filled <- v[!is.na(v) & str_squish(v) != ""]
    
    data.frame(
      column = col,
      looks_like = guess_type(filled),
      missing = length(v) - length(filled),
      distinct = length(unique(filled)),
      examples = show_examples(filled)
    )
  }))
  
  print(p, right = FALSE)
  save_csv(p, paste0("output/profile_", name, ".csv"))
}
log_msg("00_inspect: done -- now write what you found as # FOUND: lines in config.R")
