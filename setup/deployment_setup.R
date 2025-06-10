# Production Deployment Setup Script
# ===================================
# Complete automated setup voor production deployment
# Gebruik: source("setup/deployment_setup.R"); setup_production_database()

library(DBI)
library(RSQLite)
library(readr)

# Source required files
source("utils/database.R")
source("migrations/migrate.R")
source("setup/exported_config.R")

#' Complete Production Database Setup
#' 
#' Deze functie voert de volledige database setup uit voor production deployment:
#' - Database schema via migrations
#' - Alle dropdown categorieën en waarden  
#' - Deadline kleuren configuratie
#' - Gebruikers (admin/test)
#' - Performance indexes
#' 
setup_production_database <- function() {
  
  cat("🚀 DASHBOARD LANDSADVOCAAT - PRODUCTION DEPLOYMENT SETUP\n")
  cat("========================================================\n")
  cat("Versie: Main Branch (Production)\n")
  cat("Datum: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # 1. Run database migrations
  cat("📊 STAP 1: Database Schema Setup\n")
  cat("--------------------------------\n")
  
  tryCatch({
    run_migrations()
    cat("✅ Database schema succesvol aangemaakt via migrations\n\n")
  }, error = function(e) {
    cat("❌ FOUT bij migrations:", e$message, "\n")
    stop("Database migration gefaald")
  })
  
  # 2. Setup dropdown categories
  cat("📂 STAP 2: Dropdown Categorieën\n")
  cat("-------------------------------\n")
  
  setup_dropdown_categories()
  
  # 3. Setup dropdown opties
  cat("📋 STAP 3: Dropdown Waarden\n")
  cat("---------------------------\n")
  
  setup_dropdown_opties()
  
  # 4. Setup deadline kleuren
  cat("🎨 STAP 4: Deadline Kleuren\n")
  cat("---------------------------\n")
  
  setup_deadline_kleuren()
  
  # 5. Setup gebruikers
  cat("👥 STAP 5: Gebruikers\n")
  cat("--------------------\n")
  
  setup_gebruikers()
  
  # 6. Performance indexes (als ze nog niet bestaan)
  cat("⚡ STAP 6: Performance Indexes\n")
  cat("-----------------------------\n")
  
  setup_performance_indexes()
  
  # 7. Verifieer setup
  cat("✅ STAP 7: Verificatie\n")
  cat("----------------------\n")
  
  verify_setup()
  
  cat("\n🎉 DEPLOYMENT SETUP VOLTOOID!\n")
  cat("==============================\n")
  cat("✅ Database schema: OK\n")
  cat("✅ Dropdown configuratie: OK (", length(DROPDOWN_OPTIES), " waarden)\n")
  cat("✅ Deadline kleuren: OK (", length(DEADLINE_KLEUREN), " ranges)\n")
  cat("✅ Gebruikers: OK (admin/admin123, test/test123)\n")
  cat("✅ Performance indexes: OK\n\n")
  
  cat("📝 VOLGENDE STAPPEN:\n")
  cat("-------------------\n")
  cat("1. Start applicatie: shiny::runApp()\n")
  cat("2. Log in als admin (admin/admin123)\n")
  cat("3. Ga naar 'Bulk Upload' module\n")
  cat("4. Upload Excel bestand met zaakgegevens\n")
  cat("5. Volg 5-stappen wizard voor data import\n\n")
  
  cat("🔗 Database locatie: ", normalizePath(DB_PATH), "\n")
}

#' Setup dropdown categories
setup_dropdown_categories <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    added_count <- 0
    
    for (category in DROPDOWN_CATEGORIES) {
      result <- dbExecute(con, "
        INSERT OR IGNORE INTO dropdown_categories (categorie, naam_nl, beschrijving, verplicht) 
        VALUES (?, ?, ?, ?)
      ", params = list(
        category$categorie,
        category$naam_nl, 
        category$beschrijving,
        category$verplicht
      ))
      
      if (result > 0) added_count <- added_count + 1
    }
    
    cat("✅ Dropdown categorieën: ", added_count, " toegevoegd,", 
        length(DROPDOWN_CATEGORIES), " totaal\n")
    
  }, finally = {
    close_db_connection(con)
  })
}

