# Database Setup voor Dashboard Landsadvocaat met dbplyr
# ======================================================

# Required packages
library(DBI)
library(RSQLite)
library(dbplyr)
library(dplyr)
library(digest)

# Database configuratie
DB_PATH <- "data/landsadvocaat.db"

# =============================================================================
# DATABASE CONNECTIE FUNCTIES
# =============================================================================

#' Maak verbinding met database
get_db_connection <- function(db_path = DB_PATH) {
  
  # Zorg dat data directory bestaat
  if (!dir.exists("data")) {
    dir.create("data", recursive = TRUE)
  }
  
  # Maak verbinding
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  
  # Enable foreign keys (belangrijk voor data integriteit)
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  
  return(con)
}

#' Sluit database verbinding veilig
close_db_connection <- function(con) {
  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
}

# =============================================================================
# DATABASE INITIALISATIE
# =============================================================================

#' Setup complete database met alle tabellen
setup_database <- function(db_path = DB_PATH) {
  
  con <- get_db_connection(db_path)
  
  # 1. DROPDOWN CATEGORIES TABEL
  # -----------------------------
  dropdown_categories_sql <- "
    CREATE TABLE IF NOT EXISTS dropdown_categories (
      categorie TEXT PRIMARY KEY,
      naam_nl TEXT NOT NULL,
      beschrijving TEXT,
      verplicht INTEGER DEFAULT 1,
      actief INTEGER DEFAULT 1,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  "
  
  # 2. DROPDOWN OPTIES TABEL  
  # -------------------------
  dropdown_opties_sql <- "
    CREATE TABLE IF NOT EXISTS dropdown_opties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categorie TEXT NOT NULL,
      waarde TEXT NOT NULL,
      weergave_naam TEXT,
      volgorde INTEGER DEFAULT 0,
      actief INTEGER DEFAULT 1,
      aangemaakt_door TEXT,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (categorie) REFERENCES dropdown_categories(categorie),
      UNIQUE(categorie, waarde)
    )
  "
  
  # 3. GEBRUIKERS TABEL
  # -------------------
  gebruikers_sql <- "
    CREATE TABLE IF NOT EXISTS gebruikers (
      gebruiker_id INTEGER PRIMARY KEY AUTOINCREMENT,
      gebruikersnaam TEXT UNIQUE NOT NULL,
      wachtwoord_hash TEXT NOT NULL,
      volledige_naam TEXT,
      email TEXT,
      rol TEXT DEFAULT 'gebruiker',
      actief INTEGER DEFAULT 1,
      laatste_login DATETIME,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  "
  
  # 4. ZAKEN TABEL (HOOFD TABEL)
  # ----------------------------
  zaken_sql <- "
    CREATE TABLE IF NOT EXISTS zaken (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      zaak_id TEXT UNIQUE NOT NULL,
      datum_aanmaak DATE NOT NULL,
      omschrijving TEXT,
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
      
      -- Foreign key constraints kunnen later toegevoegd worden
      -- voor dropdown validatie als gewenst
      
      FOREIGN KEY (aangemaakt_door) REFERENCES gebruikers(gebruikersnaam)
    )
  "
  
  # Voer alle CREATE TABLE statements uit
  DBI::dbExecute(con, dropdown_categories_sql)
  DBI::dbExecute(con, dropdown_opties_sql)
  DBI::dbExecute(con, gebruikers_sql)
  DBI::dbExecute(con, zaken_sql)
  
  close_db_connection(con)
  
  message("Database tabellen succesvol aangemaakt: ", db_path)
}

# =============================================================================
# DBPLYR TABLE HELPERS
# =============================================================================

#' Krijg dbplyr tabel voor zaken
tbl_zaken <- function(con = NULL) {
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  return(tbl(con, "zaken"))
}

#' Krijg dbplyr tabel voor dropdown opties
tbl_dropdown_opties <- function(con = NULL) {
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  return(tbl(con, "dropdown_opties"))
}

#' Krijg dbplyr tabel voor dropdown categories
tbl_dropdown_categories <- function(con = NULL) {
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  return(tbl(con, "dropdown_categories"))
}

#' Krijg dbplyr tabel voor gebruikers
tbl_gebruikers <- function(con = NULL) {
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  return(tbl(con, "gebruikers"))
}

# =============================================================================
# DROPDOWN MANAGEMENT FUNCTIES
# =============================================================================

#' Krijg alle opties voor een dropdown categorie
get_dropdown_opties <- function(categorie, actief_alleen = TRUE, exclude_fallback = TRUE) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  query <- tbl_dropdown_opties(con) %>%
    filter(categorie == !!categorie)
  
  if (actief_alleen) {
    query <- query %>% filter(actief == 1)
  }
  
  # Exclude fallback values (niet_ingesteld) voor selecteerbare dropdowns
  if (exclude_fallback) {
    query <- query %>% filter(waarde != "niet_ingesteld")
  }
  
  result <- query %>%
    select(waarde, weergave_naam, volgorde) %>%
    arrange(volgorde) %>%
    collect()
  
  # Gebruik weergave_naam als die bestaat, anders waarde
  labels <- ifelse(is.na(result$weergave_naam) | result$weergave_naam == "", 
                   result$waarde, result$weergave_naam)
  opties <- result$waarde
  names(opties) <- labels
  
  # Sorteer alfabetisch op labels (weergave namen) zoals gewenst
  opties <- opties[order(names(opties))]
  
  return(opties)
}

