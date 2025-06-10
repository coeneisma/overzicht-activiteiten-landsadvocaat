# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Dashboard Landsadvocaat** - A government legal case management system for the Dutch Ministry of Education, Culture and Science (OCW). Built with R Shiny using a modular architecture for managing legal activities and procedures.

### Communication Standards
- Development communication in Dutch (Nederlandse taal)
- Git commit messages in Dutch
- User interface in Dutch
- **NEVER include Claude Code attribution or AI references in commit messages**

## Quick Start

### Running the Application
```r
# From R console in project directory
shiny::runApp()
# Or open app.R in RStudio and click "Run App"
```

### Database Setup
```r
# Initial setup (run once)
source("setup/initial_data.R")
complete_database_setup_fixed()

# Test connection
source("utils/database.R")
con <- get_db_connection()
```

### Package Management
```r
renv::restore()    # Restore packages
renv::snapshot()   # Update lockfile
renv::status()     # Check status
```

## Architecture

### Module Structure
- `modules/login/` - Authentication with role-based access
- `modules/data_management/` - CRUD operations and Excel export
- `modules/filters/` - Advanced filtering system
- `modules/instellingen/` - Admin interface
- `modules/analyse/` - Analytics dashboard
- `modules/bulk_upload/` - Excel import with 5-step wizard

### Core Files
- `app.R` - Entry point
- `global.R` - Configuration and libraries
- `ui.R` / `server.R` - Main UI and logic
- `utils/database.R` - Database abstraction layer

### Database Schema
SQLite database (`data/landsadvocaat.db`):
- `zaken` - Legal cases with financial tracking
- `zaak_directies` - Many-to-many case-directie relationships
- `gebruikers` - Users with hashed passwords
- `dropdown_opties` - Configurable dropdown values
- `deadline_kleuren` - Deadline warning ranges
- `gebruiker_kolom_instellingen` - User column preferences

## Development Guidelines

### Database Operations
Always use helper functions from `utils/database.R`:
- `lees_zaken()` - Read cases with filtering
- `voeg_zaak_toe()` - Add case with directies
- `update_zaak()` - Update case with directies
- `verwijder_zaak()` - Delete case
- `get_dropdown_opties()` - Get dropdown choices
- `get_zaken_met_directies_optimized()` - Optimized case loading

### Database Migrations (REQUIRED)
For EVERY database change:
1. Make changes in development
2. Create migration script in `migrations/`
3. Test on database copy
4. Commit migration + code together

Migration naming: `XXX_description.sql` (e.g., `002_add_deadline_column.sql`)

### Security
- Validate all user inputs
- Use SHA-256 password hashing
- Respect role-based access controls
- Default accounts: admin/admin123, test/test123

### Module Development
- Create both `module_ui.R` and `module_server.R`
- Use proper namespacing
- Include reactive refresh triggers
- Load in `global.R`, initialize in `server.R`

## Technology Stack

- **Core**: R Shiny, bslib (Bootstrap 5), DT
- **Database**: SQLite, DBI/RSQLite, dbplyr
- **Security**: digest (SHA-256)
- **Data**: dplyr, tidyr, plotly, ggplot2
- **UI**: shinyWidgets, colourpicker, sortable
- **Export**: writexl, readxl
- **Validation**: stringdist (fuzzy matching)

## Key Features

### Authentication & Authorization
- Role-based access (admin/user)
- Session-based authentication
- User-specific column visibility

### Data Management
- Full CRUD operations
- Many-to-many directies support
- Deadline tracking with color coding
- 30+ database fields
- Advanced filtering

### Admin Features
- User management
- Dropdown configuration with colors
- Deadline range configuration
- Column visibility per user

### Bulk Upload
- 5-step wizard workflow
- Fuzzy matching validation
- Template generation
- Error correction interface

### Performance Optimizations
- Single JOIN query for cases (98% faster)
- Database indexes on key columns
- In-memory dropdown caching
- Bulk data conversions

### Export Capabilities
- Single-tab zaakbeheer export
- Multi-tab analyse export
- Dutch column names
- All fields included

## Important Implementation Notes

### Many-to-Many Directies
- Uses `zaak_directies` junction table
- Multi-select UI with `selectizeInput`
- Comma-separated in Excel imports

### Dropdown System
- NULL/NA for empty values (no "niet_ingesteld")
- Safe deletion with NULL replacement
- Color coding support
- 7 configurable categories

### Deadline Management
- Non-overlapping ranges
- Negative = before deadline, positive = after
- Four default ranges (>week, <week, today, overdue)
- Configurable colors per range

### Column Management
- User-specific visibility
- Drag-drop ordering
- 28 configurable columns
- Zaak ID always visible

## Current Status

**Branch**: feature/ui-improvements

**Production Ready Features**:
- Complete CRUD operations
- Excel import/export
- User authentication
- Deadline tracking
- Bulk upload
- Performance optimizations
- Column management

**Database**: 74 cases from 2020-2024 Excel sheets

## Development Reminders

- Test migrations before committing
- Clear dropdown cache after changes
- Use optimized functions (`_optimized`, `_cached`)
- Maintain Dutch language throughout
- Follow existing code patterns
- No AI attribution in commits