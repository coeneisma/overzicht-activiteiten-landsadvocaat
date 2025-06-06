#!/usr/bin/env Rscript

# Import Excel data naar Landsadvocaat Database - Versie 3
# =========================================================
# Verbeterde zaak ID en datum verwerking

library(readxl)
library(dplyr)
library(DBI)
library(RSQLite)
library(lubridate)

# Bron functies
source("utils/database.R")

# Configuratie
EXCEL_PATH <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

# Directory mapping van Excel afkortingen naar database waarden
DIRECTIE_MAPPING <- list(
  # Basis directies
  "PO" = "onderwijspersoneelenprimaironderwijs",
  "VO" = "onderwijsprestatiesenvoortgezetonderwijs",
  "BVE" = "middelbaarberoepsonderwijs",
  "MBO" = "middelbaarberoepsonderwijs",
  "HO&S" = "hogeronderwijsenstudiefinanciering",
  "HOenS" = "hogeronderwijsenstudiefinanciering",
  "HO" = "hogeronderwijsenstudiefinanciering",
  "DUO-G" = "dienstuitvoeringonderwijs",
  "DUO" = "dienstuitvoeringonderwijs",
  "FEZ" = "financieeleconomischezaken",
  "WJZ" = "wetgevingenjuridischezaken",
  "BOA" = "bestuursondersteuningenadvies",
  "MenC" = "mediaencreatieveindustrie",
  "communicatie" = "mediaencreatieveindustrie",
  "EK" = "erfgoedenkunsten",
  "EGI" = "erfgoedenkunsten",
  "Kennis" = "kennisstrategie",
  "Onderwijsinspectie" = "inspectievanhetonderwijs",
  "IvhO" = "inspectievanhetonderwijs",
  "Inspectie" = "inspectievanhetonderwijs",
  "K&S" = "kennisstrategie",
  "IB" = "internationaalbeleid",
  "OWB" = "onderzoekenwetenschapsbeleid",
  "O&B" = "organisatieenbedrijfsvoering"
)

#' Detecteer zaak ID pattern en extract informatie
#' @param value Waarde uit Excel cel
#' @param current_context Huidige sectie context
#' @return List met type, zaak_id, jaar, en nieuwe context
detect_zaak_pattern <- function(value, current_context = list(year = "2010", prefix = "WJZ-LA")) {
  value_str <- trimws(as.character(value))
  
  if (is.na(value) || value_str == "" || value_str == "***") {
    return(NULL)
  }
  
  # Pattern 1: 2017-004 (jaar-nummer formaat)
  if (grepl("^\\d{4}-\\d{3}$", value_str)) {
    jaar <- substr(value_str, 1, 4)
    return(list(
      type = "year_number",
      zaak_id = paste0("WJZ-LA-", value_str),
      jaar = jaar,
      context = list(year = jaar, prefix = "WJZ-LA")
    ))
  }
  
  # Pattern 2: WJZ-LA-2015 (sectie header)
  if (grepl("^WJZ-LA-\\d{4}$", value_str)) {
    jaar <- substr(value_str, 8, 11)
    return(list(
      type = "section_header",
      zaak_id = NULL, # Dit is geen zaak, maar een sectie header
      jaar = jaar,
      context = list(year = jaar, prefix = "WJZ-LA")
    ))
  }
  
  # Pattern 3: Alleen nummer (100, 101, 204) - gebruik huidige context
  if (grepl("^\\d+$", value_str)) {
    zaak_id <- paste0(current_context$prefix, "-", current_context$year, "-", sprintf("%03d", as.numeric(value_str)))
    return(list(
      type = "number_only",
      zaak_id = zaak_id,
      jaar = current_context$year,
      context = current_context
    ))
  }
  
  # Fallback: gebruik waarde as-is
  return(list(
    type = "fallback",
    zaak_id = paste0("WJZ-LA-", value_str),
    jaar = current_context$year,
    context = current_context
  ))
}

#' Parse datum met verschillende strategieën
#' @param row Excel rij data
#' @param zaak_info Zaak informatie van detect_zaak_pattern
#' @return Datum string (YYYY-MM-DD)
parse_datum <- function(row, zaak_info) {
  # Prioriteit 1: Excel "Datum" kolom
  if ("Datum" %in% names(row) && !is.na(row$Datum)) {
    tryCatch({
      return(as.character(as.Date(row$Datum)))
    }, error = function(e) {
      cat("  - Datum conversie fout:", e$message, "\n")
    })
  }
  
  # Prioriteit 2: Jaar uit zaak pattern
  if (!is.null(zaak_info) && !is.null(zaak_info$jaar)) {
    return(as.character(as.Date(paste0(zaak_info$jaar, "-01-01"))))
  }
  
  # Fallback: huidige datum
  return(as.character(Sys.Date()))
}

