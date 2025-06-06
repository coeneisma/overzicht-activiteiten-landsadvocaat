#!/usr/bin/env Rscript

# Laad benodigde libraries
library(readxl)
library(dplyr)
library(tidyr)

# Pad naar Excel bestand
excel_path <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

# Controleer of bestand bestaat
if (!file.exists(excel_path)) {
  stop("Excel bestand niet gevonden: ", excel_path)
}

# Lees alle sheets
sheets <- excel_sheets(excel_path)
cat("Gevonden sheets:", paste(sheets, collapse = ", "), "\n\n")

# Analyseer elke sheet
for (sheet in sheets) {
  cat("=== Sheet:", sheet, "===\n")
  
  # Lees de sheet
  df <- read_excel(excel_path, sheet = sheet)
  
  # Basis info
  cat("Aantal rijen:", nrow(df), "\n")
  cat("Aantal kolommen:", ncol(df), "\n")
  cat("\nKolommen:\n")
  
  # Toon kolom info
  col_info <- data.frame(
    Kolom = names(df),
    Type = sapply(df, class),
    NietLeeg = sapply(df, function(x) sum(!is.na(x) & x != "")),
    Voorbeelden = sapply(df, function(x) {
      unieke <- unique(x[!is.na(x) & x != ""])
      if (length(unieke) > 5) {
        paste(head(unieke, 5), collapse = " | ")
      } else {
        paste(unieke, collapse = " | ")
      }
    })
  )
  
  print(col_info)
  cat("\n")
  
  # Toon eerste paar rijen
  cat("Eerste 5 rijen:\n")
  print(head(df, 5))
  cat("\n\n")
}

# Lees database structuur voor vergelijking
source("utils/database.R")
con <- get_db_connection()

# Haal zaken tabel structuur op
cat("=== Database Structuur (zaken tabel) ===\n")
zaken_cols <- dbListFields(con, "zaken")
cat("Kolommen in zaken tabel:\n")
print(zaken_cols)

# Sluit database verbinding
dbDisconnect(con)