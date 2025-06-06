# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a "Dashboard Landsadvocaat" - a government legal case management system for the Dutch Ministry of Education, Culture and Science (OCW). It's built with R Shiny and uses a modular architecture for managing legal activities and procedures.

## Communication

- Development communication in Dutch (Nederlandse taal)
- Git commit messages in Dutch
- User interface in Dutch

## Development Commands

### Running the Application
```r
# From R console in project directory
shiny::runApp()

# Or open app.R in RStudio and click "Run App"
```

### Database Setup and Management
```r
# Initial database setup (run once)
source("setup/initial_data.R")
complete_database_setup_fixed()

# Load database utilities
source("utils/database.R")

# Test database connection
con <- get_db_connection()

# Excel import operations (current production script)
source("import_excel_jaar_tabbladen.R")

# Key database functions available:
# - lees_zaken() - Read cases with filtering
# - voeg_zaak_toe() - Add new case with many-to-many directies support
# - update_zaak() - Update existing case with many-to-many directies support
# - verwijder_zaak() - Delete case
# - get_dropdown_opties() - Get dropdown choices
# - get_zaak_directies() - Get directies for a specific case
# - controleer_login() - Verify user credentials
```

### Package Management
```r
# Restore packages from lockfile
renv::restore()

# Update lockfile after adding packages
renv::snapshot()

# Check project status
renv::status()
```

## Architecture Overview

### Modular Structure
The application follows a strict modular pattern with each feature having separate UI and server files:
- `modules/login/` - Authentication system with role-based access
- `modules/data_management/` - Main case management (zaakbeheer) with CRUD operations and Excel export
- `modules/filters/` - Advanced filtering system with accordion-based UI
- `modules/instellingen/` - Admin interface for user and dropdown management
- `modules/analyse/` - Analytics dashboard with KPIs, charts, and multi-tab Excel export

### Core Files
- `app.R` - Application entry point with configuration
- `global.R` - Central configuration, themes, and library loading
- `ui.R` - Main UI with conditional authentication layout
- `server.R` - Server logic and module coordination
- `utils/database.R` - Database abstraction layer with helper functions

### Database Architecture
Uses SQLite (`data/landsadvocaat.db`) with these key tables:
- `zaken` - Main legal cases with financial tracking
- `zaak_directies` - Many-to-many relationship between cases and directies
- `gebruikers` - User management with hashed passwords
- `dropdown_opties` & `dropdown_categories` - Configurable UI dropdowns

### Authentication System
- Role-based access (admin/user) with SHA-256 password hashing
- Default accounts: admin/admin123, test/test123
- Session-based authentication with reactive state management

## Key Development Patterns

### Database Operations
Always use the helper functions in `utils/database.R` for database operations. The application uses dbplyr for type-safe queries and proper connection management.

Key patterns:
- Use `tbl_zaken()`, `tbl_gebruikers()`, `tbl_dropdown_opties()` for table references
- All CRUD operations have dedicated helper functions
- Database connections are managed automatically by helper functions
- **NEW**: Directies are managed via many-to-many table `zaak_directies`

### Module Development
When creating new modules, follow the existing pattern:
- Create both `module_name_ui.R` and `module_name_server.R`
- Use proper namespacing with module IDs
- Include reactive data refresh triggers for real-time updates
- Load modules in `global.R` and initialize in `server.R`

### Styling and Theming
The application uses Bootstrap 5 with OCW government branding. Maintain professional government styling and ensure accessibility compliance.

### Security Considerations
- Always validate user inputs
- Use proper authentication checks before displaying sensitive data
- Hash passwords using the existing digest implementation
- Respect role-based access controls throughout the application

### Git Commit Guidelines
- Write commit messages in Dutch
- **NEVER include Claude Code attribution or any AI references in commit messages**
- Do not add "Generated with Claude Code" or "Co-Authored-By: Claude" lines
- Focus on clear, concise descriptions of what was changed and why
- Use conventional commit format when appropriate (feat:, fix:, docs:, etc.)

## Technology Stack

**Core**: R Shiny with bslib (Bootstrap 5), DT for tables, shinyWidgets for enhanced UI
**Database**: SQLite with DBI/RSQLite, dbplyr for modern R database interaction
**Security**: digest for password hashing, session-based authentication
**Data**: dplyr/tidyr for manipulation, plotly/ggplot2 for visualization
**Visualization**: plotly for interactive charts, ggplot2 for static plots, RColorBrewer for colors
**UI Enhancement**: colourpicker for color management in dropdowns
**Export**: writexl for Excel generation with multi-tab support

## Important Implementation Notes

