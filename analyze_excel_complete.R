#!/usr/bin/env Rscript

# Laad benodigde libraries
library(readxl)
library(dplyr)
library(DBI)
library(RSQLite)

# Pad naar Excel bestand
excel_path <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

cat("=== EXCEL BESTAND ANALYSE ===\n\n")

# Analyseer de hoofdsheet met zaken
cat("1. Analyseer 'Lopende en slapende zaken' sheet\n")
cat(paste(rep("=", 50), collapse=""), "\n")

# Lees de sheet met skip=1 om de headers correct te krijgen
df_lopend <- read_excel(excel_path, sheet = "Lopende en slapende zaken", skip = 1)

# Filter lege kolommen
df_lopend <- df_lopend[, colSums(!is.na(df_lopend)) > 0]

cat("Gevonden kolommen in Excel:\n")
for (i in 1:length(names(df_lopend))) {
  cat(sprintf("  %d. %s\n", i, names(df_lopend)[i]))
}

cat("\nAantal records:", nrow(df_lopend), "\n")

# Toon enkele voorbeelden
cat("\nVoorbeeld data (eerste 3 rijen):\n")
print(df_lopend[1:3, 1:min(6, ncol(df_lopend))])

# Analyseer jaar sheets
cat("\n\n2. Analyseer jaar sheets\n")
cat(paste(rep("=", 50), collapse=""), "\n")

year_sheet <- "2024"
df_year <- read_excel(excel_path, sheet = year_sheet, skip = 0)

# Filter lege kolommen
df_year <- df_year[, colSums(!is.na(df_year)) > 0]

cat("Kolommen in jaar sheet (", year_sheet, "):\n", sep = "")
for (i in 1:length(names(df_year))) {
  cat(sprintf("  %d. %s\n", i, names(df_year)[i]))
}

cat("\nAantal records:", nrow(df_year), "\n")

# DATABASE STRUCTUUR
cat("\n\n=== DATABASE STRUCTUUR ===\n")
cat(paste(rep("=", 50), collapse=""), "\n")

# Verbind met database
source("utils/database.R")
con <- get_db_connection()

# Haal zaken tabel structuur op
zaken_info <- dbGetQuery(con, "PRAGMA table_info(zaken)")

cat("\nKolommen in database 'zaken' tabel:\n")
for (i in 1:nrow(zaken_info)) {
  cat(sprintf("  %d. %s (%s)%s\n", 
              i, 
              zaken_info$name[i], 
              zaken_info$type[i],
              ifelse(zaken_info$notnull[i] == 1, " - VERPLICHT", "")))
}

# Haal enkele voorbeelden op uit database
cat("\nVoorbeeld data uit database:\n")
sample_data <- dbGetQuery(con, "SELECT zaaknummer, aanduiding, type_dienst, status_zaak FROM zaken LIMIT 3")
print(sample_data)

# Dropdown opties
cat("\n\nBeschikbare dropdown opties:\n")
dropdown_cats <- dbGetQuery(con, "
  SELECT categorie, COUNT(*) as aantal_opties 
  FROM dropdown_opties 
  GROUP BY categorie
")
print(dropdown_cats)

dbDisconnect(con)

# MAPPING VOORSTEL
cat("\n\n=== MAPPING VOORSTEL ===\n")
cat(paste(rep("=", 50), collapse=""), "\n")

cat("\nVoorgestelde mapping Excel -> Database:\n")
cat("1. 'WJZ/LA/ 2010/' -> zaaknummer\n")
cat("2. 'Zaakaanduiding' -> aanduiding\n")
cat("3. 'Aanvragende directie' -> aanvragende_directie\n")
cat("4. 'WJZ-MT-lid' -> (nieuw veld nodig of opslaan in toelichting)\n")
cat("5. 'LA Budget WJZ' -> (mogelijk als boolean in nieuwe kolom)\n")
cat("6. 'advies/verpl vertegenw/bestuursR' -> type_dienst\n")
cat("7. Status bepalen op basis van sheet naam en/of kolom data\n")

cat("\n\nAandachtspunten:\n")
cat("- Excel bevat historische data vanaf 2010\n")
cat("- Sommige velden in Excel hebben geen directe match in database\n")
cat("- Status moet worden afgeleid (lopend/slapend/afgesloten)\n")
cat("- Financiële gegevens ontbreken in Excel\n")
cat("- Datumvelden moeten mogelijk worden toegevoegd/afgeleid\n")