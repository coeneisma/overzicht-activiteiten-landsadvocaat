#!/usr/bin/env Rscript

# Import Excel data - Alleen Jaar Tabbladen - Versie 4
# ====================================================
# Focus op jaar tabbladen (2020-2024) met volledige financiële gegevens

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
  "O&B" = "organisatieenbedrijfsvoering",
  
  # Uitgebreide mapping voor ontbrekende afkortingen
  "DCE" = "NIET_INGESTELD", # Voorlopig - zou moeten worden geïdentificeerd
  "RCE" = "NIET_INGESTELD", 
  "DK" = "NIET_INGESTELD",
  "MLB" = "NIET_INGESTELD",
  "SG" = "wetgevingenjuridischezaken", # Secretaris-Generaal (waarschijnlijk WJZ)
  "E&K" = "erfgoedenkunsten",
  "M&C" = "mediaencreatieveindustrie",
  "DOB" = "organisatieenbedrijfsvoering",
  "OenB" = "organisatieenbedrijfsvoering"
)

#' Parse datum uit Excel
#' @param datum_value Waarde uit Excel Datum kolom (kan POSIXct, Date, of character zijn)
#' @param fallback_jaar Fallback jaar als datum niet parseerbaar is
#' @return Datum string (YYYY-MM-DD)
parse_excel_datum <- function(datum_value, fallback_jaar) {
  if (is.na(datum_value)) {
    return(as.character(as.Date(paste0(fallback_jaar, "-01-01"))))
  }
  
  tryCatch({
    # Als het al POSIXct/POSIXt is, converteer direct naar Date
    if (inherits(datum_value, c("POSIXct", "POSIXt"))) {
      return(as.character(as.Date(datum_value)))
    }
    
    # Als het een Date is, converteer naar character
    if (inherits(datum_value, "Date")) {
      return(as.character(datum_value))
    }
    
    # Anders probeer normale conversie
    parsed_date <- as.Date(datum_value)
    if (!is.na(parsed_date)) {
      return(as.character(parsed_date))
    }
  }, error = function(e) {
    cat("    Datum conversie fout:", e$message, "\n")
  })
  
  # Fallback naar jaar
  return(as.character(as.Date(paste0(fallback_jaar, "-01-01"))))
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
    mapped <- FALSE
    for (afkorting in names(DIRECTIE_MAPPING)) {
      if (toupper(afkorting) == part_upper) {
        if (is.na(directie_gevonden)) {
          directie_gevonden <- DIRECTIE_MAPPING[[afkorting]]
          mapped <- TRUE
        }
        break
      }
    }
    
    # Als het geen directie mapping is, check of het een persoonsnaam kan zijn
    if (!mapped) {
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

#' Parse ja/nee waarde naar boolean (0/1)
parse_ja_nee <- function(value) {
  if (is.na(value) || value == "") {
    return(NA)
  }
  
  value_lower <- tolower(trimws(as.character(value)))
  if (value_lower %in% c("ja", "yes", "1", "true")) {
    return(1)
  } else if (value_lower %in% c("nee", "no", "0", "false")) {
    return(0)
  } else {
    return(NA)
  }
}

#' Import jaar sheet met uitgebreide veld verwerking
import_jaar_sheet_uitgebreid <- function(con, sheet_name, status = "lopend") {
  cat("\nImporteren van sheet:", sheet_name, "\n")
  cat(paste(rep("-", 60), collapse=""), "\n")
  
  # Lees Excel data
  df <- read_excel(EXCEL_PATH, sheet = sheet_name, skip = 0)
  
  # Toon beschikbare kolommen voor debugging
  cat("Beschikbare kolommen:", paste(names(df), collapse = ", "), "\n")
  
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
      } else if (grepl("^\\d+$", value)) {
        # Alleen nummers: format als XXX met header jaar
        nummer <- sprintf("%03d", as.numeric(value))
        zaak_id <- paste0("WJZ-LA-", header_jaar, "-", nummer)
        zaak_jaar <- header_jaar
      } else {
        # Complexere waarden: gebruik as-is met header jaar
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
      datum_aanmaak <- parse_excel_datum(
        if ("Datum" %in% names(row)) row$Datum else NA,
        zaak_jaar
      )
      
      # Map aanvragende directie
      directie_info <- if ("Aanvragende directie" %in% names(row)) {
        map_directie(row$`Aanvragende directie`)
      } else {
        list(directie = "NIET_INGESTELD", contactpersoon = NA)
      }
      
      # Parse financiële velden
      la_budget_wjz <- NULL
      budget_cols <- c("LA Budget WJZ", "LA budget WJZ")
      for (col in budget_cols) {
        if (col %in% names(row)) {
          la_budget_wjz <- parse_ja_nee(row[[col]])
          break
        }
      }
      
      # Andere financiële velden
      budget_andere_directie <- if ("budget andere directie" %in% names(row) && !is.na(row$`budget andere directie`)) {
        as.numeric(row$`budget andere directie`)
      } else {
        NA
      }
      
      # Bereid data voor insert met ALLE velden
      insert_data <- data.frame(
        zaak_id = as.character(zaak_id),
        datum_aanmaak = as.character(datum_aanmaak),
        zaakaanduiding = if ("Zaakaanduiding" %in% names(row) && !is.na(row$Zaakaanduiding)) as.character(row$Zaakaanduiding) else as.character(NA),
        contactpersoon = if (!is.na(directie_info$contactpersoon)) as.character(directie_info$contactpersoon) else as.character(NA),
        
        # Organisatie velden
        proza_link = if ("ProZa-link" %in% names(row) && !is.na(row$`ProZa-link`)) as.character(row$`ProZa-link`) else as.character(NA),
        wjz_mt_lid = if ("WJZ-MT-lid" %in% names(row) && !is.na(row$`WJZ-MT-lid`)) as.character(row$`WJZ-MT-lid`) else as.character(NA),
        
        # Financiële velden
        la_budget_wjz = if (!is.null(la_budget_wjz) && !is.na(la_budget_wjz)) as.numeric(la_budget_wjz) else as.numeric(NA),
        budget_andere_directie = if (!is.na(budget_andere_directie)) as.numeric(budget_andere_directie) else as.numeric(NA),
        kostenplaats = if ("kostenplaats" %in% names(row) && !is.na(row$kostenplaats)) as.character(row$kostenplaats) else as.character(NA),
        intern_ordernummer = if ("intern ordernummer aanvragende directie" %in% names(row) && !is.na(row$`intern ordernummer aanvragende directie`)) as.character(row$`intern ordernummer aanvragende directie`) else as.character(NA),
        grootboekrekening = if ("grootboek- rekening" %in% names(row) && !is.na(row$`grootboek- rekening`)) as.character(row$`grootboek- rekening`) else 
                           if ("grootboekrekening" %in% names(row) && !is.na(row$grootboekrekening)) as.character(row$grootboekrekening) else as.character(NA),
        budgetcode = if ("budgetcode" %in% names(row) && !is.na(row$budgetcode)) as.character(row$budgetcode) else as.character(NA),
        
        # Advocatuur velden
        budget_beleid = if ("Advocaat =Budget beleid" %in% names(row) && !is.na(row$`Advocaat =Budget beleid`)) as.character(row$`Advocaat =Budget beleid`) else as.character(NA),
        advies_vertegenw_bestuursR = if ("advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`advies/verpl vertegenw/bestuursR`)) as.character(row$`advies/verpl vertegenw/bestuursR`) else 
                                    if ("Advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`Advies/verpl vertegenw/bestuursR`)) as.character(row$`Advies/verpl vertegenw/bestuursR`) else as.character(NA),
        
        # Status en tracking
        status_zaak = as.character(status),
        locatie_formulier = if ("waar bevindt zicht het formulier?" %in% names(row) && !is.na(row$`waar bevindt zicht het formulier?`)) as.character(row$`waar bevindt zicht het formulier?`) else as.character(NA),
        opmerkingen = if ("opmerkingen" %in% names(row) && !is.na(row$opmerkingen)) as.character(row$opmerkingen) else as.character(NA),
        
        stringsAsFactors = FALSE
      )
      
      # Verwijder kolommen met alleen NA om data.frame problemen te voorkomen
      insert_data <- insert_data[, !sapply(insert_data, function(x) all(is.na(x)))]
      
      # Insert zaak met directies
      directies_voor_zaak <- if (!is.na(directie_info$directie)) list(directie_info$directie) else NULL
      voeg_zaak_toe(insert_data, "excel_import", directies = directies_voor_zaak)
      
      success_count <- success_count + 1
      
      if (success_count %% 10 == 0) {
        cat("  - Verwerkt:", success_count, "zaken\n")
      }
      
    }, error = function(e) {
      cat("  - FOUT bij rij", i, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\nResultaat:", sheet_name, "-", success_count, "geïmporteerd,", 
      skipped_count, "overgeslagen,", error_count, "fouten\n")
  
  return(list(success = success_count, skipped = skipped_count, errors = error_count))
}

#' Hoofdfunctie voor import - alleen jaar tabbladen
main <- function() {
  cat("=== EXCEL IMPORT - ALLEEN JAAR TABBLADEN ===\n")
  cat("Excel bestand:", EXCEL_PATH, "\n")
  cat("Focus: Jaar tabbladen met volledige financiële gegevens\n")
  
  # Controleer of Excel bestand bestaat
  if (!file.exists(EXCEL_PATH)) {
    stop("Excel bestand niet gevonden!")
  }
  
  # Maak database verbinding
  con <- get_db_connection()
  on.exit(dbDisconnect(con))
  
  # Lees beschikbare sheets
  sheets <- excel_sheets(EXCEL_PATH)
  cat("\nBeschikbare sheets:", paste(sheets, collapse = ", "), "\n")
  
  # Filter alleen jaar sheets
  jaar_sheets <- sheets[grepl("^20\\d{2}$", sheets)]
  cat("Te importeren jaar sheets:", paste(jaar_sheets, collapse = ", "), "\n\n")
  
  # Houdt totalen bij
  totals <- list(success = 0, skipped = 0, errors = 0)
  
  # Import alle jaar sheets
  for (sheet in jaar_sheets) {
    result <- import_jaar_sheet_uitgebreid(con, sheet, status = "lopend")
    totals$success <- totals$success + result$success
    totals$skipped <- totals$skipped + result$skipped
    totals$errors <- totals$errors + result$errors
  }
  
  # Toon financiële velden statistieken
  cat("\n=== FINANCIËLE VELDEN ANALYSE ===\n")
  
  # LA Budget statistieken
  la_budget_stats <- dbGetQuery(con, "
    SELECT 
      CASE 
        WHEN la_budget_wjz = 1 THEN 'Ja'
        WHEN la_budget_wjz = 0 THEN 'Nee'
        ELSE 'Niet ingevuld'
      END as la_budget,
      COUNT(*) as aantal
    FROM zaken 
    GROUP BY la_budget_wjz
  ")
  
  cat("LA Budget WJZ verdeling:\n")
  for(i in 1:nrow(la_budget_stats)) {
    cat("  -", la_budget_stats$la_budget[i], ":", la_budget_stats$aantal[i], "\n")
  }
  
  # Financiële velden vulling
  financial_fields <- c("kostenplaats", "intern_ordernummer", "grootboekrekening", "budgetcode", "budget_beleid")
  cat("\nFinanciële velden vulling:\n")
  
  for (field in financial_fields) {
    filled_count <- dbGetQuery(con, paste0("SELECT COUNT(*) as count FROM zaken WHERE ", field, " IS NOT NULL AND ", field, " != ''"))$count
    total_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM zaken")$count
    percentage <- round((filled_count / total_count) * 100, 1)
    cat("  -", field, ":", filled_count, "/", total_count, "(", percentage, "%)\n")
  }
  
  # Toon totaal aantal zaken in database
  total_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM zaken")
  cat("\n=== IMPORT SAMENVATTING ===\n")
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