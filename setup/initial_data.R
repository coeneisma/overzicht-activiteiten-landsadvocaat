# Initiële Data Setup
# ===========================================================

#' Vul database met standaard dropdown opties (GEFIXTE VERSIE)
initialiseer_standaard_data_fixed <- function(db_path = DB_PATH) {
  
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  # ==========================================================================
  # 1. DROPDOWN CATEGORIES (Met directe SQL - geen parameters)
  # ==========================================================================
  
  categories_sql <- "
    INSERT OR IGNORE INTO dropdown_categories (categorie, naam_nl, beschrijving, verplicht) VALUES
    ('type_dienst', 'Type Dienst', 'Soort dienstverlening door landsadvocaat', 1),
    ('type_procedure', 'Type Procedure', 'Type juridische procedure', 1),
    ('rechtsgebied', 'Rechtsgebied', 'Rechtsgebied van de zaak', 1),
    ('hoedanigheid_partij', 'Hoedanigheid Partij', 'Rol van het ministerie in de procedure', 1),
    ('type_wederpartij', 'Type Wederpartij', 'Type tegenpartij in de zaak', 0),
    ('reden_inzet', 'Reden Inzet', 'Reden voor inzet landsadvocaat', 1),
    ('civiel_bestuursrecht', 'Civiel/Bestuursrecht', 'Civielrechtelijk of bestuursrechtelijk', 1),
    ('aansprakelijkheid', 'Aansprakelijkheid', 'Aansprakelijkheidspositie', 0),
    ('status_zaak', 'Status Zaak', 'Huidige status van de zaak', 1)
  "
  
  result <- DBI::dbExecute(con, categories_sql)
  cat("Dropdown categories toegevoegd, result:", result, "\n")
  
  # ==========================================================================
  # 2. DROPDOWN OPTIES (Met directe SQL)
  # ==========================================================================
  
  # Type Dienst
  type_dienst_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('type_dienst', 'Advies', 'Juridisch advies', 1, 'system'),
    ('type_dienst', 'Vertegenwoordiging', 'Procesvertegenwoordiging', 2, 'system'),
    ('type_dienst', 'Beide', 'Advies en vertegenwoordiging', 3, 'system'),
    ('type_dienst', 'Anders', 'Overig', 4, 'system')
  "
  
  # Type Procedure  
  type_procedure_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('type_procedure', 'Civiel', 'Civiele procedure', 1, 'system'),
    ('type_procedure', 'Bestuursrecht', 'Bestuursrechtelijke procedure', 2, 'system'),
    ('type_procedure', 'Strafrecht', 'Strafrechtelijke procedure', 3, 'system'),
    ('type_procedure', 'Europees', 'Europese procedure', 4, 'system'),
    ('type_procedure', 'Arbitrage', 'Arbitrageprocedure', 5, 'system'),
    ('type_procedure', 'Anders', 'Overige procedure', 6, 'system')
  "
  
  # Rechtsgebied
  rechtsgebied_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('rechtsgebied', 'Staatsrecht', 'Staatsrecht', 1, 'system'),
    ('rechtsgebied', 'Bestuursrecht', 'Bestuursrecht', 2, 'system'),
    ('rechtsgebied', 'Civielrecht', 'Civiel recht', 3, 'system'),
    ('rechtsgebied', 'Strafrecht', 'Strafrecht', 4, 'system'),
    ('rechtsgebied', 'Europees_recht', 'Europees recht', 5, 'system'),
    ('rechtsgebied', 'Internationaal_recht', 'Internationaal recht', 6, 'system'),
    ('rechtsgebied', 'Arbeidsrecht', 'Arbeidsrecht', 7, 'system'),
    ('rechtsgebied', 'Anders', 'Overig rechtsgebied', 8, 'system')
  "
  
  # Hoedanigheid Partij
  hoedanigheid_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('hoedanigheid_partij', 'Eiser', 'Eiser', 1, 'system'),
    ('hoedanigheid_partij', 'Verweerder', 'Verweerder', 2, 'system'),
    ('hoedanigheid_partij', 'Derde_belanghebbende', 'Derde belanghebbende', 3, 'system'),
    ('hoedanigheid_partij', 'Intervenient', 'Interveniënt', 4, 'system'),
    ('hoedanigheid_partij', 'Anders', 'Overige hoedanigheid', 5, 'system')
  "
  
  # Type Wederpartij
  wederpartij_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('type_wederpartij', 'Burger', 'Particuliere burger', 1, 'system'),
    ('type_wederpartij', 'Bedrijf', 'Bedrijf/onderneming', 2, 'system'),
    ('type_wederpartij', 'Andere_overheid', 'Andere overheidsinstantie', 3, 'system'),
    ('type_wederpartij', 'Internationale_organisatie', 'Internationale organisatie', 4, 'system'),
    ('type_wederpartij', 'Belangenorganisatie', 'Belangenorganisatie', 5, 'system'),
    ('type_wederpartij', 'Anders', 'Overige wederpartij', 6, 'system')
  "
  
  # Reden Inzet
  reden_inzet_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('reden_inzet', 'Complexiteit', 'Complexe rechtsvraag', 1, 'system'),
    ('reden_inzet', 'Capaciteit', 'Capaciteitsgebrek', 2, 'system'),
    ('reden_inzet', 'Specialisme', 'Specialistische kennis vereist', 3, 'system'),
    ('reden_inzet', 'Strategisch', 'Strategisch belang', 4, 'system'),
    ('reden_inzet', 'Precedentwerking', 'Precedentwerking', 5, 'system'),
    ('reden_inzet', 'Anders', 'Overige reden', 6, 'system')
  "
  
  # Civiel/Bestuursrecht
  civiel_bestuurs_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('civiel_bestuursrecht', 'Civiel', 'Civielrechtelijk', 1, 'system'),
    ('civiel_bestuursrecht', 'Bestuursrecht', 'Bestuursrechtelijk', 2, 'system'),
    ('civiel_bestuursrecht', 'Beide', 'Beide', 3, 'system'),
    ('civiel_bestuursrecht', 'Nvt', 'Niet van toepassing', 4, 'system')
  "
  
  # Aansprakelijkheid
  aansprakelijkheid_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('aansprakelijkheid', 'Aansprakelijk', 'Aansprakelijkheid aanwezig', 1, 'system'),
    ('aansprakelijkheid', 'Niet_aansprakelijk', 'Geen aansprakelijkheid', 2, 'system'),
    ('aansprakelijkheid', 'Onduidelijk', 'Aansprakelijkheid onduidelijk', 3, 'system'),
    ('aansprakelijkheid', 'Nvt', 'Niet van toepassing', 4, 'system')
  "
  
  # Status Zaak
  status_sql <- "
    INSERT OR IGNORE INTO dropdown_opties (categorie, waarde, weergave_naam, volgorde, aangemaakt_door) VALUES
    ('status_zaak', 'Open', 'Open', 1, 'system'),
    ('status_zaak', 'In_behandeling', 'In behandeling', 2, 'system'),
    ('status_zaak', 'Afgerond', 'Afgerond', 3, 'system'),
    ('status_zaak', 'On_hold', 'On hold', 4, 'system'),
    ('status_zaak', 'Verwijderd', 'Verwijderd', 5, 'system')
  "
  
  # Voer alle INSERT statements uit
  sql_statements <- list(
    "type_dienst" = type_dienst_sql,
    "type_procedure" = type_procedure_sql, 
    "rechtsgebied" = rechtsgebied_sql,
    "hoedanigheid_partij" = hoedanigheid_sql,
    "type_wederpartij" = wederpartij_sql,
    "reden_inzet" = reden_inzet_sql,
    "civiel_bestuursrecht" = civiel_bestuurs_sql,
    "aansprakelijkheid" = aansprakelijkheid_sql,
    "status_zaak" = status_sql
  )
  
  for (naam in names(sql_statements)) {
    result <- DBI::dbExecute(con, sql_statements[[naam]])
    cat("Dropdown opties voor", naam, "toegevoegd, result:", result, "\n")
  }
  
  message("Alle dropdown opties succesvol toegevoegd!")
}