### Many-to-Many Directies System (IMPLEMENTED)
- **Database Structure**: `zaak_directies` table with `zaak_id` and `directie` columns
- **UI**: Multi-select dropdown using `selectizeInput` with `multiple = TRUE`
- **Helper Functions**: 
  - `get_zaak_directies(zaak_id)` - Returns array of directie values for a case
  - `voeg_zaak_toe(zaak_data, gebruiker, directies = NULL)` - Add case with directies
  - `update_zaak(zaak_id, zaak_data, gebruiker, directies = NULL)` - Update case with directies
- **Form Validation**: Only "Zaak ID", "Datum Aanmaak" and "Status" are required fields

### Dropdown Management System
- **Safe deletion**: When deleting dropdown values in use, they are replaced with "niet_ingesteld" 
- **Protected values**: "niet_ingesteld" values cannot be deleted (no delete button shown)
- **Edit behavior**: Only weergave_naam (display name) is editable, database values remain unchanged
- **Supported categories**: type_dienst, rechtsgebied, status_zaak, aanvragende_directie, type_wederpartij, reden_inzet, hoedanigheid_partij
- **Excluded categories**: civiel_bestuursrecht was removed due to overlap with rechtsgebied

### Database Helper Functions
Key functions for dropdown management:
- `verwijder_dropdown_optie()` - Safe deletion with fallback replacement
- `get_dropdown_opties(exclude_fallback = TRUE)` - Excludes "niet_ingesteld" from user selections
- `get_weergave_naam()` - Converts database values to display names

### Module Architecture Notes
- Use reactiveVal() instead of hidden inputs for storing modal state
- All dropdown categories require both UI and server components
- Database operations use helper functions in utils/database.R
- Real-time refresh triggers ensure UI updates after changes
- Modules use filtered_data reactive from filter module for consistency

## Analyse Module

### Features Implemented
- **KPI Dashboard**: Total cases, average duration, open cases, financial risk
- **Looptijd Analyse**: Duration calculations with grouping by category (bar charts via ggplot2 + plotly)
- **Verdeling Analyse**: Distribution analysis with pie charts (plotly)
- **Multi-tab Excel Export**: KPI overview, duration analysis, distribution analysis, filtered raw data
- **Sidebar Filter Integration**: Uses same filtered_data reactive as zaakbeheer module

### Key Functions
- `looptijd_data()` - Calculates case durations based on datum_aanmaak and current date
- `analysis_data()` - Wraps filtered_data to exclude deleted cases
- Multi-tab Excel export with proper formatting and Dutch column names

### Visualization Libraries
- **ggplot2**: For duration bar charts with proper styling
- **plotly**: For interactive charts and pie charts without legends
- **RColorBrewer**: For consistent color schemes in charts

## Excel Export Patterns

### Single-Tab Export (Zaakbeheer)
- Uses `downloadHandler` with `writexl::write_xlsx()`
- Exports filtered data with proper Dutch column names
- Database values converted to display names using `get_weergave_naam()`
- Filename format: `Zaken_Export_YYYYMMDD_HHMMSS.xlsx`

### Multi-Tab Export (Analyse)
- **Tab 1**: KPI Overview with timestamp
- **Tab 2**: Duration analysis summary statistics
- **Tab 3**: Distribution analysis counts and percentages  
- **Tab 4**: Complete filtered raw data
- Uses `list()` structure for multiple sheets in `writexl::write_xlsx()`
- Filename format: `Analyse_Export_YYYYMMDD_HHMMSS.xlsx`

### Export Formatting Standards
- Dutch column names for user readability
- Database values → display names conversion
- Currency values as numbers for Excel calculations
- Dates in dd-mm-yyyy format
- Empty/NA values as empty strings

## Current Development Status

### Branch: feature/excel-import

### ✅ VOLTOOID - Excel Import, UI Uitbreidingen & Kleurenbeheersysteem

#### **Database & Import Structuur:**
- ✅ `zaak_directies` many-to-many tabel geïmplementeerd
- ✅ **Nieuw**: `kleur` kolom toegevoegd aan `dropdown_opties` tabel
- ✅ **Nieuwe import focus**: Alleen jaar-tabbladen (2020-2024) - 74 relevante zaken
- ✅ Status waarden bijgewerkt: "lopend" → "Lopend" (met hoofdletter)
- ✅ Excel import script `import_excel_jaar_tabbladen.R` met verbeterde datum/ID parsing

#### **UI/UX Uitbreidingen:**
- ✅ **Administratieve velden** toegevoegd aan formulieren:
  - Kostenplaats, Intern Ordernummer, Grootboekrekening, Budgetcode
  - ProZa-link, Locatie Formulier, Budget Beleid (tekstveld)