#' Map Excel directie afkorting naar database waarde
map_directie <- function(excel_value) {
  if (is.na(excel_value) || excel_value == "" || toupper(excel_value) == "NA") {
    return(list(directie = "NIET_INGESTELD", contactpersoon = NA))
  }
  
  excel_value_clean <- trimws(as.character(excel_value))
  directie_gevonden <- NA
  contactpersoon <- NA
  
  # Split op slash voor combinaties en persoonsnamen
  parts <- strsplit(excel_value_clean, "/")[[1]]
  parts <- trimws(parts)
  
  for (part in parts) {
    part_upper <- toupper(part)
    
    # Zoek in mapping (case-insensitive)
    for (afkorting in names(DIRECTIE_MAPPING)) {
      if (toupper(afkorting) == part_upper) {
        if (is.na(directie_gevonden)) {
          directie_gevonden <- DIRECTIE_MAPPING[[afkorting]]
        }
        break
      }
    }
    
    # Als het geen directie mapping is, check of het een persoonsnaam kan zijn
    if (!part_upper %in% toupper(names(DIRECTIE_MAPPING))) {
      if (grepl(" ", part) || grepl("-", part) || 
          (nchar(part) > 3 && !part_upper %in% c("G", "(G)", "GS", "DG", "SG", "MT"))) {
        if (is.na(contactpersoon)) {
          contactpersoon <- part
        } else {
          contactpersoon <- paste(contactpersoon, part, sep = ", ")
        }
      }
    }
  }
  
  # Als geen directie gevonden, gebruik fallback
  if (is.na(directie_gevonden)) {
    directie_gevonden <- "NIET_INGESTELD"
    cat("  - Onbekende directie afkorting:", excel_value_clean, "-> NIET_INGESTELD\n")
  }
  
  return(list(
    directie = directie_gevonden,
    contactpersoon = if(is.na(contactpersoon)) NA else contactpersoon,
    originele_waarde = excel_value_clean
  ))
}

