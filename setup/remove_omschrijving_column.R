# Script om de omschrijving kolom te verwijderen uit de database
# ================================================================

library(DBI)
library(RSQLite)

# Database path
DB_PATH <- "data/landsadvocaat.db"

# Functie om omschrijving kolom te verwijderen
remove_omschrijving_column <- function() {
  con <- dbConnect(RSQLite::SQLite(), DB_PATH)
  
  tryCatch({
    # Begin transactie
    dbBegin(con)
    
    # SQLite ondersteunt geen directe DROP COLUMN, dus we moeten:
    # 1. Een nieuwe tabel maken zonder omschrijving
    # 2. Data kopiëren
    # 3. Oude tabel verwijderen
    # 4. Nieuwe tabel hernoemen
    
    cat("Creating new zaken table without omschrijving column...\n")
    
    # Maak nieuwe tabel zonder omschrijving
    dbExecute(con, "
      CREATE TABLE zaken_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        zaak_id TEXT UNIQUE NOT NULL,
        datum_aanmaak DATE NOT NULL,
        zaakaanduiding TEXT,
        
        -- Classificatie velden
        type_dienst TEXT,
        type_procedure TEXT,
        rechtsgebied TEXT,
        hoedanigheid_partij TEXT,
        type_wederpartij TEXT,
        reden_inzet TEXT,
        civiel_bestuursrecht TEXT,
        aansprakelijkheid TEXT,
        
        -- Organisatie velden
        aanvragende_directie TEXT,
        proza_link TEXT,
        wjz_mt_lid TEXT,
        
        -- Financiële velden
        la_budget_wjz REAL,
        budget_andere_directie REAL,
        kostenplaats TEXT,
        intern_ordernummer TEXT,
        grootboekrekening TEXT,
        budgetcode TEXT,
        financieel_risico REAL,
        
        -- Advocatuur velden
        advocaat TEXT,
        adv_kantoor TEXT,
        adv_kantoor_contactpersoon TEXT,
        budget_beleid TEXT,
        advies_vertegenw_bestuursR TEXT,
        
        -- Status en tracking
        status_zaak TEXT DEFAULT 'Open',
        locatie_formulier TEXT,
        opmerkingen TEXT,
        
        -- Metadata
        aangemaakt_door TEXT NOT NULL,
        laatst_gewijzigd DATETIME DEFAULT CURRENT_TIMESTAMP,
        gewijzigd_door TEXT,
        contactpersoon TEXT,
        deadline DATE,
        
        FOREIGN KEY (aangemaakt_door) REFERENCES gebruikers(gebruikersnaam)
      )
    ")
    
    cat("Copying data from old table to new table...\n")
    
    # Kopieer alle data behalve omschrijving
    dbExecute(con, "
      INSERT INTO zaken_new 
      SELECT 
        id, zaak_id, datum_aanmaak, zaakaanduiding,
        type_dienst, type_procedure, rechtsgebied, hoedanigheid_partij,
        type_wederpartij, reden_inzet, civiel_bestuursrecht, aansprakelijkheid,
        aanvragende_directie, proza_link, wjz_mt_lid,
        la_budget_wjz, budget_andere_directie, kostenplaats, intern_ordernummer,
        grootboekrekening, budgetcode, financieel_risico,
        advocaat, adv_kantoor, adv_kantoor_contactpersoon, budget_beleid, advies_vertegenw_bestuursR,
        status_zaak, locatie_formulier, opmerkingen,
        aangemaakt_door, laatst_gewijzigd, gewijzigd_door, contactpersoon, deadline
      FROM zaken
    ")
    
    # Check aantal rijen
    old_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM zaken")$n
    new_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM zaken_new")$n
    
    if (old_count != new_count) {
      stop(sprintf("Row count mismatch! Old: %d, New: %d", old_count, new_count))
    }
    
    cat(sprintf("Successfully copied %d rows\n", new_count))
    
    # Verwijder oude tabel
    cat("Dropping old table...\n")
    dbExecute(con, "DROP TABLE zaken")
    
    # Hernoem nieuwe tabel
    cat("Renaming new table...\n")
    dbExecute(con, "ALTER TABLE zaken_new RENAME TO zaken")
    
    # Commit transactie
    dbCommit(con)
    
    cat("✅ Successfully removed omschrijving column from zaken table!\n")
    
    # Verificatie
    columns <- dbListFields(con, "zaken")
    if ("omschrijving" %in% columns) {
      warning("⚠️ Warning: omschrijving column still exists!")
    } else {
      cat("✅ Verified: omschrijving column has been removed\n")
    }
    
  }, error = function(e) {
    dbRollback(con)
    stop("Error removing column: ", e$message)
  }, finally = {
    dbDisconnect(con)
  })
}

# Voer de migratie uit
cat("Starting migration to remove omschrijving column...\n")
remove_omschrijving_column()
cat("\nMigration completed!\n")