#' Voeg standaard gebruikers toe
voeg_standaard_gebruikers_toe_fixed <- function(db_path = DB_PATH) {
  
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  # Maak admin en test gebruikers met gehashed wachtwoorden
  gebruikers_sql <- "
    INSERT OR IGNORE INTO gebruikers (gebruikersnaam, wachtwoord_hash, volledige_naam, email, rol, actief) VALUES
    ('admin', '1b396327a447a151e4f2b647ab1a093589297247a97aeb7897fd292e6022c99d', 'Administrator', 'admin@ocw.nl', 'admin', 1),
    ('test', 'c323039c2f7a1646e0de633d0c243303860b64f14b1eda005d26ea27e7a92839', 'Test Gebruiker', 'test@ocw.nl', 'gebruiker', 1)
  "
  
  result <- DBI::dbExecute(con, gebruikers_sql)
  cat("Standaard gebruikers toegevoegd, result:", result, "\n")
  
  message("Standaard gebruikers succesvol toegevoegd!")
  message("Login gegevens:")
  message("- Admin: gebruiker 'admin', wachtwoord 'admin123'")
  message("- Test: gebruiker 'test', wachtwoord 'test123'")
}

#' Voeg test zaken toe (GEFIXTE VERSIE - geen foreign keys)
voeg_test_zaken_toe_fixed <- function(db_path = DB_PATH) {
  
  # Voeg test zaken toe met directe SQL (eenvoudiger dan loopen)
  con <- get_db_connection(db_path)
  on.exit(close_db_connection(con))
  
  test_zaken_sql <- "
    INSERT OR IGNORE INTO zaken (
      zaak_id, datum_aanmaak, omschrijving, type_dienst, type_procedure, 
      rechtsgebied, hoedanigheid_partij, type_wederpartij, reden_inzet, civiel_bestuursrecht,
      aanvragende_directie, wjz_mt_lid, la_budget_wjz, budget_andere_directie,
      financieel_risico, advocaat, adv_kantoor, status_zaak, opmerkingen, aangemaakt_door
    ) VALUES
    (
      'WJZ/LA/2024/001', '2024-01-15', 
      'Advies over aanbestedingsprocedure ziekenhuisuitbreiding',
      'Advies', 'Bestuursrecht', 'Bestuursrecht', 'Verweerder',
      'Bedrijf', 'Complexiteit', 'Bestuursrecht', 'VWS', 'De Jong',
      15000, 5000, 250000, 'Mr. A. Jansen', 'Jansen & Partners', 'In_behandeling',
      'Complexe aanbestedingszaak met Europese dimensie', 'admin'
    ),
    (
      'WJZ/LA/2024/002', '2024-02-03',
      'Vertegenwoordiging in schadeclaim na verkeersongeval dienstvoertuig',
      'Vertegenwoordiging', 'Civiel', 'Civielrecht', 'Verweerder',
      'Burger', 'Capaciteit', 'Civiel', 'IenW', 'Peters',
      8000, 0, 75000, 'Mr. B. Peters', 'Peters Advocaten', 'Open',
      'Standaard aanrijdingszaak', 'admin'
    ),
    (
      'WJZ/LA/2024/003', '2024-03-12',
      'Advies privacy wetgeving nieuwe digitale dienstverlening',
      'Advies', 'Bestuursrecht', 'Europees_recht', 'Verweerder',
      '', 'Specialisme', 'Bestuursrecht', 'BZK', 'De Vries',
      12000, 0, 0, '', '', 'Afgerond',
      'AVG compliance check voor nieuwe app', 'admin'
    )
  "
  
  result <- DBI::dbExecute(con, test_zaken_sql)
  cat("Test zaken toegevoegd, result:", result, "\n")
  
  message("Test zaken succesvol toegevoegd!")
}