- ✅ **Kleurenbeheersysteem** in instellingen module:
  - Color picker (colourpicker package) voor dropdown waarden
  - Visuele kleur badges in dropdown overzicht tabel
  - Gekleurde status indicators in zaakbeheer tabel
- ✅ **Verbeterde forms**: Nieuw toevoegen & bewerken ondersteunen alle nieuwe velden

#### **Kleuren & Styling:**
- ✅ **Status kleuren geïmplementeerd**:
  - Open: `#17a2b8` (blauw), Lopend: `#ffc107` (geel)
  - Afgerond: `#28a745` (groen), In_behandeling: `#fd7e14` (oranje)
  - On_hold: `#6c757d` (grijs), NIET_INGESTELD: `#e9ecef` (lichtgrijs)
- ✅ **Helper functie**: `get_status_kleuren()` voor dynamische kleur ophaling
- ✅ **Zaakbeheer tabel**: Status kolom toont gekleurde badges

#### **Database Functionaliteit:**
- ✅ **CRUD operations** ondersteunen alle nieuwe administratieve velden
- ✅ **Details modal** toont alle administratieve gegevens in georganiseerde secties
- ✅ **Excel export** bevat alle nieuwe velden met Nederlandse kolomnamen
- ✅ **Dropdown beheer** volledig geïntegreerd met kleurenbeheersysteem

#### **Package Management:**
- ✅ `colourpicker` package toegevoegd en geïnstalleerd
- ✅ `renv.lock` bijgewerkt met nieuwe dependencies
- ✅ Alle modules laden succesvol met nieuwe functionaliteit

### 🎯 PRODUCTIERIJPE FEATURES

#### **Volledig Geïmplementeerd:**
1. **Excel Import**: Focus op recente data (74 zaken uit 2020-2024)
2. **Administratieve Velden**: Volledige ondersteuning voor ministerie-specifieke gegevens
3. **Kleurenbeheersysteem**: 
   - Visuele status indicators met configureerbare kleuren per dropdown waarde
   - Achtergrondkleuren in tabel met zwarte tekst voor optimale leesbaarheid
   - Wit (#FFFFFF) = geen kleur optie in color picker
   - Kleuren kunnen worden toegevoegd en verwijderd per dropdown waarde
4. **Many-to-Many Directies**: Volledig operationeel multi-select systeem
5. **UI/UX**: Professionele overheidsstijl met Bootstrap 5 integratie

#### **Database Status (ACTUEEL):**
- **Zaken**: 74 records uit jaar-tabbladen (2020-2024) met echte Excel datums  
- **Status Verdeling**: Alle zaken hebben status "Lopend" met gele (#ffc107) achtergrondkleur
- **Administratieve Velden**: Kostenplaats, grootboek, budgetcodes waar beschikbaar
- **Kleuren**: 
  - Status kleuren: 5 waarden (Lopend geel, Afgerond groen, etc.)
  - Directie kleuren: 2 waarden (Financieel-Economische Zaken oranje, Hoger Onderwijs geel)
  - Andere categorieën: Klaar voor kleurtoewijzing via instellingen
- **Gebruikers**: 5 users (admin, test, Hans, excel_import, system)

#### **Belangrijke Scripts:**
- `import_excel_jaar_tabbladen.R` - Hoofdimport script voor productiedata (2020-2024 jaar-tabbladen)
- `utils/database.R` - Uitgebreid met `get_status_kleuren()` en `get_dropdown_kleuren()` helper functies
- `modules/data_management/` - Volledig uitgebreid met administratieve velden en kleurenweergave
- `modules/instellingen/` - Kleurenbeheersysteem met wit = geen kleur optie

#### **Import Script Versies:**
- `import_excel_jaar_tabbladen.R` - **HUIDIGE PRODUCTIE**: Focus op jaar-tabbladen (74 zaken)
- `import_excel_to_db_v2.R` - Vorige versie met volledige Excel parsing
- `import_excel_to_db.R` - Originele import script

### 🔄 MOGELIJKE TOEKOMSTIGE UITBREIDINGEN

**Low Prioriteit:**
1. **Import Script Verfijning**: Meer directie afkortingen toevoegen aan mapping
2. **User Management**: Debug instellingen tab voor gebruiker weergave
3. **Excel Import Optimalisatie**: Edge cases in data parsing verbeteren
4. **Kleurenschema's**: Uitbreiden naar andere dropdown categorieën

### 📋 SYSTEEMSTATUS: PRODUCTIERIJP ✅
Het dashboard is volledig functioneel met alle gewenste administratieve en visuele functionaliteit geïmplementeerd.