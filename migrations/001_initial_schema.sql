-- Migration: 001_initial_schema.sql
-- Date: 2025-01-09
-- Description: Initial database schema for Dashboard Landsadvocaat
-- 
-- This migration creates all base tables needed for the application:
-- - dropdown_categories & dropdown_opties: Configurable dropdown values
-- - gebruikers: User management with role-based access
-- - zaken: Main legal cases table
-- - zaak_directies: Many-to-many relationship for case directorates
-- - deadline_kleuren: Configurable deadline warning colors
-- - gebruiker_kolom_instellingen: User-specific column visibility settings

CREATE TABLE dropdown_categories (
      categorie TEXT PRIMARY KEY,
      naam_nl TEXT NOT NULL,
      beschrijving TEXT,
      verplicht INTEGER DEFAULT 1,
      actief INTEGER DEFAULT 1,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE dropdown_opties (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categorie TEXT NOT NULL,
      waarde TEXT NOT NULL,
      weergave_naam TEXT,
      volgorde INTEGER DEFAULT 0,
      actief INTEGER DEFAULT 1,
      aangemaakt_door TEXT,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP, kleur TEXT DEFAULT NULL,
      FOREIGN KEY (categorie) REFERENCES dropdown_categories(categorie),
      UNIQUE(categorie, waarde)
    );
CREATE TABLE gebruikers (
      gebruiker_id INTEGER PRIMARY KEY AUTOINCREMENT,
      gebruikersnaam TEXT UNIQUE NOT NULL,
      wachtwoord_hash TEXT NOT NULL,
      volledige_naam TEXT,
      email TEXT,
      rol TEXT DEFAULT 'gebruiker',
      actief INTEGER DEFAULT 1,
      laatste_login DATETIME,
      aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE zaak_directies (
      zaak_id TEXT NOT NULL,
      directie TEXT NOT NULL,
      PRIMARY KEY (zaak_id, directie),
      FOREIGN KEY (zaak_id) REFERENCES zaken(zaak_id) ON DELETE CASCADE
    );
CREATE INDEX idx_zaak_directies_zaak_id ON zaak_directies(zaak_id);
CREATE INDEX idx_zaak_directies_directie ON zaak_directies(directie);
CREATE INDEX idx_zaak_directies_composite ON zaak_directies(zaak_id, directie);
CREATE INDEX idx_dropdown_categorie_waarde ON dropdown_opties(categorie, waarde);
CREATE INDEX idx_dropdown_categorie_actief ON dropdown_opties(categorie, actief);
CREATE INDEX idx_dropdown_weergave_naam ON dropdown_opties(weergave_naam);
CREATE INDEX idx_gebruikers_naam ON gebruikers(gebruikersnaam);
CREATE INDEX idx_gebruikers_actief ON gebruikers(actief);
CREATE TABLE deadline_kleuren_backup(
  id INT,
  dagen_voor INT,
  dagen_tot INT,
  beschrijving TEXT,
  kleur TEXT,
  actief NUM,
  aangemaakt_door TEXT,
  aangemaakt_op NUM,
  gewijzigd_door TEXT,
  laatst_gewijzigd NUM,
  prioriteit INT
);
CREATE TABLE IF NOT EXISTS "deadline_kleuren" (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dagen_voor INTEGER,
  dagen_tot INTEGER, 
  beschrijving TEXT,
  kleur TEXT,
  actief BOOLEAN DEFAULT 1,
  aangemaakt_door TEXT,
  aangemaakt_op DATETIME,
  gewijzigd_door TEXT,
  laatst_gewijzigd DATETIME
);
CREATE TABLE gebruiker_kolom_instellingen (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gebruiker_id INTEGER NOT NULL,
    kolom_naam TEXT NOT NULL,
    zichtbaar BOOLEAN DEFAULT 1,
    aangemaakt_op DATETIME DEFAULT CURRENT_TIMESTAMP, volgorde INTEGER DEFAULT 999,
    FOREIGN KEY (gebruiker_id) REFERENCES gebruikers(gebruiker_id),
    UNIQUE(gebruiker_id, kolom_naam)
);
CREATE TABLE IF NOT EXISTS "zaken" (
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
      );
