# Script om volgorde kolom toe te voegen aan gebruiker_kolom_instellingen tabel
# =============================================================================

library(DBI)
library(RSQLite)

# Database path
DB_PATH <- "data/landsadvocaat.db"

# Functie om volgorde kolom toe te voegen
add_volgorde_column <- function() {
  con <- dbConnect(RSQLite::SQLite(), DB_PATH)
  
  tryCatch({
    # Check of kolom al bestaat
    existing_cols <- dbListFields(con, "gebruiker_kolom_instellingen")
    
    if ("volgorde" %in% existing_cols) {
      cat("ℹ️ Volgorde kolom bestaat al in gebruiker_kolom_instellingen tabel\n")
      return(invisible(TRUE))
    }
    
    cat("Adding volgorde column to gebruiker_kolom_instellingen table...\n")
    
    # Voeg volgorde kolom toe
    dbExecute(con, "
      ALTER TABLE gebruiker_kolom_instellingen 
      ADD COLUMN volgorde INTEGER DEFAULT 999
    ")
    
    cat("✅ Successfully added volgorde column\n")
    
    # Update bestaande records met default volgorde gebaseerd op standaard volgorde
    # Standaard volgorde zoals gespecificeerd:
    # 1. zaak_id (altijd eerste, dus volgorde = 0)
    # 2. datum_aanmaak (volgorde = 1)
    # 3. looptijd (volgorde = 2)
    # 4. directies (volgorde = 3)
    # 5. zaakaanduiding (volgorde = 4)
    # 6. type_dienst (volgorde = 5)
    # 7. status_zaak (volgorde = 6)
    
    cat("Setting default order for standard visible columns...\n")
    
    # Update standaard zichtbare kolommen met specifieke volgorde
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 1 WHERE kolom_naam = 'datum_aanmaak'")
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 2 WHERE kolom_naam = 'looptijd'")
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 3 WHERE kolom_naam = 'directies'")
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 4 WHERE kolom_naam = 'zaakaanduiding'")
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 5 WHERE kolom_naam = 'type_dienst'")
    dbExecute(con, "UPDATE gebruiker_kolom_instellingen SET volgorde = 6 WHERE kolom_naam = 'status_zaak'")
    
    # Set volgorde voor andere kolommen op basis van alfabetische volgorde
    other_columns <- dbGetQuery(con, "
      SELECT DISTINCT kolom_naam 
      FROM gebruiker_kolom_instellingen 
      WHERE kolom_naam NOT IN ('datum_aanmaak', 'looptijd', 'directies', 
                               'zaakaanduiding', 'type_dienst', 'status_zaak')
      ORDER BY kolom_naam
    ")
    
    if (nrow(other_columns) > 0) {
      for (i in 1:nrow(other_columns)) {
        kolom <- other_columns$kolom_naam[i]
        volgorde <- 6 + i  # Start na de standaard kolommen
        dbExecute(con, 
          "UPDATE gebruiker_kolom_instellingen SET volgorde = ? WHERE kolom_naam = ?",
          params = list(volgorde, kolom)
        )
      }
    }
    
    cat("✅ Default column order has been set\n")
    
    # Verificatie
    sample_data <- dbGetQuery(con, "
      SELECT kolom_naam, volgorde 
      FROM gebruiker_kolom_instellingen 
      WHERE zichtbaar = 1
      ORDER BY volgorde, kolom_naam
      LIMIT 10
    ")
    
    cat("\nSample of column order:\n")
    print(sample_data)
    
  }, error = function(e) {
    stop("Error adding volgorde column: ", e$message)
  }, finally = {
    dbDisconnect(con)
  })
}

# Voer de migratie uit
cat("Starting migration to add volgorde column...\n")
add_volgorde_column()
cat("\nMigration completed!\n")