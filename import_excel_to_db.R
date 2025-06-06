#!/usr/bin/env Rscript

# Import Excel data naar Landsadvocaat Database
# ============================================

library(readxl)
library(dplyr)
library(DBI)
library(RSQLite)
library(lubridate)

# Bron functies
source("utils/database.R")

# Configuratie
EXCEL_PATH <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

#' Converteer Excel data naar database formaat
prepare_zaak_data <- function(excel_row, status = "lopend", jaar = NULL) {
  
  # Basis velden
  zaak_id <- paste0("WJZ-LA-", excel_row$`WJZ/LA/ 2010/`[[1]])
  
  # Datum aanmaak - als jaar bekend is, gebruik 1 januari van dat jaar
  datum_aanmaak <- if (!is.null(jaar)) {
    as.Date(paste0(jaar, "-01-01"))
  } else {
    Sys.Date()  # Fallback naar vandaag
  }
  
  # LA Budget - converteer ja/nee naar 1/0
  la_budget <- tolower(excel_row$`LA Budget WJZ`[[1]]) %in% c("ja", "yes", "1")
  
  # Maak zaak data
  zaak_data <- data.frame(
    zaak_id = zaak_id,
    datum_aanmaak = datum_aanmaak,
    zaakaanduiding = excel_row$Zaakaanduiding[[1]],
    aanvragende_directie = excel_row$`Aanvragende directie`[[1]],
    wjz_mt_lid = excel_row$`WJZ-MT-lid`[[1]],
    la_budget_wjz = if (la_budget) 1 else 0,
    type_dienst = if ("advies/verpl vertegenw/bestuursR" %in% names(excel_row)) {
      excel_row$`advies/verpl vertegenw/bestuursR`[[1]]
    } else {
      NA
    },
    status_zaak = status,
    opmerkingen = if ("advocaat =Budget beleid" %in% names(excel_row)) {
      excel_row$`advocaat =Budget beleid`[[1]]
    } else {
      NA
    }
  )
  
  # Verwijder NA waarden
  zaak_data <- zaak_data[!is.na(zaak_data)]
  
  return(zaak_data)
}

#' Import zaken uit Excel sheet
import_sheet <- function(con, sheet_name, status = "lopend", skip_rows = 1) {
  
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
  
  for (i in 1:nrow(df)) {
    tryCatch({
      zaak_data <- prepare_zaak_data(df[i, ], status = status, jaar = jaar)
      
      # Check of zaak al bestaat
      existing <- dbGetQuery(con, 
        "SELECT COUNT(*) as count FROM zaken WHERE zaak_id = ?",
        params = list(zaak_data$zaak_id)
      )
      
      if (existing$count == 0) {
        # Voeg zaak toe
        voeg_zaak_toe(zaak_data = zaak_data, gebruiker = "excel_import")
        success_count <- success_count + 1
      } else {
        cat("  - Zaak", zaak_data$zaak_id, "bestaat al, overgeslagen\n")
      }
      
    }, error = function(e) {
      cat("  - FOUT bij rij", i, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\nResultaat: ", success_count, " zaken geïmporteerd, ", 
      error_count, " fouten\n")
  
  return(list(success = success_count, errors = error_count))
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
  
  # Lees beschikbare sheets
  sheets <- excel_sheets(EXCEL_PATH)
  cat("\nBeschikbare sheets:", paste(sheets, collapse = ", "), "\n\n")
  
  # Import lopende en slapende zaken
  if ("Lopende en slapende zaken" %in% sheets) {
    import_sheet(con, "Lopende en slapende zaken", status = "lopend")
  }
  
  # Import afgesloten zaken
  if ("Afgesloten zaken" %in% sheets) {
    import_sheet(con, "Afgesloten zaken", status = "afgesloten")
  }
  
  # Import jaar sheets (laatste 3 jaar)
  jaar_sheets <- sheets[grepl("^20\\d{2}$", sheets)]
  jaar_sheets <- tail(jaar_sheets, 3)  # Laatste 3 jaar
  
  for (sheet in jaar_sheets) {
    import_sheet(con, sheet, status = "lopend", skip_rows = 0)
  }
  
  # Toon totaal aantal zaken in database
  total_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM zaken")
  cat("\n\nTotaal aantal zaken in database:", total_count$count, "\n")
  
  # Sluit database
  dbDisconnect(con)
  
  cat("\nImport voltooid!\n")
}

# Voer import uit indien direct aangeroepen
if (!interactive()) {
  main()
}