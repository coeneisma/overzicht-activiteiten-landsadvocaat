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

# Directory mapping van Excel afkortingen naar database waarden
# Let op: deze moeten exact overeenkomen met waarden in dropdown_opties tabel
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

#' Map Excel directie afkorting naar database waarde
#' @param excel_value De waarde uit Excel (bijv. "PO/VO" of "PO/Bond")
#' @return Een lijst met directie en contactpersoon
#' Let op: retourneert slechts één directie waarde (de eerste gevonden) voor dropdown compatibiliteit
map_directie <- function(excel_value) {
  if (is.na(excel_value) || excel_value == "" || toupper(excel_value) == "NA") {
    return(list(directie = "NIET_INGESTELD", contactpersoon = NA))
  }
  
  # Converteer naar uppercase voor matching
  excel_value_clean <- trimws(as.character(excel_value))
  
  # Variabelen voor resultaat
  directie_gevonden <- NA
  contactpersoon <- NA
  
  # Split op slash voor combinaties en persoonsnamen
  parts <- strsplit(excel_value_clean, "/")[[1]]
  parts <- trimws(parts)
  
  for (part in parts) {
    # Check of het een bekende directie afkorting is
    part_upper <- toupper(part)
    
    # Zoek in mapping (case-insensitive)
    for (afkorting in names(DIRECTIE_MAPPING)) {
      if (toupper(afkorting) == part_upper) {
        # Gebruik alleen de eerste gevonden directie voor dropdown compatibiliteit
        if (is.na(directie_gevonden)) {
          directie_gevonden <- DIRECTIE_MAPPING[[afkorting]]
        }
        break
      }
    }
    
    # Als het geen directie mapping is, check of het een persoonsnaam kan zijn
    if (!part_upper %in% names(DIRECTIE_MAPPING)) {
      # Check of het een persoonsnaam kan zijn (bevat spatie, streepje, of is langer dan 3 chars en geen afkorting)
      if (grepl(" ", part) || grepl("-", part) || 
          (nchar(part) > 3 && !part_upper %in% c("G", "(G)", "GS", "DG", "SG", "MT"))) {
        # Dit is waarschijnlijk een persoonsnaam
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
    # Log de originele waarde in opmerkingen veld (dit wordt later toegevoegd aan opmerkingen)
    cat("  - Onbekende directie afkorting:", excel_value_clean, "-> NIET_INGESTELD\n")
  }
  
  return(list(
    directie = directie_gevonden,
    contactpersoon = if(is.na(contactpersoon)) NA else contactpersoon,
    originele_waarde = excel_value_clean
  ))
}

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
      
      # Bepaal datum - prioriteit aan "Datum" kolom uit Excel
      datum_aanmaak <- if ("Datum" %in% names(row) && !is.na(row$Datum)) {
        # Gebruik datum uit Excel kolom
        tryCatch({
          as.character(as.Date(row$Datum))
        }, error = function(e) {
          cat("  - Fout bij datum conversie voor zaak", zaak_id, ":", e$message, "\n")
          as.character(Sys.Date())
        })
      } else if (!is.null(jaar)) {
        # Fallback naar jaar uit sheet naam
        as.character(as.Date(paste0(jaar, "-01-01")))
      } else {
        # Laatste fallback naar huidige datum
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
      
      # Map aanvragende directie en extract contactpersoon
      directie_info <- if ("Aanvragende directie" %in% names(row)) {
        map_directie(row$`Aanvragende directie`)
      } else {
        list(directie = "NIET_INGESTELD", contactpersoon = NA)
      }
      
      # Bereid data voor insert (zonder aanvragende_directie want dat gaat via many-to-many)
      # Gebruik expliciete NA values om "differing number of rows" fouten te voorkomen
      insert_data <- data.frame(
        zaak_id = as.character(zaak_id),
        datum_aanmaak = as.character(datum_aanmaak),
        zaakaanduiding = if ("Zaakaanduiding" %in% names(row) && !is.na(row$Zaakaanduiding)) as.character(row$Zaakaanduiding) else as.character(NA),
        contactpersoon = if (!is.na(directie_info$contactpersoon)) as.character(directie_info$contactpersoon) else as.character(NA),
        wjz_mt_lid = if ("WJZ-MT-lid" %in% names(row) && !is.na(row$`WJZ-MT-lid`)) as.character(row$`WJZ-MT-lid`) else as.character(NA),
        la_budget_wjz = if (!is.null(la_budget_val)) as.numeric(la_budget_val) else as.numeric(NA),
        type_dienst = if ("advies/verpl vertegenw/bestuursR" %in% names(row) && !is.na(row$`advies/verpl vertegenw/bestuursR`)) as.character(row$`advies/verpl vertegenw/bestuursR`) else as.character(NA),
        status_zaak = as.character(status),
        opmerkingen = if ("advocaat =Budget beleid" %in% names(row) && !is.na(row$`advocaat =Budget beleid`)) as.character(row$`advocaat =Budget beleid`) else as.character(NA),
        stringsAsFactors = FALSE
      )
      
      # Verwijder kolommen met alleen NA
      insert_data <- insert_data[, !sapply(insert_data, function(x) all(is.na(x)))]
      
      # Use the new voeg_zaak_toe function with many-to-many directies support
      directies_voor_zaak <- if (!is.na(directie_info$directie)) list(directie_info$directie) else NULL
      voeg_zaak_toe(insert_data, "excel_import", directies = directies_voor_zaak)
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