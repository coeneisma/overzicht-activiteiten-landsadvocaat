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
- `modules/data_management/` - Main case management (zaakbeheer) with CRUD operations
- `modules/filters/` - Advanced filtering system with accordion-based UI
- `modules/instellingen/` - Admin interface for user and dropdown management

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
- Do not include Claude Code attribution in commit messages
- Focus on clear, concise descriptions of what was changed and why
- Use conventional commit format when appropriate (feat:, fix:, docs:, etc.)

## Technology Stack

**Core**: R Shiny with bslib (Bootstrap 5), DT for tables, shinyWidgets for enhanced UI
**Database**: SQLite with DBI/RSQLite, dbplyr for modern R database interaction
**Security**: digest for password hashing, session-based authentication
**Data**: dplyr/tidyr for manipulation, plotly/ggplot2 for visualization

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

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.