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
get_dropdown_opties <- function(categorie, actief_alleen = TRUE) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  query <- tbl_dropdown_opties(con) %>%
    filter(categorie == !!categorie)
  
  if (actief_alleen) {
    query <- query %>% filter(actief == 1)
  }
  
  result <- query %>%
    select(waarde, weergave_naam) %>%
    collect()
  
  # Gebruik weergave_naam als die bestaat, anders waarde
  labels <- ifelse(is.na(result$weergave_naam) | result$weergave_naam == "", 
                   result$waarde, result$weergave_naam)
  opties <- result$waarde
  names(opties) <- labels
  
  # Sorteer alfabetisch op labels (weergave namen)
  opties <- opties[order(names(opties))]
  
  return(opties)
}

#' Converteer database waarde naar weergave naam
get_weergave_naam <- function(categorie, waarde) {
  if (is.na(waarde) || is.null(waarde) || waarde == "") {
    return(waarde)
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
voeg_zaak_toe <- function(zaak_data, gebruiker) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  # Voeg metadata toe
  zaak_data$aangemaakt_door <- gebruiker
  zaak_data$gewijzigd_door <- gebruiker
  zaak_data$laatst_gewijzigd <- Sys.time()
  
  # Zorg dat datum_aanmaak een Date is
  if (!"datum_aanmaak" %in% names(zaak_data)) {
    zaak_data$datum_aanmaak <- Sys.Date()
  }
  
  DBI::dbAppendTable(con, "zaken", zaak_data)
}

#' Update bestaande zaak
update_zaak <- function(zaak_id, zaak_data, gebruiker) {
  
  con <- get_db_connection()
  on.exit(close_db_connection(con))
  
  # Voeg metadata toe
  zaak_data$gewijzigd_door <- gebruiker
  zaak_data$laatst_gewijzigd <- Sys.time()
  
  # Bouw UPDATE query
  set_columns <- paste(names(zaak_data), "= ?", collapse = ", ")
  query <- paste0("UPDATE zaken SET ", set_columns, " WHERE zaak_id = ?")
  
  DBI::dbExecute(con, query, params = c(unlist(zaak_data), zaak_id))
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