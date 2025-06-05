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

### Module Development
When creating new modules, follow the existing pattern:
- Create both `module_name_ui.R` and `module_name_server.R`
- Use proper namespacing with module IDs
- Include reactive data refresh triggers for real-time updates

### Styling and Theming
The application uses Bootstrap 5 with OCW government branding. Maintain professional government styling and ensure accessibility compliance.

### Security Considerations
- Always validate user inputs
- Use proper authentication checks before displaying sensitive data
- Hash passwords using the existing digest implementation
- Respect role-based access controls throughout the application

## Technology Stack

**Core**: R Shiny with bslib (Bootstrap 5), DT for tables, shinyWidgets for enhanced UI
**Database**: SQLite with DBI/RSQLite, dbplyr for modern R database interaction
**Security**: digest for password hashing, session-based authentication
**Data**: dplyr/tidyr for manipulation, plotly/ggplot2 for visualization