#!/usr/bin/env Rscript

# Import Excel data naar Landsadvocaat Database - Versie 2
# =========================================================

library(readxl)
library(dplyr)
library(DBI)
library(RSQLite)
library(lubridate)

# Bron functies
source("utils/database.R")

# Configuratie
EXCEL_PATH <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

#' Import zaken uit Excel sheet - Directe database insert
import_sheet_direct <- function(con, sheet_name, status = "lopend", skip_rows = 1) {
  
  cat("\nImporteren van sheet:", sheet_name, "\n")
  cat(paste(rep("-", 50), collapse=""), "\n")
  
  # Lees Excel data
  df <- read_excel(EXCEL_PATH, sheet = sheet_name, skip = skip_rows)
  
  # Filter lege kolommen en rijen
  df <- df[, colSums(!is.na(df)) > 0]
  df <- df[!is.na(df[[1]]), ]  # Verwijder rijen zonder zaak nummer
  
  # Filter ongeldige zaak nummers
  if ("WJZ/LA/ 2010/" %in% names(df)) {
    df <- df[!df$`WJZ/LA/ 2010/` %in% c("***", NA, ""), ]
  } else if (grepl("^20\\d{2}$", sheet_name)) {
    # Voor jaar sheets, gebruik eerste kolom
    col_name <- names(df)[1]
    df <- df[!df[[col_name]] %in% c("***", NA, ""), ]
  }
  
  cat("Gevonden zaken:", nrow(df), "\n")
  
  # Bepaal jaar uit sheet naam
  jaar <- NULL
  if (grepl("^20\\d{2}$", sheet_name)) {
    jaar <- as.numeric(sheet_name)
  }
  
  # Importeer elke zaak
  success_count <- 0
  error_count <- 0
  skipped_count <- 0
  
  for (i in 1:nrow(df)) {
    tryCatch({
      row <- df[i, ]
      
      # Bepaal zaak_id
      zaak_id <- if ("WJZ/LA/ 2010/" %in% names(row)) {
        paste0("WJZ-LA-", row$`WJZ/LA/ 2010/`)
      } else if (grepl("WJZ/LA/", names(row)[1])) {
        paste0("WJZ-LA-", row[[1]])
      } else {
        paste0("WJZ-LA-", row[[1]])
      }
      
      # Check of zaak al bestaat
      existing <- dbGetQuery(con, 
        "SELECT COUNT(*) as count FROM zaken WHERE zaak_id = ?",
        params = list(zaak_id)
      )
      
      if (existing$count > 0) {
        skipped_count <- skipped_count + 1
        next
      }
      
      # Bepaal datum
      datum_aanmaak <- if (!is.null(jaar)) {
        as.character(as.Date(paste0(jaar, "-01-01")))
      } else if ("Datum" %in% names(row) && !is.na(row$Datum)) {
        as.character(as.Date(row$Datum))
      } else {
        as.character(Sys.Date())
      }
      
      # LA Budget - converteer ja/nee naar numeric
      la_budget_val <- NULL
      if ("LA Budget WJZ" %in% names(row)) {
        budget_text <- tolower(as.character(row$`LA Budget WJZ`))
        if (budget_text %in% c("ja", "yes", "1")) {
          la_budget_val <- 1
        } else if (budget_text %in% c("nee", "no", "0")) {
          la_budget_val <- 0
        }
      }
      
      # Bereid data voor insert
      insert_data <- data.frame(
        zaak_id = zaak_id,
        datum_aanmaak = datum_aanmaak,
        zaakaanduiding = if ("Zaakaanduiding" %in% names(row)) as.character(row$Zaakaanduiding) else NA,
        aanvragende_directie = if ("Aanvragende directie" %in% names(row)) as.character(row$`Aanvragende directie`) else NA,
        wjz_mt_lid = if ("WJZ-MT-lid" %in% names(row)) as.character(row$`WJZ-MT-lid`) else NA,
        la_budget_wjz = la_budget_val,
        type_dienst = if ("advies/verpl vertegenw/bestuursR" %in% names(row)) as.character(row$`advies/verpl vertegenw/bestuursR`) else NA,
        status_zaak = status,
        opmerkingen = if ("advocaat =Budget beleid" %in% names(row)) as.character(row$`advocaat =Budget beleid`) else NA,
        aangemaakt_door = "excel_import",
        laatst_gewijzigd = as.character(Sys.time()),
        gewijzigd_door = "excel_import",
        stringsAsFactors = FALSE
      )
      
      # Verwijder kolommen met alleen NA
      insert_data <- insert_data[, !sapply(insert_data, function(x) all(is.na(x)))]
      
      # Insert in database
      dbAppendTable(con, "zaken", insert_data)
      success_count <- success_count + 1
      
    }, error = function(e) {
      cat("  - FOUT bij rij", i, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\nResultaat:", success_count, "geïmporteerd,", 
      skipped_count, "overgeslagen (bestonden al),",
      error_count, "fouten\n")
  
  return(list(success = success_count, skipped = skipped_count, errors = error_count))
}

#' Hoofdfunctie voor import
main <- function() {
  
  cat("=== EXCEL IMPORT NAAR DATABASE ===\n")
  cat("Excel bestand:", EXCEL_PATH, "\n")
  
  # Controleer of Excel bestand bestaat
  if (!file.exists(EXCEL_PATH)) {
    stop("Excel bestand niet gevonden!")
  }
  
  # Maak database verbinding
  con <- get_db_connection()
  on.exit(dbDisconnect(con))
  
  # Lees beschikbare sheets
  sheets <- excel_sheets(EXCEL_PATH)
  cat("\nBeschikbare sheets:", paste(sheets, collapse = ", "), "\n\n")
  
  # Houdt totalen bij
  totals <- list(success = 0, skipped = 0, errors = 0)
  
  # Import lopende en slapende zaken
  if ("Lopende en slapende zaken" %in% sheets) {
    result <- import_sheet_direct(con, "Lopende en slapende zaken", status = "lopend")
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Import afgesloten zaken
  if ("Afgesloten zaken" %in% sheets) {
    result <- import_sheet_direct(con, "Afgesloten zaken", status = "afgesloten")
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Import jaar sheets (laatste 3 jaar)
  jaar_sheets <- sheets[grepl("^20\\d{2}$", sheets)]
  jaar_sheets <- tail(jaar_sheets, 3)  # Laatste 3 jaar
  
  for (sheet in jaar_sheets) {
    result <- import_sheet_direct(con, sheet, status = "lopend", skip_rows = 0)
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Toon totaal aantal zaken in database
  total_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM zaken")
  cat("\n\n=== IMPORT SAMENVATTING ===\n")
  cat("Totaal geïmporteerd:", totals$success, "\n")
  cat("Totaal overgeslagen:", totals$skipped, "\n")
  cat("Totaal fouten:", totals$errors, "\n")
  cat("\nTotaal aantal zaken in database:", total_count$count, "\n")
  
  cat("\nImport voltooid!\n")
}

# Voer import uit indien direct aangeroepen
if (!interactive()) {
  main()
}