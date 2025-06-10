# Dashboard Landsadvocaat

Een professioneel zaakbeheersysteem voor juridische activiteiten van het Ministerie van Onderwijs, Cultuur en Wetenschap (OCW). Gebouwd met R Shiny en een modulaire architectuur voor optimale schaalbaarheid en onderhoudbaarheid.

## 📋 Inhoudsopgave

- [Overzicht](#overzicht)
- [Technologie Stack](#technologie-stack)
- [Architectuur](#architectuur)
- [Installatie & Setup](#installatie--setup)
- [Database Structuur](#database-structuur)
- [Modules](#modules)
- [Configuratie & Instellingen](#configuratie--instellingen)
- [Gebruikersbeheer](#gebruikersbeheer)
- [Development Workflow](#development-workflow)
- [Performance Optimalisaties](#performance-optimalisaties)
- [Troubleshooting](#troubleshooting)

## 🎯 Overzicht

Dit dashboard biedt een complete oplossing voor het beheren van juridische zaken binnen OCW. Hoofdfunctionaliteiten:

- **Zaakbeheer**: CRUD operaties voor juridische zaken met 30+ velden
- **Gebruikersbeheer**: Role-based access control (admin/gebruiker)
- **Filtering & Zoeken**: Geavanceerde filteropties met full-text search
- **Data Analyse**: KPI dashboards met visualisaties
- **Bulk Upload**: 5-stappen wizard voor Excel imports
- **Deadline Management**: Configureerbare waarschuwingen met kleurcodering
- **Personalisatie**: Per-gebruiker kolom zichtbaarheid en volgorde

## 🛠 Technologie Stack

### Core
- **R Shiny** - Web framework
- **bslib** - Bootstrap 5 theming
- **SQLite** - Database engine

### UI Components
- **DT** - Interactieve datatables
- **shinyWidgets** - Enhanced UI elementen
- **sortable** - Drag & drop functionaliteit
- **colourpicker** - Kleurenkiezer voor dropdown beheer

### Data Processing
- **dplyr/dbplyr** - Database queries en data manipulatie
- **tidyr** - Data transformaties
- **readxl/writexl** - Excel import/export
- **stringdist** - Fuzzy matching voor bulk upload

### Visualisatie
- **plotly** - Interactieve charts
- **ggplot2** - Statische visualisaties
- **RColorBrewer** - Kleurenschema's

### Security
- **digest** - SHA-256 password hashing
- **shinyjs** - JavaScript integratie

## 🏗 Architectuur

### Directory Structuur
```
overzicht-activiteiten-landsadvocaat/
├── app.R                    # Applicatie entry point
├── global.R                 # Globale configuratie en libraries
├── ui.R                     # Hoofd UI met conditional authentication
├── server.R                 # Server logica en module coordinatie
├── utils/
│   └── database.R          # Database helper functies
├── modules/                # Feature modules
│   ├── login/             # Authenticatie systeem
│   ├── data_management/   # Zaakbeheer CRUD
│   ├── filters/          # Filter sidebar
│   ├── instellingen/     # Admin configuratie
│   ├── analyse/          # Dashboards en visualisaties
│   └── bulk_upload/      # Excel import wizard
├── migrations/            # Database migration scripts
├── setup/                # Initiële setup scripts
├── data/                 # SQLite database (niet in git)
└── media/               # Statische assets
```

### Module Architectuur

Elke module volgt een consistent patroon:
- `module_ui.R` - UI componenten met proper namespacing
- `module_server.R` - Server logica met reactive data flow
- Modules communiceren via reactive triggers voor real-time updates

### Database Layer

Het systeem gebruikt een abstractielaag in `utils/database.R` met:
- Helper functies voor alle CRUD operaties
- Automatisch connection management
- Performance-geoptimaliseerde queries met caching
- Type-safe database operaties via dbplyr

## 🚀 Deployment & Setup

### Voor Production Server Deployment

**BELANGRIJKE NOTE:** Deployment gebeurt op de `main` branch. De development branch wordt gemerged naar main voor releases.

#### Vereisten
- R versie 4.0 of hoger
- RStudio Server of Shiny Server
- SQLite3
- Git

#### Deployment Stappen

1. **Clone repository (main branch)**
```bash
git clone [repository-url]
cd overzicht-activiteiten-landsadvocaat
# Main branch wordt automatisch gebruikt
```

2. **Installeer packages via renv**
```r
# Start R in project directory
# Herstel exacte package versies
renv::restore()
```

3. **Database setup (GEAUTOMATISEERD)**
```r
# Voer VOLLEDIGE setup uit - één commando:
source("setup/deployment_setup.R")
setup_production_database()

# Dit voert automatisch uit:
# ✅ Database schema via migrations
# ✅ Alle dropdown categorieën en waarden (75 items)
# ✅ Deadline kleuren configuratie (5 ranges)
# ✅ Gebruikers: admin/admin123, test/test123
# ✅ Database indexes voor performance
```

4. **Data Import**
```r
# Start applicatie
shiny::runApp()

# Log in als admin (admin/admin123)
# Ga naar "Bulk Upload" module
# Upload Excel bestand met zaakgegevens
# Volg 5-stappen wizard voor import
```

5. **Verifieer deployment**
- Login werkt (admin/admin123)
- Alle dropdown waarden aanwezig
- Deadline kleuren actief
- Excel upload functioneert

#### Development Setup (Local)

Voor lokale development:

```r
# 1. Package setup
renv::restore()

# 2. Database setup
source("setup/deployment_setup.R")
setup_production_database()

# 3. Start app
shiny::runApp()
```

#### Belangrijke Files voor Deployment

- `migrations/001_initial_schema.sql` - Database schema
- `setup/deployment_setup.R` - Complete automated setup
- `renv.lock` - Exacte package versies
- `CLAUDE.md` - Development guidance

#### Branch Management

- **Production Deployment**: Gebruik `main` branch
- **Development Work**: Gebruik `development` branch
- **Feature Development**: Gebruik feature branches, merge naar development
- **Releases**: Merge development naar main voor deployment

## 💾 Database Structuur

### Hoofdtabellen

#### `zaken` - Juridische zaken
De centrale tabel met 30+ velden voor complete zaakregistratie:
- **Identificatie**: zaak_id (uniek), datum_aanmaak, deadline
- **Classificatie**: type_dienst, rechtsgebied, status_zaak, etc.
- **Financieel**: budgetten, kostenplaats, financieel_risico
- **Metadata**: aangemaakt_door, laatst_gewijzigd

#### `zaak_directies` - Many-to-Many relatie
```sql
CREATE TABLE zaak_directies (
  zaak_id TEXT NOT NULL,
  directie TEXT NOT NULL,
  PRIMARY KEY (zaak_id, directie),
  FOREIGN KEY (zaak_id) REFERENCES zaken(zaak_id)
)
```

#### `gebruikers` - Gebruikersbeheer
- Authenticatie met SHA-256 hashed passwords
- Role-based access: admin/gebruiker
- Activatie status en laatste login tracking

#### `dropdown_opties` - Configureerbare keuzelijsten
- 9 categorieën (type_dienst, rechtsgebied, etc.)
- Weergave namen vs database waarden
- Optionele kleurcodering per waarde

#### `deadline_kleuren` - Deadline waarschuwingen
- Non-overlapping ranges systeem
- Configureerbare kleuren per tijdsbereik
- Automatische styling in tabellen

### Performance Indexes

13 database indexes voor optimale query performance:
```sql
-- Kritieke indexes voor snelle filtering
CREATE INDEX idx_zaken_status ON zaken(status_zaak);
CREATE INDEX idx_zaken_datum ON zaken(datum_aanmaak);
CREATE INDEX idx_zaak_directies_composite ON zaak_directies(zaak_id, directie);
```

### Database Migrations

Het systeem gebruikt een migration-based approach:
1. Wijzigingen worden via genummerde SQL scripts toegevoegd
2. `migrations/migrate.R` handelt automatische uitvoering af
3. Backups worden automatisch gemaakt voor elke migration
4. Schema versie wordt bijgehouden in `schema_migrations`

**Belangrijke regel**: Bij ELKE database wijziging moet een migration script worden gemaakt!

## 📦 Modules

### 1. Login Module 🔐
- **Functie**: Gebruikersauthenticatie
- **Features**: 
  - Full-screen overlay met OCW branding
  - SHA-256 password verificatie
  - Session management
  - Rate limiting bescherming

### 2. Data Management Module 📊
- **Functie**: Complete zaakbeheer (CRUD)
- **Features**:
  - DataTable met 30+ configureerbare kolommen
  - Per-gebruiker kolom zichtbaarheid
  - Gekleurde status/deadline indicators
  - Excel export met alle velden
  - Many-to-many directies support

### 3. Filters Module 🔍
- **Functie**: Geavanceerde filtering
- **Features**:
  - Accordion-based filter groepen
  - Full-text search in alle velden
  - "Geen waarde" optie voor lege velden
  - Quick date filters (dit jaar, vorige maand, etc.)

### 4. Instellingen Module ⚙️
- **Functie**: Systeem configuratie
- **Features**:
  - **Admin tabs**: Gebruikersbeheer, Dropdown beheer, Deadline kleuren
  - **User tab**: Kolom zichtbaarheid met drag & drop volgorde
  - Kleurenkiezer voor dropdown waarden
  - Non-overlapping deadline ranges

### 5. Analyse Module 📈
- **Functie**: Management dashboards
- **Features**:
  - KPI cards (totaal, gemiddelde looptijd, etc.)
  - Interactieve charts (ggplot2 + plotly)
  - Multi-tab Excel export
  - Lazy loading voor performance

### 6. Bulk Upload Module 📤
- **Functie**: Excel bulk import
- **Features**:
  - 5-stappen wizard workflow
  - Intelligent template met dropdown validatie
  - Fuzzy matching met Jaro-Winkler algoritme
  - Interactieve correctie interface
  - Duplicate detectie

## ⚙️ Configuratie & Instellingen

### Globale Configuratie (global.R)

```r
# App metadata
APP_TITLE <- "Dashboard Landsadvocaat"
APP_VERSION <- "1.0.0"

# Database pad
DB_PATH <- "data/landsadvocaat.db"

# Upload limieten
MAX_FILE_SIZE <- 10 * 1024^2  # 10MB
ALLOWED_FILE_TYPES <- c("xlsx", "xls", "csv")
```

### Dropdown Beheer

Beheerders kunnen dropdown waarden configureren voor 9 categorieën:
- type_dienst
- rechtsgebied
- status_zaak
- aanvragende_directie
- type_procedure
- hoedanigheid_partij
- type_wederpartij
- reden_inzet
- aansprakelijkheid

**Features**:
- Toevoegen/bewerken/verwijderen van opties
- Kleurcodering per waarde
- Veilige verwijdering (vervangt gebruikte waarden met NULL)

### Deadline Management

Configureerbare deadline waarschuwingen via non-overlapping ranges:
- **Standaard ranges**:
  - Langer dan week: Groen
  - Binnen week: Oranje
  - Vandaag: Geel
  - Te laat: Rood

### Kolom Zichtbaarheid

Gebruikers kunnen individueel bepalen welke kolommen zichtbaar zijn:
- 28 configureerbare kolommen
- Drag & drop voor volgorde aanpassing
- Zaak ID altijd zichtbaar (niet uitschakelbaar)
- Reset naar standaard optie

## 👥 Gebruikersbeheer

### Rollen

1. **Admin**
   - Volledige systeemtoegang
   - Gebruikersbeheer
   - Dropdown configuratie
   - Deadline kleuren beheer

2. **Gebruiker**
   - Zaakbeheer (CRUD)
   - Analyse dashboards
   - Bulk upload
   - Eigen kolom configuratie

### Standaard Accounts

Na initiële setup:
- admin / admin123
- test / test123

**⚠️ Wijzig deze wachtwoorden direct na installatie!**

### Account Beheer

Admins kunnen via Instellingen → Gebruikersbeheer:
- Nieuwe gebruikers toevoegen
- Rollen toewijzen
- Accounts activeren/deactiveren
- Wachtwoorden resetten

## 🔄 Development Workflow

### Git Workflow

1. **Feature branches**
```bash
git checkout -b feature/nieuwe-functionaliteit
```

2. **Commit messages in het Nederlands**
```bash
git commit -m "feat: voeg deadline notificaties toe"
```

3. **Database migrations**
Bij database wijzigingen:
```sql
-- migrations/003_add_notification_table.sql
CREATE TABLE notificaties (
  -- table definition
);
```

### Testing

```r
# Test database connectie
source("utils/database.R")
test_db_connection()

# Test performance
source("test_performance.R")

# Test specifieke module
shiny::runApp(display.mode = "showcase")
```

### Package Management

```r
# Voeg nieuwe package toe
install.packages("nieuwe_package")

# Update lockfile
renv::snapshot()

# Commit beide bestanden
git add renv.lock .Rprofile
git commit -m "feat: voeg nieuwe_package toe voor functionaliteit X"
```

## ⚡ Performance Optimalisaties

Het dashboard is geoptimaliseerd voor snelheid:

### Database Optimalisaties
- **Single JOIN query** vervangt N+1 queries (98.4% sneller)
- **13 performance indexes** op veel gebruikte kolommen
- **Prepared statements** voor veiligheid en snelheid

### Caching Systeem
- **In-memory dropdown cache** voorkomt herhaalde database lookups
- **Bulk conversies** voor weergave namen
- **Automatische cache invalidatie** bij wijzigingen

### UI Optimalisaties
- **Lazy loading** voor zware modules (analyse)
- **Debouncing** voor filter inputs (300ms)
- **Server-side DataTable** processing
- **Conditional module loading** based op actieve tab

### Gemeten Verbeteringen
- Tabel laadtijd: 3.14s → 0.05s (98.4% sneller)
- Filter wijzigingen: 75-80% sneller
- Dropdown updates: 80-85% sneller

## 🔧 Troubleshooting

### Database Problemen

**Fout: Database connectie mislukt**
```r
# Herinitialiseer database
source("setup/initial_data.R")
complete_database_setup_fixed()
```

**Fout: Migration failed**
```r
# Check migration status
source("migrations/migrate.R")
check_migration_status()

# Rollback indien nodig
rollback_last_migration()
```

### Package Problemen

**Fout: Package niet gevonden**
```r
# Herstel alle packages
renv::restore()

# Of installeer specifiek package
install.packages("package_naam")
renv::snapshot()
```

### Performance Problemen

**Trage laadtijden**
```r
# Check indexes
source("setup/add_database_indexes.R")
add_all_indexes()

# Clear cache
clear_dropdown_cache()
```

### Login Problemen

**Kan niet inloggen**
```r
# Reset admin wachtwoord
source("utils/database.R")
con <- get_db_connection()
reset_admin_password()
close_db_connection(con)
```

## 📞 Support & Documentatie

### Interne Documentatie
- `migrations/README.md` - Migration instructies
- Code comments voor complexe logica

### Externe Resources
- [R Shiny Documentation](https://shiny.rstudio.com/)
- [bslib Documentation](https://rstudio.github.io/bslib/)
- [dbplyr Documentation](https://dbplyr.tidyverse.org/)

### Contact
Voor vragen over dit dashboard, neem contact op met [Coen Eisma](mailto:c.w.eisma@minocw.nl).

---

**Versie**: 1.0.0  
**Laatste update**: Januari 2025  
**Ontwikkeld voor**: Ministerie van Onderwijs, Cultuur en Wetenschap 
