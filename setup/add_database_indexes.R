# setup/add_database_indexes.R
# ================================
# Performance Optimalisatie: Database Indexes

#' Voeg performance indexes toe aan de database
#' 
#' Deze indexes verbeteren de query performance aanzienlijk voor veelgebruikte queries
add_performance_indexes <- function(db_path = "data/landsadvocaat.db") {
  
  cli_alert_info("Adding performance indexes to database...")
  
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  # Index statements voor performance optimalisatie
  indexes <- list(
    # Zaken tabel indexes
    "idx_zaken_status" = "CREATE INDEX IF NOT EXISTS idx_zaken_status ON zaken(status_zaak)",
    "idx_zaken_datum" = "CREATE INDEX IF NOT EXISTS idx_zaken_datum ON zaken(datum_aanmaak)",
    "idx_zaken_type_dienst" = "CREATE INDEX IF NOT EXISTS idx_zaken_type_dienst ON zaken(type_dienst)",
    "idx_zaken_rechtsgebied" = "CREATE INDEX IF NOT EXISTS idx_zaken_rechtsgebied ON zaken(rechtsgebied)",
    "idx_zaken_zaak_id" = "CREATE INDEX IF NOT EXISTS idx_zaken_zaak_id ON zaken(zaak_id)",
    
    # Zaak directies tabel indexes (kritiek voor JOIN performance)
    "idx_zaak_directies_zaak_id" = "CREATE INDEX IF NOT EXISTS idx_zaak_directies_zaak_id ON zaak_directies(zaak_id)",
    "idx_zaak_directies_directie" = "CREATE INDEX IF NOT EXISTS idx_zaak_directies_directie ON zaak_directies(directie)",
    "idx_zaak_directies_composite" = "CREATE INDEX IF NOT EXISTS idx_zaak_directies_composite ON zaak_directies(zaak_id, directie)",
    
    # Dropdown opties tabel indexes
    "idx_dropdown_categorie_waarde" = "CREATE INDEX IF NOT EXISTS idx_dropdown_categorie_waarde ON dropdown_opties(categorie, waarde)",
    "idx_dropdown_categorie_actief" = "CREATE INDEX IF NOT EXISTS idx_dropdown_categorie_actief ON dropdown_opties(categorie, actief)",
    "idx_dropdown_weergave_naam" = "CREATE INDEX IF NOT EXISTS idx_dropdown_weergave_naam ON dropdown_opties(weergave_naam)",
    
    # Gebruikers tabel indexes
    "idx_gebruikers_naam" = "CREATE INDEX IF NOT EXISTS idx_gebruikers_naam ON gebruikers(gebruikersnaam)",
    "idx_gebruikers_actief" = "CREATE INDEX IF NOT EXISTS idx_gebruikers_actief ON gebruikers(actief)"
  )
  
  success_count <- 0
  error_count <- 0
  
  for (index_name in names(indexes)) {
    tryCatch({
      DBI::dbExecute(con, indexes[[index_name]])
      cli_alert_success("Index created: {index_name}")
      success_count <- success_count + 1
    }, error = function(e) {
      cli_alert_danger("Error creating index {index_name}: {e$message}")
      error_count <- error_count + 1
    })
  }
  
  cli_alert_info("Index creation summary: {success_count} success, {error_count} errors")
  
  # Verify indexes were created
  existing_indexes <- DBI::dbGetQuery(con, "
    SELECT name, sql 
    FROM sqlite_master 
    WHERE type = 'index' 
    AND name LIKE 'idx_%'
    ORDER BY name
  ")
  
  if (nrow(existing_indexes) > 0) {
    cli_alert_success("Verified {nrow(existing_indexes)} performance indexes in database:")
    for (i in 1:nrow(existing_indexes)) {
      cli_li("{existing_indexes$name[i]}")
    }
  }
  
  return(list(
    success = success_count,
    errors = error_count,
    total = length(indexes),
    indexes = existing_indexes
  ))
}

#' Check welke indexes al bestaan
check_existing_indexes <- function(db_path = "data/landsadvocaat.db") {
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  existing <- DBI::dbGetQuery(con, "
    SELECT name, sql 
    FROM sqlite_master 
    WHERE type = 'index' 
    AND name NOT LIKE 'sqlite_%'
    ORDER BY name
  ")
  
  if (nrow(existing) > 0) {
    cli_alert_info("Existing indexes in database:")
    for (i in 1:nrow(existing)) {
      cli_li("{existing$name[i]}: {existing$sql[i]}")
    }
  } else {
    cli_alert_warning("No custom indexes found in database")
  }
  
  return(existing)
}

#' Analyse query performance impact
analyze_query_performance <- function(db_path = "data/landsadvocaat.db") {
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  cli_alert_info("Analyzing query performance...")
  
  # Test belangrijke queries met EXPLAIN QUERY PLAN
  test_queries <- list(
    "main_query" = "
      SELECT z.*,
             COALESCE(GROUP_CONCAT(do.weergave_naam, ', '), 'Niet ingesteld') as directies
      FROM zaken z
      LEFT JOIN zaak_directies zd ON z.zaak_id = zd.zaak_id
      LEFT JOIN dropdown_opties do ON zd.directie = do.waarde 
                                   AND do.categorie = 'aanvragende_directie'
      GROUP BY z.zaak_id
      ORDER BY z.datum_aanmaak DESC
    ",
    "status_filter" = "SELECT * FROM zaken WHERE status_zaak = 'Lopend'",
    "date_filter" = "SELECT * FROM zaken WHERE datum_aanmaak >= '2024-01-01'",
    "dropdown_lookup" = "SELECT * FROM dropdown_opties WHERE categorie = 'status_zaak' AND actief = 1"
  )
  
  for (query_name in names(test_queries)) {
    cli_alert_info("Query plan for {query_name}:")
    plan <- DBI::dbGetQuery(con, paste("EXPLAIN QUERY PLAN", test_queries[[query_name]]))
    for (i in 1:nrow(plan)) {
      cli_li("{plan$detail[i]}")
    }
    cat("\n")
  }
}

# Execute if run directly
if (!interactive()) {
  # Load required libraries first
  library(cli)
  
  # Load database utilities first
  source("utils/database.R")
  
  # Check existing indexes
  cat("=== CHECKING EXISTING INDEXES ===\n")
  check_existing_indexes()
  
  cat("\n=== ADDING PERFORMANCE INDEXES ===\n")
  result <- add_performance_indexes()
  
  cat("\n=== QUERY PERFORMANCE ANALYSIS ===\n")
  analyze_query_performance()
  
  cat("\n=== SUMMARY ===\n")
  cli_alert_success("Database indexing complete!")
  cli_li("Indexes created: {result$success}/{result$total}")
  if (result$errors > 0) {
    cli_li("Errors: {result$errors}")
  }
}