# =============================================================================
# DROPDOWN CACHE SYSTEM (Performance Optimalisatie)
# =============================================================================

# Global cache voor dropdown weergave namen
.dropdown_cache <- new.env(parent = emptyenv())

#' Clear dropdown cache (call when dropdowns are updated)
clear_dropdown_cache <- function() {
  rm(list = ls(.dropdown_cache), envir = .dropdown_cache)
  message("Dropdown cache cleared")
}

#' Get cached dropdown mapping voor een categorie
get_dropdown_cache <- function(categorie) {
  cache_key <- paste0("mapping_", categorie)
  if (exists(cache_key, envir = .dropdown_cache)) {
    return(get(cache_key, envir = .dropdown_cache))
  }
  return(NULL)
}

#' Set cached dropdown mapping voor een categorie
set_dropdown_cache <- function(categorie, mapping) {
  cache_key <- paste0("mapping_", categorie)
  assign(cache_key, mapping, envir = .dropdown_cache)
}

#' Bulk load dropdown mappings voor een categorie
load_dropdown_mapping <- function(categorie) {
  # Check cache first
  cached <- get_dropdown_cache(categorie)
  if (!is.null(cached)) {
    return(cached)
  }
  
  # Load from database
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  mapping_data <- tbl_dropdown_opties(con) %>%
    filter(categorie == !!categorie, actief == 1) %>%
    select(waarde, weergave_naam) %>%
    collect()
  
  # Create named vector mapping
  mapping <- setNames(
    ifelse(is.na(mapping_data$weergave_naam) | mapping_data$weergave_naam == "", 
           mapping_data$waarde, 
           mapping_data$weergave_naam),
    mapping_data$waarde
  )
  
  # Add special cases
  mapping["niet_ingesteld"] <- "Niet ingesteld"
  mapping[""] <- ""
  mapping[is.na(names(mapping))] <- ""
  
  # Cache it
  set_dropdown_cache(categorie, mapping)
  
  return(mapping)
}

#' Converteer database waarde naar weergave naam (CACHED)
get_weergave_naam_cached <- function(categorie, waarde) {
  if (is.na(waarde) || is.null(waarde) || waarde == "") {
    return(waarde)
  }
  
  # Get mapping from cache or load
  mapping <- load_dropdown_mapping(categorie)
  
  # Look up value
  waarde_str <- as.character(waarde)
  if (waarde_str %in% names(mapping)) {
    result <- mapping[[waarde_str]]
    if (!is.null(result) && !is.na(result)) {
      return(result)
    }
  }
  
  # Fallback naar originele waarde
  return(waarde)
}

