#!/usr/bin/env Rscript

# Vergelijk Excel velden met Database structuur
# ============================================

library(readxl)
library(DBI)
library(RSQLite)

# Configuratie
EXCEL_PATH <- "bronbestanden/Overzicht Inschakeling LA 2022.xlsx"

cat("=== VERGELIJKING EXCEL vs DATABASE VELDEN ===\n\n")

# 1. EXCEL VELDEN ANALYSE
cat("1. EXCEL VELDEN\n")
cat(paste(rep("=", 50), collapse=""), "\n\n")

# Lees Excel sheets
df_lopend <- read_excel(EXCEL_PATH, sheet = "Lopende en slapende zaken", skip = 1, n_max = 5)
df_lopend <- df_lopend[, colSums(!is.na(df_lopend)) > 0]

df_jaar <- read_excel(EXCEL_PATH, sheet = "2024", n_max = 5)
df_jaar <- df_jaar[, colSums(!is.na(df_jaar)) > 0]

cat("Velden in 'Lopende en slapende zaken' sheet:\n")
excel_fields_main <- names(df_lopend)
for (i in 1:length(excel_fields_main)) {
  cat(sprintf("  %d. %s\n", i, excel_fields_main[i]))
}

cat("\nVelden in jaar sheet (2024):\n")
excel_fields_year <- names(df_jaar)
for (i in 1:length(excel_fields_year)) {
  cat(sprintf("  %d. %s\n", i, excel_fields_year[i]))
}

# 2. DATABASE VELDEN
cat("\n\n2. DATABASE VELDEN\n")
cat(paste(rep("=", 50), collapse=""), "\n\n")

source("utils/database.R")
con <- get_db_connection()

zaken_info <- dbGetQuery(con, "PRAGMA table_info(zaken)")
db_fields <- zaken_info$name

cat("Velden in 'zaken' tabel:\n")
for (i in 1:length(db_fields)) {
  cat(sprintf("  %d. %s\n", i, db_fields[i]))
}

# 3. MAPPING ANALYSE
cat("\n\n3. VELD MAPPING\n")
cat(paste(rep("=", 50), collapse=""), "\n\n")

cat("Excel -> Database mapping:\n")
cat("  - WJZ/LA/ 2010/ -> zaak_id\n")
cat("  - Zaakaanduiding -> zaakaanduiding\n")
cat("  - Aanvragende directie -> aanvragende_directie\n")
cat("  - WJZ-MT-lid -> wjz_mt_lid\n")
cat("  - LA Budget WJZ -> la_budget_wjz\n")
cat("  - advies/verpl vertegenw/bestuursR -> type_dienst\n")
cat("  - advocaat =Budget beleid -> opmerkingen\n")
cat("  - (Sheet naam) -> status_zaak\n")
cat("  - Datum (uit jaar sheets) -> datum_aanmaak\n")

# 4. ONTBREKENDE VELDEN
cat("\n\n4. ONTBREKENDE VELDEN ANALYSE\n")
cat(paste(rep("=", 50), collapse=""), "\n\n")

cat("A. Excel velden ZONDER directe database match:\n")
excel_no_match <- c(
  "advocaat =Budget beleid (gedeeltelijk in opmerkingen)",
  "...8, ...9, ...10, ...11 (lege/onbenoemde kolommen)"
)
for (field in excel_no_match) {
  cat("  - ", field, "\n")
}

cat("\nB. Database velden ZONDER Excel data:\n")
db_no_excel <- c(
  "id (auto-increment)",
  "omschrijving",
  "type_procedure", 
  "rechtsgebied",
  "hoedanigheid_partij",
  "type_wederpartij", 
  "reden_inzet",
  "civiel_bestuursrecht",
  "aansprakelijkheid",
  "proza_link",
  "budget_andere_directie",
  "kostenplaats",
  "intern_ordernummer", 
  "grootboekrekening",
  "budgetcode",
  "financieel_risico",
  "advocaat",
  "adv_kantoor",
  "adv_kantoor_contactpersoon",
  "budget_beleid",
  "advies_vertegenw_bestuursR",
  "locatie_formulier",
  "laatst_gewijzigd",
  "gewijzigd_door"
)

for (field in db_no_excel) {
  cat("  - ", field, "\n")
}

# 5. AANBEVELINGEN
cat("\n\n5. AANBEVELINGEN\n")
cat(paste(rep("=", 50), collapse=""), "\n\n")

cat("Voor succesvolle import:\n")
cat("1. Gebruik standaard waarden voor ontbrekende verplichte velden\n")
cat("2. Map 'advocaat =Budget beleid' naar opmerkingen veld\n")
cat("3. Leid datum_aanmaak af uit sheet naam of gebruik huidige datum\n")
cat("4. Stel status_zaak in op basis van sheet naam\n")
cat("5. Vul aangemaakt_door met 'excel_import'\n")

cat("\nVelden die later handmatig aangevuld kunnen worden:\n")
cat("- Financiële gegevens (budget, risico, kostenplaats)\n")
cat("- Advocaat/kantoor informatie\n")
cat("- Juridische classificaties (rechtsgebied, type_procedure)\n")
cat("- Proza link\n")

dbDisconnect(con)