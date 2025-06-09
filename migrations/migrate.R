# Database Migration Runner
# ========================
# Dit script draait automatisch bij app startup om database schema updates toe te passen

# Load database utilities
source("utils/database.R")

#' Run all pending database migrations
#' @param dry_run Als TRUE, toon alleen welke migrations zouden draaien zonder ze uit te voeren
run_migrations <- function(dry_run = FALSE) {
  
  message("\n📊 Database Migration Runner")
  message("===========================")
  
  # Get database connection
  con <- get_db_connection()
  
  tryCatch({
    # Ensure schema_migrations table exists
    if (!DBI::dbExistsTable(con, "schema_migrations")) {
      if (!dry_run) {
        message("📋 Creating schema_migrations table...")
        DBI::dbExecute(con, "
          CREATE TABLE schema_migrations (
            version INTEGER PRIMARY KEY,
            executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            description TEXT
          )
        ")
      } else {
        message("📋 Would create schema_migrations table")
      }
    }
    
    # Get current version
    current_version <- get_current_migration_version(con)
    message("📌 Current database version: ", current_version)
    
    # Find all migration files
    migration_files <- list.files("migrations", 
                                  pattern = "^\\d{3}.*\\.sql$", 
                                  full.names = TRUE)
    
    if (length(migration_files) == 0) {
      message("✅ No migration files found")
      return(invisible(TRUE))
    }
    
    # Sort by version number
    migration_files <- migration_files[order(sapply(migration_files, extract_version_from_filename))]
    
    # Find pending migrations
    pending_migrations <- character()
    for (file in migration_files) {
      version <- extract_version_from_filename(file)
      if (!is.na(version) && version > current_version) {
        pending_migrations <- c(pending_migrations, file)
      }
    }
    
    if (length(pending_migrations) == 0) {
      message("✅ Database is up to date!")
      return(invisible(TRUE))
    }
    
    message("\n🔄 Found ", length(pending_migrations), " pending migration(s)")
    
    # Create backup before migrations (unless dry run)
    if (!dry_run && length(pending_migrations) > 0) {
      backup_file <- create_database_backup("before_migrations")
      if (is.null(backup_file)) {
        stop("❌ Failed to create backup, aborting migrations")
      }
    }
    
    # Run each pending migration
    for (file in pending_migrations) {
      version <- extract_version_from_filename(file)
      description <- gsub("^\\d{3}_", "", gsub("\\.sql$", "", basename(file)))
      
      message("\n🚀 Migration ", version, ": ", description)
      
      if (!dry_run) {
        # Read SQL file
        sql_content <- readr::read_file(file)
        
        # Execute migration
        tryCatch({
          # Split by semicolons and execute each statement
          sql_statements <- strsplit(sql_content, ";\\s*")[[1]]
          sql_statements <- sql_statements[nchar(trimws(sql_statements)) > 0]
          
          for (statement in sql_statements) {
            if (nchar(trimws(statement)) > 0) {
              DBI::dbExecute(con, statement)
            }
          }
          
          # Record successful migration
          DBI::dbExecute(con, 
            "INSERT INTO schema_migrations (version, description) VALUES (?, ?)",
            list(version, description)
          )
          
          message("   ✅ Successfully applied")
          
        }, error = function(e) {
          message("   ❌ FAILED: ", e$message)
          message("\n⚠️  Migration failed! Database backup available at: ", backup_file)
          stop("Migration ", version, " failed. Stopping migration process.")
        })
        
      } else {
        message("   📋 Would execute migration (dry run mode)")
      }
    }
    
    if (!dry_run) {
      message("\n✅ All migrations completed successfully!")
    } else {
      message("\n📋 Dry run completed - no changes made")
    }
    
    return(invisible(TRUE))
    
  }, finally = {
    # Always close connection
    close_db_connection(con)
  })
}

#' Test a specific migration on a copy of the database
test_migration <- function(migration_file) {
  if (!file.exists(migration_file)) {
    stop("Migration file not found: ", migration_file)
  }
  
  # Create test database
  test_db <- "data/test_migration.db"
  message("🧪 Creating test database copy...")
  file.copy(DB_PATH, test_db, overwrite = TRUE)
  
  # Temporarily change DB_PATH
  original_db <- DB_PATH
  assign("DB_PATH", test_db, envir = .GlobalEnv)
  
  tryCatch({
    # Run migrations on test database
    message("🧪 Running migration on test database...")
    run_migrations(dry_run = FALSE)
    
    message("\n✅ Migration test successful!")
    message("🧹 Cleaning up test database...")
    
  }, error = function(e) {
    message("\n❌ Migration test failed: ", e$message)
  }, finally = {
    # Restore original DB_PATH
    assign("DB_PATH", original_db, envir = .GlobalEnv)
    # Remove test database
    if (file.exists(test_db)) {
      file.remove(test_db)
    }
  })
}

#' List all migrations and their status
list_migrations <- function() {
  con <- get_db_connection()
  
  tryCatch({
    current_version <- get_current_migration_version(con)
    
    # Get all migration files
    migration_files <- list.files("migrations", 
                                  pattern = "^\\d{3}.*\\.sql$", 
                                  full.names = FALSE)
    
    if (length(migration_files) == 0) {
      message("No migration files found")
      return(invisible(NULL))
    }
    
    # Sort and display
    migration_files <- migration_files[order(sapply(file.path("migrations", migration_files), 
                                                    extract_version_from_filename))]
    
    message("\n📋 Migration Status")
    message("==================")
    
    for (file in migration_files) {
      version <- extract_version_from_filename(file.path("migrations", file))
      status <- ifelse(version <= current_version, "✅ Applied", "⏳ Pending")
      message(sprintf("%s %03d: %s", status, version, file))
    }
    
  }, finally = {
    close_db_connection(con)
  })
}

# Als dit script direct wordt uitgevoerd
if (!interactive() && length(commandArgs(TRUE)) > 0) {
  args <- commandArgs(TRUE)
  if (args[1] == "run") {
    run_migrations()
  } else if (args[1] == "dry-run") {
    run_migrations(dry_run = TRUE)
  } else if (args[1] == "list") {
    list_migrations()
  }
}