#' Bulk convert multiple values to display names (OPTIMIZED)
bulk_get_weergave_namen <- function(categorie, waarden) {
  if (length(waarden) == 0) return(character(0))
  
  # Remove NA values but keep track of positions
  na_positions <- is.na(waarden) | waarden == ""
  
  if (all(na_positions)) {
    return(waarden)
  }
  
  # Get mapping
  mapping <- load_dropdown_mapping(categorie)
  
  # Apply mapping
  result <- character(length(waarden))
  result[na_positions] <- waarden[na_positions]
  
  valid_waarden <- waarden[!na_positions]
  valid_waarden_str <- as.character(valid_waarden)
  
  # Get mapped values with safe lookup
  mapped_values <- character(length(valid_waarden))
  for (i in seq_along(valid_waarden_str)) {
    if (valid_waarden_str[i] %in% names(mapping)) {
      mapped_values[i] <- mapping[[valid_waarden_str[i]]]
    } else {
      mapped_values[i] <- valid_waarden[i]
    }
  }
  
  result[!na_positions] <- mapped_values
  
  return(result)
}

#' Converteer database waarde naar weergave naam (LEGACY - Non-cached)
#' @deprecated Use get_weergave_naam_cached() instead for better performance
get_weergave_naam <- function(categorie, waarde) {
  if (is.na(waarde) || is.null(waarde) || waarde == "") {
    return(waarde)
  }
  
  # Special handling for fallback value
  if (waarde == "niet_ingesteld") {
    return("Niet ingesteld")
  }
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  result <- tbl_dropdown_opties(con) %>%
    filter(categorie == !!categorie, waarde == !!waarde) %>%
    select(weergave_naam) %>%
    collect()
  
  if (nrow(result) > 0 && !is.na(result$weergave_naam) && result$weergave_naam != "") {
    return(result$weergave_naam)
  } else {
    return(waarde)  # Fallback naar originele waarde
  }
}

#' Voeg dropdown optie toe
add_dropdown_optie <- function(categorie, waarde, weergave_naam = NULL, 
                               volgorde = 0, gebruiker = "system") {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  nieuwe_optie <- data.frame(
    categorie = categorie,
    waarde = waarde,
    weergave_naam = weergave_naam,
    volgorde = volgorde,
    aangemaakt_door = gebruiker,
    stringsAsFactors = FALSE
  )
  
  DBI::dbAppendTable(con, "dropdown_opties", nieuwe_optie)
  
  # Clear cache voor deze categorie
  clear_dropdown_cache()
}