# ==========================================================================
# COMPLETE SETUP FUNCTIE (GEFIXTE VERSIE)
# ==========================================================================

#' Voer complete database setup uit (GEFIXTE VERSIE)
complete_database_setup_fixed <- function(db_path = DB_PATH) {
  
  cat("=== GEFIXTE Database Setup Gestart ===\n")
  
  # 1. Maak database en tabellen (deze werkte al)
  cat("1. Aanmaken database en tabellen...\n")
  setup_database(db_path)
  
  # 2. Voeg standaard gebruikers toe (NIEUW!)
  cat("2. Toevoegen standaard gebruikers...\n")
  voeg_standaard_gebruikers_toe_fixed(db_path)
  
  # 3. Voeg standaard data toe (GEFIXTE versie)
  cat("3. Toevoegen standaard dropdown opties...\n") 
  initialiseer_standaard_data_fixed(db_path)
  
  # 4. Voeg test zaken toe (GEFIXTE versie - geen foreign keys)
  cat("4. Toevoegen test zaken...\n")
  voeg_test_zaken_toe_fixed(db_path)
  
  cat("=== GEFIXTE Database Setup Voltooid ===\n")
  cat("Login gegevens:\n")
  cat("- Admin: gebruiker 'admin', wachtwoord 'admin123'\n")
  cat("- Test: gebruiker 'test', wachtwoord 'test123'\n")
  cat("Database locatie:", normalizePath(db_path), "\n")
}

# ==========================================================================
# GEBRUIK
# ==========================================================================

# Run dit om de gefixte setup uit te voeren:
# complete_database_setup_fixed()

# Test daarna met:
# test_database()