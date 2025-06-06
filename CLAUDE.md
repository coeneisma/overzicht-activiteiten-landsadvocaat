# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a "Dashboard Landsadvocaat" - a government legal case management system for the Dutch Ministry of Education, Culture and Science (OCW). It's built with R Shiny and uses a modular architecture for managing legal activities and procedures.

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

# Key database functions available:
# - lees_zaken() - Read cases with filtering
# - voeg_zaak_toe() - Add new case
# - update_zaak() - Update existing case
# - verwijder_zaak() - Delete case
# - get_dropdown_opties() - Get dropdown choices
# - controleer_login() - Verify user credentials
```

### Package Management
```r
# Restore packages from lockfile
renv::restore()

# Update lockfile after adding packages
renv::snapshot()
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
**Export**: writexl for Excel generation with multi-tab support

## Important Implementation Notes

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

## Current Development Status (Excel Import Feature)

### Branch: feature/excel-import

### Completed Tasks
- ✅ Added `wjz_mt_lid` field to database and all forms (positioned after date)
- ✅ Added `contactpersoon` field to database and all forms
- ✅ Changed `aanvragende_directie` from dropdown to text input (supports multiple values)
- ✅ Reorganized field order in forms: omschrijving is form-wide after advocaat fields
- ✅ Made opmerkingen field form-wide under optional fields
- ✅ Created directory mapping proposal in `directie_mapping_voorstel.md`
- ✅ Imported 109 cases from Excel (using `import_excel_to_db_v2.R`)

### Pending Tasks
1. **Update import script** (`import_excel_to_db_v2.R`):
   - Implement directory abbreviation mapping (see `directie_mapping_voorstel.md`)
   - Extract contact person from person names in Excel (e.g., "PO/Bond" → directie: "PO", contactpersoon: "Bond")
   - Add fallback for unclear abbreviations: "Opdrachtgever onduidelijk. Waarde in Excel-bestand: [value]"
   
2. **Fix user management issue**:
   - No users visible in settings tab
   - Need to create non-deletable `excel_import` user (like admin)
   
3. **Final import**:
   - Clear database
   - Re-import with updated mapping logic

### Key Files
- `import_excel_to_db_v2.R` - Current import script
- `directie_mapping_voorstel.md` - Directory abbreviation mappings
- `modules/data_management/data_management_server.R` - Updated forms with new fields