#' Verwijder dropdown optie met vervanging voor zaken in gebruik
verwijder_dropdown_optie <- function(categorie, waarde, gebruiker = "system") {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  tryCatch({
    # Start transactie
    DBI::dbBegin(con)
    
    # 1. Zoek kolom naam voor deze categorie in zaken tabel
    kolom_mapping <- list(
      "type_dienst" = "type_dienst",
      "rechtsgebied" = "rechtsgebied", 
      "status_zaak" = "status_zaak",
      "aanvragende_directie" = "aanvragende_directie",
      "type_wederpartij" = "type_wederpartij",
      "reden_inzet" = "reden_inzet",
      "hoedanigheid_partij" = "hoedanigheid_partij"
    )
    
    kolom_naam <- kolom_mapping[[categorie]]
    if (is.null(kolom_naam)) {
      stop(paste("Onbekende categorie:", categorie))
    }
    
    # 2. Check of waarde in gebruik is in zaken
    query <- paste0("SELECT COUNT(*) as count FROM zaken WHERE ", kolom_naam, " = ?")
    gebruik_count <- DBI::dbGetQuery(con, query, list(waarde))$count
    
    # 3. Als in gebruik, vervang door "niet_ingesteld" 
    if (gebruik_count > 0) {
      # Voeg "niet_ingesteld" optie toe als deze nog niet bestaat
      bestaande_niet_ingesteld <- DBI::dbGetQuery(con, "
        SELECT COUNT(*) as count FROM dropdown_opties 
        WHERE categorie = ? AND waarde = 'niet_ingesteld'
      ", list(categorie))$count
      
      if (bestaande_niet_ingesteld == 0) {
        DBI::dbExecute(con, "
          INSERT INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door, actief)
          VALUES (?, 'niet_ingesteld', 'Niet ingesteld', -1, ?, 0)
        ", list(categorie, gebruiker))
      }
      
      # Update alle zaken die deze waarde gebruiken
      update_query <- paste0("UPDATE zaken SET ", kolom_naam, " = 'niet_ingesteld' WHERE ", kolom_naam, " = ?")
      DBI::dbExecute(con, update_query, list(waarde))
    }
    
    # 4. Verwijder de dropdown optie
    rows_deleted <- DBI::dbExecute(con, "
      DELETE FROM dropdown_opties 
      WHERE categorie = ? AND waarde = ?
    ", list(categorie, waarde))
    
    # Debug info
    message("Deleted ", rows_deleted, " rows for categorie='", categorie, "', waarde='", waarde, "'")
    
    # Commit transactie
    DBI::dbCommit(con)
    
    # Clear cache after successful deletion
    clear_dropdown_cache()
    
    return(list(success = TRUE, zaken_updated = gebruik_count))
    
  }, error = function(e) {
    # Rollback bij fout
    DBI::dbRollback(con)
    return(list(success = FALSE, error = e$message))
  })
}

# =============================================================================
# ZAKEN CRUD FUNCTIES MET DBPLYR
# =============================================================================

#' Lees alle zaken (met filtering opties)
lees_zaken <- function(filters = list(), con = NULL) {
  
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  
  query <- tbl_zaken(con)
  
  # Pas filters toe als gegeven
  for (kolom in names(filters)) {
    if (!is.null(filters[[kolom]]) && filters[[kolom]] != "") {
      query <- query %>% filter(!!sym(kolom) == !!filters[[kolom]])
    }
  }
  
  # Sorteer op datum (nieuwste eerst)
  result <- query %>%
    arrange(desc(datum_aanmaak)) %>%
    collect()
  
  # Converteer datum kolommen
  if (nrow(result) > 0) {
    result$datum_aanmaak <- as.Date(result$datum_aanmaak)
    
    # Robuuste conversie van laatst_gewijzigd met verschillende formaten
    result$laatst_gewijzigd <- tryCatch({
      # Probeer eerst standaard POSIXct conversie
      as.POSIXct(result$laatst_gewijzigd)
    }, error = function(e) {
      # Als dat faalt, probeer verschillende formaten
      sapply(result$laatst_gewijzigd, function(x) {
        if (is.na(x) || x == "") return(as.POSIXct(NA))
        
        # Probeer verschillende datetime formaten
        formats <- c(
          "%Y-%m-%d %H:%M:%S",
          "%Y-%m-%d %H:%M:%S.%f",
          "%Y-%m-%d %H:%M",
          "%Y-%m-%d"
        )
        
        for (fmt in formats) {
          result <- tryCatch(as.POSIXct(x, format = fmt), error = function(e) NULL)
          if (!is.null(result) && !is.na(result)) return(result)
        }
        
        # Als alles faalt, return huidige tijd
        return(Sys.time())
      })
    })
  }
  
  return(result)
}

#' Voeg nieuwe zaak toe
voeg_zaak_toe <- function(zaak_data, gebruiker, directies = NULL) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  tryCatch({
    dbBegin(con)
    
    # Extract directies if present in zaak_data
    if (is.null(directies) && "aanvragende_directie" %in% names(zaak_data)) {
      # Handle legacy single directie or new multi-directie format
      if (!is.null(zaak_data$aanvragende_directie)) {
        directies <- if (is.character(zaak_data$aanvragende_directie)) {
          # Could be comma-separated for backwards compatibility
          trimws(strsplit(zaak_data$aanvragende_directie, ",")[[1]])
        } else {
          zaak_data$aanvragende_directie
        }
      }
      # Remove from zaak_data as it's handled separately now
      zaak_data$aanvragende_directie <- NULL
    }
    
    # Voeg metadata toe
    zaak_data$aangemaakt_door <- gebruiker
    zaak_data$gewijzigd_door <- gebruiker
    zaak_data$laatst_gewijzigd <- Sys.time()
    
    # Zorg dat datum_aanmaak een Date is
    if (!"datum_aanmaak" %in% names(zaak_data)) {
      zaak_data$datum_aanmaak <- Sys.Date()
    }
    
    # Insert zaak
    DBI::dbAppendTable(con, "zaken", zaak_data)
    
    # Add directies if provided
    if (!is.null(directies) && length(directies) > 0) {
      directies <- directies[directies != "" & !is.na(directies)]
      if (length(directies) > 0) {
        for (directie in directies) {
          dbExecute(con, "
            INSERT INTO zaak_directies (zaak_id, directie) 
            VALUES (?, ?)
          ", params = list(zaak_data$zaak_id, directie))
        }
      }
    }
    
    dbCommit(con)
    
  }, error = function(e) {
    dbRollback(con)
    stop("Fout bij toevoegen zaak: ", e$message)
  })
}

#' Update bestaande zaak
update_zaak <- function(zaak_id, zaak_data, gebruiker, directies = NULL) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  tryCatch({
    dbBegin(con)
    
    # Extract directies if present in zaak_data
    if (is.null(directies) && "aanvragende_directie" %in% names(zaak_data)) {
      # Handle legacy single directie or new multi-directie format
      if (!is.null(zaak_data$aanvragende_directie)) {
        directies <- if (is.character(zaak_data$aanvragende_directie)) {
          # Could be comma-separated for backwards compatibility
          trimws(strsplit(zaak_data$aanvragende_directie, ",")[[1]])
        } else {
          zaak_data$aanvragende_directie
        }
      }
      # Remove from zaak_data as it's handled separately now
      zaak_data$aanvragende_directie <- NULL
    }
    
    # Voeg metadata toe
    zaak_data$gewijzigd_door <- gebruiker
    zaak_data$laatst_gewijzigd <- Sys.time()
    
    # Update zaak if there are fields to update
    if (length(zaak_data) > 0) {
      # Bouw UPDATE query
      set_columns <- paste(names(zaak_data), "= ?", collapse = ", ")
      query <- paste0("UPDATE zaken SET ", set_columns, " WHERE zaak_id = ?")
      
      # Create parameter list without names to avoid named/numbered parameter mix
      params_list <- unname(c(as.list(zaak_data), list(zaak_id)))
      
      DBI::dbExecute(con, query, params = params_list)
    }
    
    # Update directies if provided
    if (!is.null(directies)) {
      # Delete existing directies
      dbExecute(con, "DELETE FROM zaak_directies WHERE zaak_id = ?", 
                params = list(zaak_id))
      
      # Add new directies
      directies <- directies[directies != "" & !is.na(directies)]
      if (length(directies) > 0) {
        for (directie in directies) {
          dbExecute(con, "
            INSERT INTO zaak_directies (zaak_id, directie) 
            VALUES (?, ?)
          ", params = list(zaak_id, directie))
        }
      }
    }
    
    dbCommit(con)
    
  }, error = function(e) {
    dbRollback(con)
    stop("Fout bij updaten zaak: ", e$message)
  })
}

#' Verwijder zaak (soft delete mogelijk door status aan te passen)
verwijder_zaak <- function(zaak_id, hard_delete = FALSE) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  tryCatch({
    if (hard_delete) {
      result <- DBI::dbExecute(con, "DELETE FROM zaken WHERE zaak_id = ?", params = list(zaak_id))
    } else {
      # Soft delete - verander status naar 'Verwijderd'
      result <- DBI::dbExecute(con, 
                     "UPDATE zaken SET status_zaak = 'Verwijderd', laatst_gewijzigd = ? WHERE zaak_id = ?",
                     params = list(Sys.time(), zaak_id))
    }
    return(result > 0)  # Return TRUE if rows were affected
  }, error = function(e) {
    warning("Error deleting zaak ", zaak_id, ": ", e$message)
    return(FALSE)
  })
}

# =============================================================================
# ZAAK DIRECTIES (MANY-TO-MANY) HELPER FUNCTIES
# =============================================================================

#' Haal directies op voor een zaak
get_zaak_directies <- function(zaak_id) {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  result <- dbGetQuery(con, "
    SELECT DISTINCT d.directie
    FROM zaak_directies d
    WHERE d.zaak_id = ?
    ORDER BY d.directie
  ", params = list(zaak_id))
  
  return(result$directie)
}

#' Haal alle zaken met hun directies op voor display (OPTIMIZED - Single Query)
get_zaken_met_directies_optimized <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  # Single JOIN query instead of N+1 queries
  result <- DBI::dbGetQuery(con, "
    SELECT z.*,
           COALESCE(
             GROUP_CONCAT(
               CASE 
                 WHEN do.weergave_naam IS NOT NULL AND do.weergave_naam != '' 
                 THEN do.weergave_naam 
                 ELSE zd.directie 
               END, 
               ', '
             ), 
             'Niet ingesteld'
           ) as directies
    FROM zaken z
    LEFT JOIN zaak_directies zd ON z.zaak_id = zd.zaak_id
    LEFT JOIN dropdown_opties do ON zd.directie = do.waarde 
                                 AND do.categorie = 'aanvragende_directie'
                                 AND do.actief = 1
    GROUP BY z.zaak_id, z.datum_aanmaak, z.omschrijving, z.zaakaanduiding,
             z.type_dienst, z.type_procedure, z.rechtsgebied, z.hoedanigheid_partij,
             z.type_wederpartij, z.reden_inzet, z.civiel_bestuursrecht, z.aansprakelijkheid,
             z.aanvragende_directie, z.proza_link, z.wjz_mt_lid, z.la_budget_wjz,
             z.budget_andere_directie, z.kostenplaats, z.intern_ordernummer,
             z.grootboekrekening, z.budgetcode, z.financieel_risico, z.advocaat,
             z.adv_kantoor, z.adv_kantoor_contactpersoon, z.budget_beleid,
             z.advies_vertegenw_bestuursR, z.status_zaak, z.locatie_formulier,
             z.opmerkingen, z.aangemaakt_door, z.laatst_gewijzigd, z.gewijzigd_door
    ORDER BY z.datum_aanmaak DESC
  ")
  
  # Convert dates properly
  if (nrow(result) > 0) {
    result$datum_aanmaak <- as.Date(result$datum_aanmaak)
    
    # Robuuste conversie van laatst_gewijzigd
    result$laatst_gewijzigd <- tryCatch({
      as.POSIXct(result$laatst_gewijzigd)
    }, error = function(e) {
      sapply(result$laatst_gewijzigd, function(x) {
        if (is.na(x) || x == "") return(as.POSIXct(NA))
        
        formats <- c(
          "%Y-%m-%d %H:%M:%S",
          "%Y-%m-%d %H:%M:%S.%f",
          "%Y-%m-%d %H:%M",
          "%Y-%m-%d"
        )
        
        for (fmt in formats) {
          parsed <- tryCatch(as.POSIXct(x, format = fmt), error = function(e) NULL)
          if (!is.null(parsed) && !is.na(parsed)) return(parsed)
        }
        
        return(Sys.time())
      })
    })
  }
  
  return(result)
}

#' Haal alle zaken met hun directies op voor display (LEGACY - N+1 queries)
#' @deprecated Use get_zaken_met_directies_optimized() instead
get_zaken_met_directies <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  # Haal alle zaken op
  zaken <- lees_zaken()
  
  if (nrow(zaken) > 0) {
    # Voor elke zaak, haal de directies op
    zaken$directies <- sapply(zaken$zaak_id, function(id) {
      dirs <- get_zaak_directies(id)
      if (length(dirs) == 0) return("Niet ingesteld")
      
      # Converteer naar weergave namen
      weergave_namen <- sapply(dirs, function(d) {
        get_weergave_naam("aanvragende_directie", d)
      })
      
      return(paste(weergave_namen, collapse = ", "))
    })
  }
  
  return(zaken)
}

# =============================================================================
# GEBRUIKERS MANAGEMENT
# =============================================================================

#' Controleer login met dbplyr
controleer_login <- function(gebruikersnaam, wachtwoord) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  wachtwoord_hash <- digest(wachtwoord, algo = "sha256")
  
  gebruiker <- tbl_gebruikers(con) %>%
    filter(gebruikersnaam == !!gebruikersnaam,
           wachtwoord_hash == !!wachtwoord_hash,
           actief == 1) %>%
    collect()
  
  if (nrow(gebruiker) > 0) {
    # Update laatste login tijd
    DBI::dbExecute(con, 
                   "UPDATE gebruikers SET laatste_login = ? WHERE gebruikersnaam = ?",
                   params = list(Sys.time(), gebruikersnaam))
    return(TRUE)
  }
  
  return(FALSE)
}