#' Import lopende en slapende zaken met complexe sectie verwerking
import_lopende_slapende <- function(con) {
  cat("\nImporteren van sheet: Lopende en slapende zaken\n")
  cat(paste(rep("-", 50), collapse=""), "\n")
  
  # Lees Excel data
  df <- read_excel(EXCEL_PATH, sheet = "Lopende en slapende zaken", skip = 1)
  
  # Filter lege kolommen
  df <- df[, colSums(!is.na(df)) > 0]
  
  # Verwijder volledig lege rijen
  df <- df[!is.na(df[[1]]), ]
  
  # Filter *** rijen
  df <- df[!df[[1]] %in% c("***", NA, ""), ]
  
  cat("Gevonden records:", nrow(df), "\n")
  
  # Initialiseer context tracking
  current_context <- list(year = "2010", prefix = "WJZ-LA")
  success_count <- 0
  error_count <- 0
  skipped_count <- 0
  
  for (i in 1:nrow(df)) {
    tryCatch({
      row <- df[i, ]
      
      # Detecteer zaak pattern
      zaak_info <- detect_zaak_pattern(row[[1]], current_context)
      
      if (is.null(zaak_info)) {
        skipped_count <- skipped_count + 1
        next
      }
      
      # Update context als we een sectie header hebben
      if (zaak_info$type == "section_header") {
        current_context <- zaak_info$context
        cat("  - Nieuwe sectie gedetecteerd: jaar", zaak_info$jaar, "\n")
        skipped_count <- skipped_count + 1
        next
      }
      
      # Als we geen zaak_id hebben, skip
      if (is.null(zaak_info$zaak_id)) {
        skipped_count <- skipped_count + 1
        next
      }
      
      zaak_id <- zaak_info$zaak_id
      
      # Update context voor volgende records
      current_context <- zaak_info$context
      
      # Check of zaak al bestaat
      existing <- dbGetQuery(con, 
        "SELECT COUNT(*) as count FROM zaken WHERE zaak_id = ?",
        params = list(zaak_id)
      )
      
      if (existing$count > 0) {
        skipped_count <- skipped_count + 1
        next
      }
      
      # Parse datum
      datum_aanmaak <- parse_datum(row, zaak_info)
      
      # LA Budget verwerking
      la_budget_val <- NULL
      if ("LA Budget WJZ" %in% names(row)) {
        budget_text <- tolower(as.character(row$`LA Budget WJZ`))
        if (budget_text %in% c("ja", "yes", "1")) {
          la_budget_val <- 1
        } else if (budget_text %in% c("nee", "no", "0")) {
          la_budget_val <- 0
        }
      }
      
      # Map aanvragende directie
      directie_info <- if ("Aanvragende directie" %in% names(row)) {
        map_directie(row$`Aanvragende directie`)
      } else {
        list(directie = "NIET_INGESTELD", contactpersoon = NA)
      }
      
      # Bereid data voor insert
      insert_data <- data.frame(
        zaak_id = as.character(zaak_id),
        datum_aanmaak = as.character(datum_aanmaak),
        zaakaanduiding = if ("Zaakaanduiding" %in% names(row) && !is.na(row$Zaakaanduiding)) as.character(row$Zaakaanduiding) else as.character(NA),
        contactpersoon = if (!is.na(directie_info$contactpersoon)) as.character(directie_info$contactpersoon) else as.character(NA),
        wjz_mt_lid = if ("WJZ-MT-lid" %in% names(row) && !is.na(row$`WJZ-MT-lid`)) as.character(row$`WJZ-MT-lid`) else as.character(NA),
        la_budget_wjz = if (!is.null(la_budget_val)) as.numeric(la_budget_val) else as.numeric(NA),
        type_dienst = if ("advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`advies/verpl vertegenw/bestuursR`)) as.character(row$`advies/verpl vertegenw/bestuursR`) else as.character(NA),
        status_zaak = "lopend",
        opmerkingen = if ("advocaat =Budget beleid" %in% names(row) && !is.na(row$`advocaat =Budget beleid`)) as.character(row$`advocaat =Budget beleid`) else as.character(NA),
        stringsAsFactors = FALSE
      )
      
      # Verwijder kolommen met alleen NA
      insert_data <- insert_data[, !sapply(insert_data, function(x) all(is.na(x)))]
      
      # Insert zaak met directies
      directies_voor_zaak <- if (!is.na(directie_info$directie)) list(directie_info$directie) else NULL
      voeg_zaak_toe(insert_data, "excel_import", directies = directies_voor_zaak)
      
      success_count <- success_count + 1
      
      if (success_count %% 50 == 0) {
        cat("  - Verwerkt:", success_count, "zaken\n")
      }
      
    }, error = function(e) {
      cat("  - FOUT bij rij", i, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\nResultaat: Lopende en slapende zaken -", success_count, "geïmporteerd,", 
      skipped_count, "overgeslagen,", error_count, "fouten\n")
  
  return(list(success = success_count, skipped = skipped_count, errors = error_count))
}

#' Import jaar sheet met verbeterde zaak ID verwerking
import_jaar_sheet <- function(con, sheet_name, status = "lopend") {
  cat("\nImporteren van sheet:", sheet_name, "\n")
  cat(paste(rep("-", 50), collapse=""), "\n")
  
  # Lees Excel data
  df <- read_excel(EXCEL_PATH, sheet = sheet_name, skip = 0)
  
  # Filter lege kolommen en rijen
  df <- df[, colSums(!is.na(df)) > 0]
  df <- df[!is.na(df[[1]]), ]
  
  # Filter *** rijen
  df <- df[!df[[1]] %in% c("***", NA, ""), ]
  
  cat("Gevonden zaken:", nrow(df), "\n")
  
  # Extract jaar uit kolom header (bijv. "WJZ/LA/ 2021/" -> "2021")
  col_header <- names(df)[1]
  header_jaar <- regmatches(col_header, regexpr("\\d{4}", col_header))
  if (length(header_jaar) == 0) {
    header_jaar <- sheet_name # fallback naar sheet naam
  }
  
  cat("Gedetecteerd header jaar:", header_jaar, "\n")
  
  success_count <- 0
  error_count <- 0
  skipped_count <- 0
  
  for (i in 1:nrow(df)) {
    tryCatch({
      row <- df[i, ]
      
      # Zaak ID constructie voor jaar sheets
      value <- trimws(as.character(row[[1]]))
      
      # Voor jaar sheets: waarde is meestal al "YYYY-XXX" formaat
      if (grepl("^\\d{4}-\\d{3}$", value)) {
        zaak_id <- paste0("WJZ-LA-", value)
        zaak_jaar <- substr(value, 1, 4)
      } else {
        # Fallback: gebruik header jaar
        zaak_id <- paste0("WJZ-LA-", header_jaar, "-", value)
        zaak_jaar <- header_jaar
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
      
      # Parse datum - prioriteit aan Excel Datum kolom
      datum_aanmaak <- if ("Datum" %in% names(row) && !is.na(row$Datum)) {
        tryCatch({
          as.character(as.Date(row$Datum))
        }, error = function(e) {
          cat("  - Datum conversie fout voor", zaak_id, ":", e$message, "\n")
          as.character(as.Date(paste0(zaak_jaar, "-01-01")))
        })
      } else {
        as.character(as.Date(paste0(zaak_jaar, "-01-01")))
      }
      
      # LA Budget verwerking
      la_budget_val <- NULL
      budget_cols <- c("LA Budget WJZ", "LA budget WJZ")
      for (col in budget_cols) {
        if (col %in% names(row) && !is.na(row[[col]])) {
          budget_text <- tolower(as.character(row[[col]]))
          if (budget_text %in% c("ja", "yes", "1")) {
            la_budget_val <- 1
          } else if (budget_text %in% c("nee", "no", "0")) {
            la_budget_val <- 0
          }
          break
        }
      }
      
      # Map aanvragende directie
      directie_info <- if ("Aanvragende directie" %in% names(row)) {
        map_directie(row$`Aanvragende directie`)
      } else {
        list(directie = "NIET_INGESTELD", contactpersoon = NA)
      }
      
      # Bereid data voor insert
      insert_data <- data.frame(
        zaak_id = as.character(zaak_id),
        datum_aanmaak = as.character(datum_aanmaak),
        zaakaanduiding = if ("Zaakaanduiding" %in% names(row) && !is.na(row$Zaakaanduiding)) as.character(row$Zaakaanduiding) else as.character(NA),
        contactpersoon = if (!is.na(directie_info$contactpersoon)) as.character(directie_info$contactpersoon) else as.character(NA),
        wjz_mt_lid = if ("WJZ-MT-lid" %in% names(row) && !is.na(row$`WJZ-MT-lid`)) as.character(row$`WJZ-MT-lid`) else as.character(NA),
        la_budget_wjz = if (!is.null(la_budget_val)) as.numeric(la_budget_val) else as.numeric(NA),
        type_dienst = if ("advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`advies/verpl vertegenw/bestuursR`)) as.character(row$`advies/verpl vertegenw/bestuursR`) else 
                     if ("Advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`Advies/verpl vertegenw/bestuursR`)) as.character(row$`Advies/verpl vertegenw/bestuursR`) else as.character(NA),
        status_zaak = as.character(status),
        opmerkingen = if ("advocaat =Budget beleid" %in% names(row) && !is.na(row$`advocaat =Budget beleid`)) as.character(row$`advocaat =Budget beleid`) else 
                     if ("Advocaat =Budget beleid" %in% names(row) && !is.na(row$`Advocaat =Budget beleid`)) as.character(row$`Advocaat =Budget beleid`) else as.character(NA),
        stringsAsFactors = FALSE
      )
      
      # Verwijder kolommen met alleen NA
      insert_data <- insert_data[, !sapply(insert_data, function(x) all(is.na(x)))]
      
      # Insert zaak met directies
      directies_voor_zaak <- if (!is.na(directie_info$directie)) list(directie_info$directie) else NULL
      voeg_zaak_toe(insert_data, "excel_import", directies = directies_voor_zaak)
      
      success_count <- success_count + 1
      
    }, error = function(e) {
      cat("  - FOUT bij rij", i, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\nResultaat:", sheet_name, "-", success_count, "geïmporteerd,", 
      skipped_count, "overgeslagen,", error_count, "fouten\n")
  
  return(list(success = success_count, skipped = skipped_count, errors = error_count))
}

#' Hoofdfunctie voor import
main <- function() {
  cat("=== EXCEL IMPORT NAAR DATABASE - VERSIE 3 ===\n")
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
  
  # Import lopende en slapende zaken (speciale verwerking)
  if ("Lopende en slapende zaken" %in% sheets) {
    result <- import_lopende_slapende(con)
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Import afgesloten zaken (als reguliere sheet)
  if ("Afgesloten zaken" %in% sheets) {
    result <- import_jaar_sheet(con, "Afgesloten zaken", status = "afgesloten")
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Import alle jaar sheets
  jaar_sheets <- sheets[grepl("^20\\d{2}$", sheets)]
  
  for (sheet in jaar_sheets) {
    result <- import_jaar_sheet(con, sheet, status = "lopend")
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