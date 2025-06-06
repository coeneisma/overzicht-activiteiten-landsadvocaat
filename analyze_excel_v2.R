#!/usr/bin/env Rscript

# Laad benodigde libraries
library(readxl)
library(dplyr)

# Pad naar Excel bestand
excel_path <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

# Controleer of bestand bestaat
if (!file.exists(excel_path)) {
  stop("Excel bestand niet gevonden: ", excel_path)
}

# Lees alle sheets
sheets <- excel_sheets(excel_path)
cat("Gevonden sheets:", paste(sheets, collapse = ", "), "\n\n")

# Focus op de hoofdsheets
main_sheets <- c("Lopende en slapende zaken", "Afgesloten zaken")

for (sheet in main_sheets) {
  cat("\n=== Analyseer sheet:", sheet, "===\n")
  
  # Lees eerste 10 rijen om structuur te bekijken
  df_preview <- read_excel(excel_path, sheet = sheet, n_max = 10)
  
  cat("Aantal kolommen:", ncol(df_preview), "\n")
  cat("Kolomnamen (eerste rij):\n")
  print(names(df_preview))
  
  # Probeer data vanaf een bepaalde rij te lezen (skip headers)
  # Meestal begint de echte data na een paar header rijen
  for (skip_rows in c(0, 1, 2, 3, 4, 5)) {
    cat("\n--- Probeer met skip =", skip_rows, "---\n")
    tryCatch({
      df_test <- read_excel(excel_path, sheet = sheet, skip = skip_rows, n_max = 5)
      
      # Filter lege kolommen
      df_test <- df_test[, colSums(!is.na(df_test)) > 0]
      
      if (ncol(df_test) > 0 && nrow(df_test) > 0) {
        cat("Gevonden kolommen:\n")
        for (col in names(df_test)) {
          cat("  -", col, "\n")
        }
        cat("\nEerste rij data:\n")
        print(df_test[1,])
      }
    }, error = function(e) {
      cat("Fout bij skip =", skip_rows, ":", e$message, "\n")
    })
  }
}

# Analyseer jaar sheets
cat("\n\n=== Jaar sheets analyse ===\n")
year_sheets <- sheets[grepl("^20[0-9]{2}$", sheets)]

for (sheet in year_sheets[1:2]) {  # Bekijk eerste 2 jaar sheets
  cat("\n--- Sheet:", sheet, "---\n")
  
  tryCatch({
    df <- read_excel(excel_path, sheet = sheet, skip = 1)
    
    # Filter lege kolommen
    df <- df[, colSums(!is.na(df)) > 0]
    
    cat("Aantal rijen:", nrow(df), "\n")
    cat("Kolommen:", paste(names(df), collapse = ", "), "\n")
    
    # Toon eerste rij
    if (nrow(df) > 0) {
      cat("\nEerste rij:\n")
      print(df[1,])
    }
  }, error = function(e) {
    cat("Fout:", e$message, "\n")
  })
}

# Database structuur voor vergelijking
cat("\n\n=== Database Structuur ===\n")
source("utils/database.R")
con <- get_db_connection()

# Haal zaken tabel info op
zaken_info <- dbGetQuery(con, "PRAGMA table_info(zaken)")
cat("\nKolommen in 'zaken' tabel:\n")
for (i in 1:nrow(zaken_info)) {
  cat(sprintf("  - %s (%s)\n", zaken_info$name[i], zaken_info$type[i]))
}

# Haal dropdown opties op voor vergelijking
cat("\nDropdown categorieën:\n")
dropdown_cats <- dbGetQuery(con, "SELECT DISTINCT categorie FROM dropdown_categories")
print(dropdown_cats$categorie)

dbDisconnect(con)