#' Voeg nieuwe gebruiker toe
voeg_gebruiker_toe <- function(gebruikersnaam, wachtwoord, volledige_naam = NULL, 
                               email = NULL, rol = "gebruiker") {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  wachtwoord_hash <- digest(wachtwoord, algo = "sha256")
  
  nieuwe_gebruiker <- data.frame(
    gebruikersnaam = gebruikersnaam,
    wachtwoord_hash = wachtwoord_hash,
    volledige_naam = volledige_naam,
    email = email,
    rol = rol,
    stringsAsFactors = FALSE
  )
  
  DBI::dbAppendTable(con, "gebruikers", nieuwe_gebruiker)
}

# =============================================================================
# AUTOCOMPLETE HELPER FUNCTIES
# =============================================================================

#' Haal unieke advocaten op voor autocomplete
#' @return Character vector met unieke advocaat namen
get_advocaten_autocomplete <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  advocaten <- tbl(con, "zaken") %>%
    filter(!is.na(advocaat), advocaat != "") %>%
    distinct(advocaat) %>%
    arrange(advocaat) %>%
    collect() %>%
    pull(advocaat)
  
  return(advocaten)
}

#' Haal unieke advocatenkantoren op voor autocomplete  
#' @return Character vector met unieke kantoor namen
get_advocatenkantoren_autocomplete <- function() {
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  kantoren <- tbl(con, "zaken") %>%
    filter(!is.na(adv_kantoor), adv_kantoor != "") %>%
    distinct(adv_kantoor) %>%
    arrange(adv_kantoor) %>%
    collect() %>%
    pull(adv_kantoor)
  
  return(kantoren)
}

