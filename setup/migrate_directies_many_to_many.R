#!/usr/bin/env Rscript

# Migratie script voor many-to-many relatie aanvragende_directies
# ================================================================

library(DBI)
library(RSQLite)
source("utils/database.R")

migrate_to_many_to_many <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  cat("=== MIGRATIE NAAR MANY-TO-MANY DIRECTIES ===\n")
  
  # 1. Maak de nieuwe many-to-many tabel
  cat("\n1. Creëer zaak_directies tabel...\n")
  
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS zaak_directies (
      zaak_id TEXT NOT NULL,
      directie TEXT NOT NULL,
      PRIMARY KEY (zaak_id, directie),
      FOREIGN KEY (zaak_id) REFERENCES zaken(zaak_id) ON DELETE CASCADE
    )
  ")
  
  cat("   ✓ Tabel zaak_directies aangemaakt\n")
  
  # 2. Migreer bestaande data
  cat("\n2. Migreer bestaande directie data...\n")
  
  # Haal alle zaken op met hun huidige directie
  zaken <- dbGetQuery(con, "
    SELECT zaak_id, aanvragende_directie 
    FROM zaken 
    WHERE aanvragende_directie IS NOT NULL 
      AND aanvragende_directie != ''
      AND aanvragende_directie != 'NIET_INGESTELD'
  ")
  
  cat("   Gevonden zaken met directie:", nrow(zaken), "\n")
  
  # Haal alle geldige dropdown waarden op
  geldige_directies <- dbGetQuery(con, "
    SELECT waarde 
    FROM dropdown_opties 
    WHERE categorie = 'aanvragende_directie' 
      AND actief = 1
  ")$waarde
  
  # Voeg NIET_INGESTELD toe aan geldige waarden (voor fallback)
  geldige_directies <- c(geldige_directies, "NIET_INGESTELD")
  
  # Import mapping voor backwards compatibility met bestaande data
  directie_mapping <- list(
    "PO" = "onderwijspersoneelenprimaironderwijs",
    "VO" = "onderwijsprestatiesenvoortgezetonderwijs",
    "BVE" = "middelbaarberoepsonderwijs",
    "MBO" = "middelbaarberoepsonderwijs",
    "HO&S" = "hogeronderwijsenstudiefinanciering",
    "DUO" = "dienstuitvoeringonderwijs",
    "FEZ" = "financieeleconomischezaken",
    "WJZ" = "wetgevingenjuridischezaken",
    "BOA" = "bestuursondersteuningenadvies",
    "EK" = "erfgoedenkunsten",
    "EGI" = "erfgoedenkunsten"
  )
  
  migrated <- 0
  fallback_used <- 0
  mapped <- 0
  
  for (i in 1:nrow(zaken)) {
    zaak <- zaken[i,]
    directie_waarde <- zaak$aanvragende_directie
    
    # Check of de directie een geldige dropdown waarde is
    if (directie_waarde %in% geldige_directies) {
      # Direct geldige waarde
      tryCatch({
        dbExecute(con, "
          INSERT OR IGNORE INTO zaak_directies (zaak_id, directie) 
          VALUES (?, ?)
        ", params = list(zaak$zaak_id, directie_waarde))
        migrated <- migrated + 1
      }, error = function(e) {
        cat("   - Fout bij zaak", zaak$zaak_id, ":", e$message, "\n")
      })
    } else if (directie_waarde %in% names(directie_mapping)) {
      # Map oude afkorting naar nieuwe waarde
      gemapte_waarde <- directie_mapping[[directie_waarde]]
      if (gemapte_waarde %in% geldige_directies) {
        tryCatch({
          dbExecute(con, "
            INSERT OR IGNORE INTO zaak_directies (zaak_id, directie) 
            VALUES (?, ?)
          ", params = list(zaak$zaak_id, gemapte_waarde))
          mapped <- mapped + 1
        }, error = function(e) {
          cat("   - Fout bij zaak", zaak$zaak_id, ":", e$message, "\n")
        })
      } else {
        # Gemapte waarde bestaat niet, gebruik fallback
        tryCatch({
          dbExecute(con, "
            INSERT OR IGNORE INTO zaak_directies (zaak_id, directie) 
            VALUES (?, 'NIET_INGESTELD')
          ", params = list(zaak$zaak_id))
          fallback_used <- fallback_used + 1
        }, error = function(e) {
          cat("   - Fout bij zaak", zaak$zaak_id, ":", e$message, "\n")
        })
      }
    } else {
      # Gebruik NIET_INGESTELD als fallback voor onbekende waarden
      tryCatch({
        dbExecute(con, "
          INSERT OR IGNORE INTO zaak_directies (zaak_id, directie) 
          VALUES (?, 'NIET_INGESTELD')
        ", params = list(zaak$zaak_id))
        fallback_used <- fallback_used + 1
        cat("   - Onbekende directie:", directie_waarde, "-> NIET_INGESTELD\n")
      }, error = function(e) {
        cat("   - Fout bij zaak", zaak$zaak_id, ":", e$message, "\n")
      })
    }
  }
  
  cat("   ✓ Direct gemigreerd:", migrated, "zaken\n")
  cat("   ✓ Gemapped:", mapped, "zaken\n")
  cat("   ✓ Fallback gebruikt:", fallback_used, "zaken\n")
  
  # 3. Verwijder de oude kolom (optioneel - voor nu behouden we hem)
  cat("\n3. Behoud aanvragende_directie kolom voor backwards compatibility\n")
  cat("   (Kan later verwijderd worden na volledige migratie)\n")
  
  # 4. Toon statistieken
  cat("\n=== MIGRATIE RESULTAAT ===\n")
  
  # Tel records in nieuwe tabel
  count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM zaak_directies")$n
  cat("Totaal records in zaak_directies:", count, "\n")
  
  # Toon top directies
  top_directies <- dbGetQuery(con, "
    SELECT d.directie, do.weergave_naam, COUNT(*) as aantal
    FROM zaak_directies d
    LEFT JOIN dropdown_opties do ON d.directie = do.waarde
    GROUP BY d.directie
    ORDER BY aantal DESC
    LIMIT 10
  ")
  
  cat("\nTop 10 directies:\n")
  print(top_directies)
  
  cat("\nMigratie voltooid!\n")
}

# Test de migratie
test_many_to_many <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  cat("\n=== TEST MANY-TO-MANY QUERIES ===\n")
  
  # Test 1: Haal directies op voor een zaak
  cat("\nTest 1: Directies voor eerste zaak\n")
  result <- dbGetQuery(con, "
    SELECT z.zaak_id, d.directie, do.weergave_naam
    FROM zaken z
    JOIN zaak_directies d ON z.zaak_id = d.zaak_id
    JOIN dropdown_opties do ON d.directie = do.waarde
    LIMIT 5
  ")
  print(result)
  
  # Test 2: Tel zaken per directie
  cat("\nTest 2: Aantal zaken per directie\n")
  result <- dbGetQuery(con, "
    SELECT do.weergave_naam, COUNT(DISTINCT d.zaak_id) as aantal_zaken
    FROM zaak_directies d
    JOIN dropdown_opties do ON d.directie = do.waarde
    GROUP BY d.directie
    ORDER BY aantal_zaken DESC
  ")
  print(head(result))
}

# Voer migratie uit indien direct aangeroepen
if (!interactive()) {
  migrate_to_many_to_many()
  test_many_to_many()
}