#' Setup dropdown opties
setup_dropdown_opties <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    added_count <- 0
    
    for (optie in DROPDOWN_OPTIES) {
      # Handle NULL values properly
      kleur_val <- if (is.null(optie$kleur)) NA else optie$kleur
      
      result <- dbExecute(con, "
        INSERT OR IGNORE INTO dropdown_opties 
        (categorie, waarde, weergave_naam, volgorde, kleur, actief, aangemaakt_door) 
        VALUES (?, ?, ?, ?, ?, ?, 'deployment')
      ", params = list(
        optie$categorie,
        optie$waarde,
        optie$weergave_naam,
        optie$volgorde,
        kleur_val,
        optie$actief
      ))
      
      if (result > 0) added_count <- added_count + 1
    }
    
    cat("✅ Dropdown waarden: ", added_count, " toegevoegd,", 
        length(DROPDOWN_OPTIES), " totaal\n")
    
  }, finally = {
    close_db_connection(con)
  })
}

#' Setup deadline kleuren
setup_deadline_kleuren <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    # Verwijder bestaande en voeg nieuwe toe
    dbExecute(con, "DELETE FROM deadline_kleuren")
    
    added_count <- 0
    
    for (kleur in DEADLINE_KLEUREN) {
      # Handle NULL values properly
      dagen_voor_val <- if (is.null(kleur$dagen_voor)) NA else kleur$dagen_voor
      dagen_tot_val <- if (is.null(kleur$dagen_tot)) NA else kleur$dagen_tot
      
      dbExecute(con, "
        INSERT INTO deadline_kleuren 
        (dagen_voor, dagen_tot, beschrijving, kleur, actief, aangemaakt_door, aangemaakt_op) 
        VALUES (?, ?, ?, ?, ?, 'deployment', CURRENT_TIMESTAMP)
      ", params = list(
        dagen_voor_val,
        dagen_tot_val,
        kleur$beschrijving,
        kleur$kleur,
        kleur$actief
      ))
      
      added_count <- added_count + 1
    }
    
    cat("✅ Deadline kleuren: ", added_count, " toegevoegd\n")
    
  }, finally = {
    close_db_connection(con)
  })
}

#' Setup gebruikers
setup_gebruikers <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    added_count <- 0
    
    for (gebruiker in GEBRUIKERS) {
      result <- dbExecute(con, "
        INSERT OR IGNORE INTO gebruikers 
        (gebruikersnaam, wachtwoord_hash, volledige_naam, email, rol, actief) 
        VALUES (?, ?, ?, ?, ?, ?)
      ", params = list(
        gebruiker$gebruikersnaam,
        gebruiker$wachtwoord_hash,
        gebruiker$volledige_naam,
        gebruiker$email,
        gebruiker$rol,
        gebruiker$actief
      ))
      
      if (result > 0) added_count <- added_count + 1
    }
    
    cat("✅ Gebruikers: ", added_count, " toegevoegd,", 
        length(GEBRUIKERS), " totaal\n")
    cat("   - admin: admin123\n")
    cat("   - test: test123\n")
    
  }, finally = {
    close_db_connection(con)
  })
}

#' Setup performance indexes (if not exists)
setup_performance_indexes <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    # Deze indexes worden normaal via migrations aangemaakt
    # Maar we controleren voor de zekerheid
    
    indexes <- c(
      "CREATE INDEX IF NOT EXISTS idx_zaken_status ON zaken(status_zaak)",
      "CREATE INDEX IF NOT EXISTS idx_zaken_datum ON zaken(datum_aanmaak)",
      "CREATE INDEX IF NOT EXISTS idx_zaken_deadline ON zaken(deadline)",
      "CREATE INDEX IF NOT EXISTS idx_zaken_aangemaakt_door ON zaken(aangemaakt_door)"
    )
    
    for (index_sql in indexes) {
      dbExecute(con, index_sql)
    }
    
    cat("✅ Performance indexes: Geverifieerd en aangemaakt indien nodig\n")
    
  }, finally = {
    close_db_connection(con)
  })
}

#' Verify setup
verify_setup <- function() {
  con <- get_db_connection()
  
  tryCatch({
    
    # Check tables
    tables <- dbListTables(con)
    required_tables <- c("zaken", "dropdown_opties", "deadline_kleuren", "gebruikers")
    
    for (table in required_tables) {
      if (table %in% tables) {
        count <- dbGetQuery(con, paste0("SELECT COUNT(*) as count FROM ", table))$count
        cat("   ", table, ": ", count, " records\n")
      } else {
        cat("   ❌ ", table, ": ONTBREEKT\n")
      }
    }
    
  }, finally = {
    close_db_connection(con)
  })
}

# Als script direct wordt uitgevoerd
if (!interactive()) {
  setup_production_database()
}