#' Krijg status kleuren voor dropdown weergave
#' @param con Database connectie (optioneel)
#' @return Named list met status waarden en hun kleuren
get_status_kleuren <- function(con = NULL) {
  
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  
  # Haal status kleuren op uit dropdown_opties
  kleuren_data <- tbl(con, "dropdown_opties") %>%
    filter(categorie == "status_zaak", actief == 1) %>%
    select(waarde, kleur) %>%
    collect()
  
  # Converteer naar named list
  kleuren <- setNames(kleuren_data$kleur, kleuren_data$waarde)
  
  # Voeg default kleur toe voor onbekende statussen
  if (!"default" %in% names(kleuren)) {
    kleuren[["default"]] <- "#6c757d"
  }
  
  return(kleuren)
}

#' Haal kleuren op voor alle dropdown categorieën uit de database
#' 
#' @param categorie De dropdown categorie (optioneel, als NULL dan alle categorieën)
#' @param con Database connectie (optioneel)
#' @return Named list met waarden en hun kleuren per categorie
get_dropdown_kleuren <- function(categorie = NULL, con = NULL) {
  
  if (is.null(con)) {
    con <- get_db_connection()
    on.exit(close_db_connection(con))
  }
  
  # Query bouwen
  query <- tbl(con, "dropdown_opties") %>%
    filter(actief == 1) %>%
    select(categorie, waarde, kleur)
  
  # Filter op categorie als opgegeven
  if (!is.null(categorie)) {
    query <- query %>% filter(categorie == !!categorie)
  }
  
  kleuren_data <- query %>% collect()
  
  # Groepeer per categorie
  result <- list()
  for (cat in unique(kleuren_data$categorie)) {
    cat_data <- kleuren_data[kleuren_data$categorie == cat, ]
    kleuren <- setNames(cat_data$kleur, cat_data$waarde)
    
    # Voeg default kleur toe voor onbekende waarden
    if (!"default" %in% names(kleuren)) {
      kleuren[["default"]] <- "#f8f9fa"
    }
    
    result[[cat]] <- kleuren
  }
  
  # Als specifieke categorie gevraagd, return direct de kleuren
  if (!is.null(categorie) && categorie %in% names(result)) {
    return(result[[categorie]])
  }
  
  return(result)
}