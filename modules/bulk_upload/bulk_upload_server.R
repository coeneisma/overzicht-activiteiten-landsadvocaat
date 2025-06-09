# modules/bulk_upload/bulk_upload_server.R
# =======================================

# Initialize debug logging
DEBUG_LOG_FILE <- "bulk_upload_debug.log"

# Helper function to write to debug log
write_debug_log <- function(message, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste0("[", timestamp, "] [", level, "] ", message, "\n")
  
  # Write to file (append mode)
  tryCatch({
    cat(log_entry, file = DEBUG_LOG_FILE, append = TRUE)
  }, error = function(e) {
    # If file writing fails, at least show in console
    cli::cli_alert_warning("Failed to write to debug log: {e$message}")
  })
  
  # Also show in console for real-time monitoring
  if (level == "ERROR") {
    cli::cli_alert_danger(message)
  } else if (level == "WARNING") {
    cli::cli_alert_warning(message)
  } else {
    cli::cli_alert_info(message)
  }
}

bulk_upload_server <- function(id, data_refresh_trigger = NULL, filtered_data = NULL, current_user = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Initialize debug session
    write_debug_log("=== BULK UPLOAD SESSION STARTED ===")
    write_debug_log(paste("Session ID:", session$token))
    
    # Show available data count for checkbox
    output$available_data_info <- renderUI({
      if (!is.null(filtered_data)) {
        tryCatch({
          data <- filtered_data()
          count <- nrow(data)
          if (count > 0) {
            span(
              paste("(", count, "zaken beschikbaar)"),
              class = "text-muted small"
            )
          } else {
            span(
              "(Geen zaken gevonden met huidige filter)",
              class = "text-muted small"
            )
          }
        }, error = function(e) {
          span(
            "(Data niet beschikbaar)",
            class = "text-muted small"
          )
        })
      } else {
        span(
          "(Geen gefilterde data beschikbaar)",
          class = "text-muted small"
        )
      }
    })
    
    # ========================================================================
    # DOWNLOAD TEMPLATE HANDLER
    # ========================================================================
    
    output$download_template <- downloadHandler(
      filename = function() {
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        paste0("Zaken_Import_Sjabloon_", timestamp, ".xlsx")
      },
      content = function(file) {
        write_debug_log("=== TEMPLATE GENERATION STARTED ===")
        
        tryCatch({
          # Get current dropdown options for validation
          write_debug_log("Fetching dropdown options for template...")
          dropdown_opties <- list()
          dropdown_opties$type_dienst <- get_dropdown_opties("type_dienst", exclude_fallback = TRUE)
          dropdown_opties$rechtsgebied <- get_dropdown_opties("rechtsgebied", exclude_fallback = TRUE)
          dropdown_opties$status_zaak <- get_dropdown_opties("status_zaak", exclude_fallback = TRUE)
          dropdown_opties$aanvragende_directie <- get_dropdown_opties("aanvragende_directie", exclude_fallback = TRUE)
          
          # Log dropdown structure for debugging
          for (cat_name in names(dropdown_opties)) {
            options <- dropdown_opties[[cat_name]]
            write_debug_log(paste("Dropdown", cat_name, "- Count:", length(options)))
            write_debug_log(paste("  Display names (names):", paste(names(options)[1:min(3, length(options))], collapse = ", ")))
            write_debug_log(paste("  Database values (values):", paste(as.character(options)[1:min(3, length(options))], collapse = ", ")))
          }
          
          # Get existing filtered data if user requested it via checkbox
          existing_data <- NULL
          include_existing <- input$include_existing_data
          
          write_debug_log(paste("Include existing data checkbox:", include_existing))
          
          if (include_existing && !is.null(filtered_data)) {
            write_debug_log("User requested existing data - attempting to get filtered data...")
            tryCatch({
              existing_data <- filtered_data()
              write_debug_log(paste("Retrieved filtered data:", nrow(existing_data), "rows"))
            }, error = function(e) {
              write_debug_log(paste("Could not get filtered data:", e$message))
              existing_data <- NULL
            })
          } else if (include_existing) {
            write_debug_log("User requested existing data but filtered_data not available")
          } else {
            write_debug_log("User did not request existing data - using sample template")
          }
          
          # Create template data - either with existing data or sample rows
          if (!is.null(existing_data) && nrow(existing_data) > 0) {
            write_debug_log("Creating template with existing filtered data...")
            
            # Helper function to safely format dates
            safe_format_date <- function(date_vec) {
              sapply(date_vec, function(d) {
                if (is.na(d) || is.null(d)) {
                  return("")
                } else {
                  return(format(as.Date(d), "%d-%m-%Y"))
                }
              })
            }
            
            # Helper function to safely convert dropdown values
            safe_get_weergave_naam <- function(values, category) {
              sapply(values, function(v) {
                if (is.na(v) || is.null(v) || v == "") {
                  return("")
                } else {
                  # Debug logging to check conversion
                  write_debug_log(paste("Converting", category, "value:", v))
                  result <- get_weergave_naam_cached(category, v)
                  write_debug_log(paste("  Result:", result))
                  if (is.na(result) || is.null(result)) {
                    # If conversion failed, use original value
                    write_debug_log(paste("  WARNING: No display name found, using original value"))
                    return(v)
                  } else {
                    return(result)
                  }
                }
              })
            }
            
            # Convert existing data to template format
            template_data <- data.frame(
              "Zaak ID" = existing_data$zaak_id,
              "Datum Aanmaak" = safe_format_date(existing_data$datum_aanmaak),
              "Deadline" = safe_format_date(existing_data$deadline),
              "Zaakaanduiding" = ifelse(is.na(existing_data$zaakaanduiding), "", existing_data$zaakaanduiding),
              "Type Dienst" = safe_get_weergave_naam(existing_data$type_dienst, "type_dienst"),
              "Rechtsgebied" = safe_get_weergave_naam(existing_data$rechtsgebied, "rechtsgebied"),
              "Status" = safe_get_weergave_naam(existing_data$status_zaak, "status_zaak"),
              "Aanvragende Directie" = sapply(existing_data$zaak_id, function(id) {
                directies <- get_zaak_directies(id)
                if (length(directies) > 0) {
                  display_names <- sapply(directies, function(d) {
                    name <- get_weergave_naam_cached("aanvragende_directie", d)
                    if (is.na(name) || is.null(name)) "" else name
                  })
                  display_names <- display_names[display_names != ""]
                  if (length(display_names) > 0) {
                    paste(display_names, collapse = ", ")
                  } else {
                    ""
                  }
                } else {
                  ""
                }
              }),
              "Advocaat" = ifelse(is.na(existing_data$advocaat), "", existing_data$advocaat),
              "Advocatenkantoor" = ifelse(is.na(existing_data$adv_kantoor), "", existing_data$adv_kantoor),
              "Budget WJZ (€)" = ifelse(is.na(existing_data$la_budget_wjz), "", format(existing_data$la_budget_wjz, scientific = FALSE)),
              "Budget Andere Directie (€)" = ifelse(is.na(existing_data$budget_andere_directie), "", format(existing_data$budget_andere_directie, scientific = FALSE)),
              "Financieel Risico (€)" = ifelse(is.na(existing_data$financieel_risico), "", format(existing_data$financieel_risico, scientific = FALSE)),
              "Opmerkingen" = ifelse(is.na(existing_data$opmerkingen), "", existing_data$opmerkingen),
              check.names = FALSE,
              stringsAsFactors = FALSE
            )
            
            write_debug_log(paste("Template created with", nrow(template_data), "existing zaken"))
            
          } else {
            write_debug_log("Creating template with sample data...")
            
            # Create template data with sample rows and instructions
            template_data <- data.frame(
              "Zaak ID" = c("VOORBEELD-001", "VOORBEELD-002", ""),
              "Datum Aanmaak" = c("01-01-2024", "15-02-2024", ""),
              "Deadline" = c("01-06-2024", "", ""),
              "Zaakaanduiding" = c("Voorbeeld zaak 1", "Voorbeeld zaak 2", ""),
              "Type Dienst" = c(
                if(length(dropdown_opties$type_dienst) > 0) names(dropdown_opties$type_dienst)[1] else "",
                if(length(dropdown_opties$type_dienst) > 1) names(dropdown_opties$type_dienst)[2] else "",
                ""
              ),
              "Rechtsgebied" = c(
                if(length(dropdown_opties$rechtsgebied) > 0) names(dropdown_opties$rechtsgebied)[1] else "",
                if(length(dropdown_opties$rechtsgebied) > 1) names(dropdown_opties$rechtsgebied)[2] else "",
                ""
              ),
              "Status" = c(
                if(length(dropdown_opties$status_zaak) > 0) names(dropdown_opties$status_zaak)[1] else "",
                if(length(dropdown_opties$status_zaak) > 1) names(dropdown_opties$status_zaak)[2] else "",
                ""
              ),
              "Aanvragende Directie" = c(
                if(length(dropdown_opties$aanvragende_directie) > 0) names(dropdown_opties$aanvragende_directie)[1] else "",
                if(length(dropdown_opties$aanvragende_directie) > 1) paste(names(dropdown_opties$aanvragende_directie)[1:min(2, length(dropdown_opties$aanvragende_directie))], collapse = ", ") else "",
                ""
              ),
              "Advocaat" = c("Jan Jansen", "Marie de Vries", ""),
              "Advocatenkantoor" = c("Advocatenkantoor A", "Kantoor B", ""),
              "Budget WJZ (€)" = c("50000", "25000", ""),
              "Budget Andere Directie (€)" = c("", "10000", ""),
              "Financieel Risico (€)" = c("100000", "", ""),
              "Opmerkingen" = c("Dit is een voorbeeldzaak", "", ""),
              check.names = FALSE,
              stringsAsFactors = FALSE
            )
          }
          
          # Create validation lists sheet
          validation_data <- list()
          
          # Add dropdown options (use display names, not database values)
          write_debug_log("Creating validation sheet with dropdown options...")
          max_length <- max(sapply(dropdown_opties, length))
          for (categorie in names(dropdown_opties)) {
            opties <- names(dropdown_opties[[categorie]])  # Get display names (names, not values)
            write_debug_log(paste("Adding", categorie, "options to validation sheet:", paste(opties[1:min(3, length(opties))], collapse = ", ")))
            if (length(opties) < max_length) {
              opties <- c(opties, rep("", max_length - length(opties)))
            }
            validation_data[[paste("Dropdown:", categorie)]] <- opties
          }
          
          validation_df <- data.frame(validation_data, check.names = FALSE, stringsAsFactors = FALSE)
          
          # Create instructions sheet
          instructions_data <- data.frame(
            "Kolom" = c(
              "Zaak ID",
              "Datum Aanmaak", 
              "Deadline",
              "Zaakaanduiding",
              "Type Dienst",
              "Rechtsgebied", 
              "Status",
              "Aanvragende Directie",
              "Advocaat",
              "Advocatenkantoor",
              "Budget WJZ (€)",
              "Budget Andere Directie (€)",
              "Financieel Risico (€)",
              "Opmerkingen"
            ),
            "Verplicht" = c(
              "JA",
              "JA", 
              "Nee",
              "Nee",
              "Nee",
              "Nee",
              "Nee", 
              "Nee",
              "Nee",
              "Nee",
              "Nee",
              "Nee",
              "Nee",
              "Nee"
            ),
            "Beschrijving" = c(
              "Unieke identifier voor de zaak",
              "Aanmaakdatum in DD-MM-YYYY formaat",
              "Deadline datum in DD-MM-YYYY formaat (optioneel)",
              "Korte beschrijving van de zaak",
              "Selecteer uit beschikbare opties (zie Dropdown Waarden sheet)",
              "Selecteer uit beschikbare opties (zie Dropdown Waarden sheet)",
              "Selecteer uit beschikbare opties (zie Dropdown Waarden sheet)",
              "Eén of meerdere directies, gescheiden door komma's",
              "Naam van de advocaat",
              "Naam van het advocatenkantoor", 
              "Budget van WJZ in euro's (alleen cijfers)",
              "Budget van andere directie in euro's (alleen cijfers)",
              "Financieel risico in euro's (alleen cijfers)",
              "Aanvullende opmerkingen"
            ),
            check.names = FALSE,
            stringsAsFactors = FALSE
          )
          
          # Write multi-sheet Excel file
          write_debug_log("Writing Excel file with 3 sheets...")
          writexl::write_xlsx(
            list(
              "Sjabloon" = template_data,
              "Instructies" = instructions_data,
              "Dropdown Waarden" = validation_df
            ),
            path = file,
            col_names = TRUE,
            format_headers = TRUE
          )
          
          write_debug_log("=== TEMPLATE GENERATION COMPLETED SUCCESSFULLY ===")
          cli_alert_success("Excel template generated successfully")
          
        }, error = function(e) {
          cli_alert_danger("Error generating Excel template: {e$message}")
          # Create simple error file
          error_data <- data.frame("Fout" = paste("Er is een fout opgetreden bij het genereren van het sjabloon:", e$message))
          writexl::write_xlsx(list("Fout" = error_data), path = file)
        })
      },
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    # ========================================================================
    # REACTIVE VALUES & STATE MANAGEMENT
    # ========================================================================
    
    # Track current wizard step
    current_step <- reactiveVal(1)
    
    # Store uploaded data
    uploaded_data <- reactiveVal(NULL)
    upload_error <- reactiveVal("")
    file_info <- reactiveVal(NULL)
    
    # Store validation results
    validation_data <- reactiveVal(NULL)
    validation_summary <- reactiveVal(NULL)
    
    # Store corrections data
    corrections_data <- reactiveVal(NULL)
    corrections_summary <- reactiveVal(NULL)
    
    # Render dynamic wizard progress indicator
    output$wizard_progress <- renderUI({
      step <- current_step()
      
      # Helper function for circle styles
      get_circle_style <- function(current_step, target_step) {
        base_style <- "width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; margin: 0 auto 0.5rem auto; transition: all 0.3s ease;"
        
        if (current_step == target_step && current_step < 6) {
          # Active step - blue
          return(paste0(base_style, "background-color: #154273; color: white;"))
        } else if (current_step > target_step || (current_step == 6 && target_step == 5)) {
          # Completed step - green (including step 5 when import is done)
          return(paste0(base_style, "background-color: #28a745; color: white;"))
        } else {
          # Future step - gray
          return(paste0(base_style, "background-color: #e9ecef; color: #6c757d;"))
        }
      }
      
      # Helper function for label styles
      get_label_style <- function(current_step, target_step) {
        base_style <- "font-size: 0.875rem; text-align: center;"
        
        if (current_step == target_step && current_step < 6) {
          return(paste0(base_style, "color: #154273; font-weight: 600;"))
        } else if (current_step > target_step || (current_step == 6 && target_step == 5)) {
          return(paste0(base_style, "color: #28a745; font-weight: 600;"))
        } else {
          return(paste0(base_style, "color: #6c757d; font-weight: 500;"))
        }
      }
      
      div(
        class = "progress-wizard",
        style = "padding: 1rem 0;",
        div(
          class = "d-flex justify-content-between",
          
          # Step 1: Download Template
          div(
            style = "text-align: center; flex: 1; position: relative;",
            div(
              style = get_circle_style(step, 1),
              if(step > 1) icon("check") else "1"
            ),
            div(
              style = get_label_style(step, 1),
              "Sjabloon"
            )
          ),
          
          # Step 2: Upload File
          div(
            style = "text-align: center; flex: 1; position: relative;",
            div(
              style = get_circle_style(step, 2),
              if(step > 2) icon("check") else "2"
            ),
            div(
              style = get_label_style(step, 2),
              "Upload"
            )
          ),
          
          # Step 3: Validate Data
          div(
            style = "text-align: center; flex: 1; position: relative;",
            div(
              style = get_circle_style(step, 3),
              if(step > 3) icon("check") else "3"
            ),
            div(
              style = get_label_style(step, 3),
              "Validatie"
            )
          ),
          
          # Step 4: Corrections
          div(
            style = "text-align: center; flex: 1; position: relative;",
            div(
              style = get_circle_style(step, 4),
              if(step > 4) icon("check") else "4"
            ),
            div(
              style = get_label_style(step, 4),
              "Aanpassingen"
            )
          ),
          
          # Step 5: Import
          div(
            style = "text-align: center; flex: 1; position: relative;",
            div(
              style = get_circle_style(step, 5),
              if(step == 6) icon("check") else "5"
            ),
            div(
              style = get_label_style(step, 5),
              "Import"
            )
          )
        )
      )
    })
    
    # ========================================================================
    # FILE UPLOAD & PARSING
    # ========================================================================
    
    # Handle file upload
    observeEvent(input$upload_file, {
      req(input$upload_file)
      
      write_debug_log("=== FILE UPLOAD STARTED ===")
      write_debug_log(paste("File name:", input$upload_file$name))
      write_debug_log(paste("File size:", input$upload_file$size, "bytes"))
      write_debug_log(paste("File type:", input$upload_file$type))
      
      # Reset previous state
      uploaded_data(NULL)
      upload_error("")
      file_info(input$upload_file)
      
      tryCatch({
        # Validate file
        write_debug_log("Validating uploaded file...")
        if (input$upload_file$size > MAX_FILE_SIZE) {
          write_debug_log("File too large - rejecting", "ERROR")
          upload_error("Bestand is te groot (max 10MB)")
          return()
        }
        
        file_ext <- tools::file_ext(input$upload_file$name)
        write_debug_log(paste("File extension:", file_ext))
        if (!file_ext %in% c("xlsx", "xls")) {
          write_debug_log("Invalid file extension - rejecting", "ERROR")
          upload_error("Alleen Excel bestanden (.xlsx, .xls) zijn toegestaan")
          return()
        }
        
        write_debug_log(paste("Reading Excel file from:", input$upload_file$datapath))
        
        # Read Excel file
        # Read Excel with all columns as text to avoid mixed type issues
        data <- readxl::read_excel(
          input$upload_file$datapath,
          sheet = 1,  # Read first sheet
          col_names = TRUE,
          col_types = "text",  # Force all columns to text
          trim_ws = TRUE
        )
        
        # Handle date columns manually after reading
        write_debug_log(paste("Raw data read - Rows:", nrow(data), "Cols:", ncol(data)))
        write_debug_log(paste("Column names:", paste(names(data), collapse = ", ")))
        
        # Helper function to convert Excel dates to Dutch format (DD-MM-YYYY)
        convert_to_dutch_format <- function(date_value) {
          if (is.na(date_value) || date_value == "") return(NA)
          
          date_string <- as.character(date_value)
          write_debug_log(paste("Processing date value:", date_string))
          
          # Check if it's a numeric Excel date (all digits)
          if (grepl("^[0-9]+$", date_string)) {
            write_debug_log(paste("  Detected numeric Excel date:", date_string))
            
            # Excel numeric date (days since 1899-12-30)
            tryCatch({
              numeric_value <- as.numeric(date_string)
              date_obj <- as.Date(numeric_value, origin = "1899-12-30")
              
              # Validate the date is reasonable
              if (date_obj >= as.Date("1990-01-01") && date_obj <= as.Date("2030-12-31")) {
                dutch_format <- format(date_obj, "%d-%m-%Y")
                write_debug_log(paste("  Excel conversion successful:", date_string, "->", date_obj, "->", dutch_format))
                return(dutch_format)
              } else {
                write_debug_log(paste("  Excel date out of range:", date_obj, "- keeping original"), "WARNING")
                return(date_string)
              }
            }, error = function(e) {
              write_debug_log(paste("  Excel conversion failed:", e$message), "ERROR")
              return(date_string)
            })
          } else {
            # Try to parse existing string and convert to Dutch format
            write_debug_log(paste("  Detected string date:", date_string))
            
            # Try various input formats and convert to Dutch
            input_formats <- c(
              "%d-%m-%Y",     # 01-01-2024
              "%d-%m-%y",     # 01-01-24  
              "%Y-%m-%d",     # 2024-01-01
              "%m/%d/%Y",     # 01/01/2024
              "%d/%m/%Y",     # 01/01/2024
              "%Y/%m/%d"      # 2024/01/01
            )
            
            for (fmt in input_formats) {
              write_debug_log(paste("    Trying format:", fmt))
              parsed_date <- tryCatch({
                result <- as.Date(date_string, format = fmt)
                if (!is.na(result)) {
                  dutch_format <- format(result, "%d-%m-%Y")
                  write_debug_log(paste("    SUCCESS:", date_string, "via", fmt, "->", result, "->", dutch_format))
                  return(dutch_format)
                }
                NULL
              }, error = function(e) {
                write_debug_log(paste("    Failed with", fmt, ":", e$message))
                NULL
              })
              
              if (!is.null(parsed_date)) {
                return(parsed_date)
              }
            }
            
            # If no format worked, keep as-is and log warning
            write_debug_log(paste("  No format worked, keeping as-is:", date_string), "WARNING")
            return(date_string)
          }
        }
        
        if ("Datum Aanmaak" %in% names(data)) {
          write_debug_log("Processing Datum Aanmaak column to Dutch format...")
          original_dates <- data$`Datum Aanmaak`[1:min(5, nrow(data))]  # First 5 for debugging
          write_debug_log(paste("Sample original dates:", paste(original_dates, collapse = ", ")))
          
          data$`Datum Aanmaak` <- sapply(data$`Datum Aanmaak`, convert_to_dutch_format)
          
          processed_dates <- data$`Datum Aanmaak`[1:min(5, nrow(data))]
          write_debug_log(paste("Sample processed dates (Dutch format):", paste(processed_dates, collapse = ", ")))
        }
        
        if ("Deadline" %in% names(data)) {
          write_debug_log("Processing Deadline column to Dutch format...")
          data$Deadline <- sapply(data$Deadline, convert_to_dutch_format)
        }
        
        cli_alert_info("Excel file read successfully. Rows: {nrow(data)}, Cols: {ncol(data)}")
        
        # Basic validation - check required columns
        required_cols <- c("Zaak ID", "Datum Aanmaak")
        missing_cols <- required_cols[!required_cols %in% names(data)]
        
        if (length(missing_cols) > 0) {
          upload_error(paste("Verplichte kolommen ontbreken:", paste(missing_cols, collapse = ", ")))
          return()
        }
        
        # Check if data has rows
        if (nrow(data) == 0) {
          upload_error("Excel bestand bevat geen data")
          return()
        }
        
        # Store successful upload
        uploaded_data(data)
        upload_error("")
        
        cli_alert_success("File uploaded and parsed successfully: {nrow(data)} rows")
        
      }, error = function(e) {
        cli_alert_danger("Error processing Excel file: {e$message}")
        upload_error(paste("Fout bij lezen Excel bestand:", e$message))
        uploaded_data(NULL)
      })
    })
    
    # Upload status output
    output$upload_status <- renderUI({
      error_msg <- upload_error()
      data <- uploaded_data()
      
      if (error_msg != "") {
        div(
          class = "alert alert-danger",
          icon("exclamation-triangle"),
          " ", error_msg
        )
      } else if (!is.null(data)) {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          " Bestand succesvol geladen: ", strong(nrow(data)), " rijen gevonden"
        )
      } else {
        ""
      }
    })
    
    # Show preview condition
    output$show_preview <- reactive({
      !is.null(uploaded_data()) && upload_error() == ""
    })
    outputOptions(output, "show_preview", suspendWhenHidden = FALSE)
    
    # Preview table
    output$preview_table <- DT::renderDataTable({
      req(uploaded_data())
      
      data <- uploaded_data()
      
      # Show first 10 rows for preview
      preview_data <- if (nrow(data) > 10) head(data, 10) else data
      
      DT::datatable(
        preview_data,
        options = list(
          pageLength = 10,
          lengthChange = FALSE,
          searching = FALSE,
          info = TRUE,
          paging = FALSE,
          scrollX = TRUE,
          dom = 't'  # Only show table
        ),
        rownames = FALSE,
        class = 'cell-border stripe compact'
      )
    })
    
    # Enable/disable navigation buttons based on upload status
    observe({
      has_data <- !is.null(uploaded_data()) && upload_error() == ""
      
      # Use updateActionButton instead of shinyjs
      if (has_data) {
        updateActionButton(session, "btn_next_validation", disabled = FALSE)
      } else {
        updateActionButton(session, "btn_next_validation", disabled = TRUE)
      }
    })
    
    # ========================================================================
    # DATA VALIDATION ENGINE
    # ========================================================================
    
    # Fuzzy matching function
    suggest_best_match <- function(input_value, valid_options) {
      if (is.null(input_value) || is.na(input_value) || input_value == "") {
        return(list(match = "", confidence = 0, status = "empty"))
      }
      
      # Clean input
      input_clean <- tolower(trimws(as.character(input_value)))
      write_debug_log(paste("      Fuzzy matching input:", input_value, "-> cleaned:", input_clean))
      
      # Get display names for comparison
      option_names <- names(valid_options)
      if (is.null(option_names)) option_names <- valid_options
      write_debug_log(paste("      Available option names:", paste(option_names[1:min(3, length(option_names))], collapse = ", ")))
      
      # Check for exact match first (case insensitive)
      exact_match <- option_names[tolower(option_names) == input_clean]
      if (length(exact_match) > 0) {
        write_debug_log(paste("      EXACT MATCH found:", exact_match[1]))
        return(list(
          match = exact_match[1], 
          confidence = 1.0, 
          status = "exact"
        ))
      }
      
      # Try partial matching for truncated values like "Afge" -> "Afgerond" 
      partial_matches <- character(0)
      for (i in seq_along(option_names)) {
        if (grepl(paste0("^", input_clean), tolower(option_names[i]))) {
          partial_matches <- c(partial_matches, option_names[i])
        }
      }
      
      if (length(partial_matches) > 0) {
        # Found partial match - this should be a fuzzy match to show in corrections
        write_debug_log(paste("      PARTIAL MATCH found:", partial_matches[1]))
        return(list(
          match = partial_matches[1],
          confidence = 0.7,  # Good confidence but not exact
          status = "fuzzy_match",  # Show as fuzzy to allow correction
          original = input_value
        ))
      }
      
      # Fuzzy matching using string distance
      if (length(option_names) == 0) {
        write_debug_log("      NO OPTIONS available for matching", "WARNING")
        return(list(match = input_value, confidence = 0, status = "no_options"))
      }
      
      # Calculate string distances (Jaro-Winkler)
      write_debug_log("      Trying fuzzy matching with string distance...")
      distances <- stringdist::stringdist(
        input_clean, 
        tolower(option_names), 
        method = "jw"
      )
      
      best_idx <- which.min(distances)
      best_distance <- distances[best_idx]
      confidence <- 1 - best_distance
      best_match <- option_names[best_idx]
      
      write_debug_log(paste("      Best fuzzy match:", best_match, "| Distance:", round(best_distance, 3), "| Confidence:", round(confidence, 3)))
      
      # Determine status based on confidence
      if (confidence >= 0.8) {
        status <- "exact"  # Auto-accept high confidence matches
      } else if (confidence >= 0.5) {
        status <- "fuzzy_match"
      } else {
        status <- "poor_match"
      }
      
      write_debug_log(paste("      Final result - Status:", status, "| Match:", best_match))
      
      return(list(
        match = best_match,
        confidence = confidence,
        status = status,
        original = input_value
      ))
    }
    
    # Parse comma-separated directies
    parse_directies <- function(directies_string) {
      if (is.null(directies_string) || is.na(directies_string) || directies_string == "") {
        return(character(0))
      }
      
      # Split on comma and clean
      directies <- strsplit(as.character(directies_string), ",")[[1]]
      directies <- trimws(directies)
      directies <- directies[directies != ""]
      
      return(directies)
    }
    
    # Main validation function
    validate_uploaded_data <- function(data) {
      write_debug_log("=== DATA VALIDATION STARTED ===")
      write_debug_log(paste("Validating", nrow(data), "rows of data"))
      
      # Get current dropdown options
      write_debug_log("Fetching dropdown options for validation...")
      dropdown_opties <- list()
      dropdown_opties$type_dienst <- get_dropdown_opties("type_dienst", exclude_fallback = TRUE)
      dropdown_opties$rechtsgebied <- get_dropdown_opties("rechtsgebied", exclude_fallback = TRUE)
      dropdown_opties$status_zaak <- get_dropdown_opties("status_zaak", exclude_fallback = TRUE)
      dropdown_opties$aanvragende_directie <- get_dropdown_opties("aanvragende_directie", exclude_fallback = TRUE)
      
      # Debug: Log dropdown structure in detail
      write_debug_log("=== DROPDOWN OPTIONS ANALYSIS ===")
      for (cat_name in names(dropdown_opties)) {
        options <- dropdown_opties[[cat_name]]
        write_debug_log(paste("Category:", cat_name))
        write_debug_log(paste("  Total options:", length(options)))
        write_debug_log(paste("  Structure type:", class(options)))
        write_debug_log(paste("  Has names:", !is.null(names(options))))
        
        if (length(options) > 0) {
          # Show first few options in detail
          for (i in 1:min(3, length(options))) {
            display_name <- if (!is.null(names(options))) names(options)[i] else "NO_NAME"
            db_value <- as.character(options)[i]
            write_debug_log(paste("    Option", i, "- Display:", display_name, "| DB value:", db_value))
          }
        }
      }
      
      # Initialize validation results
      validation_results <- data.frame(
        row_id = 1:nrow(data),
        zaak_id = data$`Zaak ID`,
        stringsAsFactors = FALSE
      )
      
      # Counter for summary
      summary_stats <- list(
        total_rows = nrow(data),
        exact_matches = 0,
        fuzzy_matches = 0,
        poor_matches = 0,
        empty_values = 0
      )
      
      # Validate each dropdown field
      dropdown_fields <- list(
        "Type Dienst" = "type_dienst",
        "Rechtsgebied" = "rechtsgebied", 
        "Status" = "status_zaak"
      )
      
      for (field_name in names(dropdown_fields)) {
        category <- dropdown_fields[[field_name]]
        field_values <- data[[field_name]]
        
        write_debug_log(paste("=== VALIDATING FIELD:", field_name, "(category:", category, ") ==="))
        write_debug_log(paste("Field has", length(field_values), "values"))
        
        # Show sample values being validated
        sample_values <- field_values[1:min(3, length(field_values))]
        write_debug_log(paste("Sample values to validate:", paste(sample_values, collapse = ", ")))
        
        # Validate each value
        for (i in 1:length(field_values)) {
          value <- field_values[i]
          write_debug_log(paste("  Row", i, "- Validating value:", ifelse(is.na(value) || value == "", "[EMPTY]", value)))
          result <- suggest_best_match(value, dropdown_opties[[category]])
          write_debug_log(paste("    Result - Match:", result$match, "| Confidence:", round(result$confidence, 3), "| Status:", result$status))
          
          # Store results
          validation_results[[paste0(field_name, "_original")]] <- if (i == 1) character(nrow(data)) else validation_results[[paste0(field_name, "_original")]]
          validation_results[[paste0(field_name, "_suggested")]] <- if (i == 1) character(nrow(data)) else validation_results[[paste0(field_name, "_suggested")]]
          validation_results[[paste0(field_name, "_status")]] <- if (i == 1) character(nrow(data)) else validation_results[[paste0(field_name, "_status")]]
          validation_results[[paste0(field_name, "_confidence")]] <- if (i == 1) numeric(nrow(data)) else validation_results[[paste0(field_name, "_confidence")]]
          
          validation_results[i, paste0(field_name, "_original")] <- as.character(value %||% "")
          validation_results[i, paste0(field_name, "_suggested")] <- result$match
          validation_results[i, paste0(field_name, "_status")] <- result$status
          validation_results[i, paste0(field_name, "_confidence")] <- result$confidence
          
          # Update summary stats
          switch(result$status,
            "exact" = summary_stats$exact_matches <- summary_stats$exact_matches + 1,
            "fuzzy_match" = summary_stats$fuzzy_matches <- summary_stats$fuzzy_matches + 1,
            "poor_match" = summary_stats$poor_matches <- summary_stats$poor_matches + 1,
            "empty" = summary_stats$empty_values <- summary_stats$empty_values + 1
          )
        }
      }
      
      # Handle multi-directies validation
      cli_alert_info("Validating Aanvragende Directie field")
      directies_field <- data$`Aanvragende Directie`
      
      for (i in 1:length(directies_field)) {
        directies_string <- directies_field[i]
        parsed_directies <- parse_directies(directies_string)
        
        if (length(parsed_directies) == 0) {
          validation_results[i, "Aanvragende Directie_original"] <- ""
          validation_results[i, "Aanvragende Directie_suggested"] <- ""
          validation_results[i, "Aanvragende Directie_status"] <- "empty"
          validation_results[i, "Aanvragende Directie_confidence"] <- 0
          summary_stats$empty_values <- summary_stats$empty_values + 1
        } else {
          # Validate each directie
          validated_directies <- character(length(parsed_directies))
          overall_status <- "exact"
          min_confidence <- 1.0
          
          for (j in 1:length(parsed_directies)) {
            dir_result <- suggest_best_match(parsed_directies[j], dropdown_opties$aanvragende_directie)
            validated_directies[j] <- dir_result$match
            
            # Track worst status for overall assessment
            if (dir_result$status %in% c("poor_match", "fuzzy_match") && overall_status == "exact") {
              overall_status <- dir_result$status
            }
            min_confidence <- min(min_confidence, dir_result$confidence)
          }
          
          validation_results[i, "Aanvragende Directie_original"] <- as.character(directies_string %||% "")
          validation_results[i, "Aanvragende Directie_suggested"] <- paste(validated_directies, collapse = ", ")
          validation_results[i, "Aanvragende Directie_status"] <- overall_status
          validation_results[i, "Aanvragende Directie_confidence"] <- min_confidence
          
          # Update summary
          switch(overall_status,
            "exact" = summary_stats$exact_matches <- summary_stats$exact_matches + 1,
            "fuzzy_match" = summary_stats$fuzzy_matches <- summary_stats$fuzzy_matches + 1,
            "poor_match" = summary_stats$poor_matches <- summary_stats$poor_matches + 1
          )
        }
      }
      
      cli_alert_success("Data validation completed")
      
      return(list(
        results = validation_results,
        summary = summary_stats
      ))
    }
    
    # Trigger validation when user reaches validation tab
    observeEvent(current_step(), {
      if (current_step() == 3 && !is.null(uploaded_data())) {
        cli_alert_info("User reached validation step - starting validation")
        
        tryCatch({
          validation_result <- validate_uploaded_data(uploaded_data())
          validation_data(validation_result$results)
          validation_summary(validation_result$summary)
          
          cli_alert_success("Validation completed successfully")
          
        }, error = function(e) {
          cli_alert_danger("Error during validation: {e$message}")
          validation_data(NULL)
          validation_summary(NULL)
        })
      }
    })
    
    # Validation status output
    output$validation_status <- renderUI({
      summary <- validation_summary()
      
      if (is.null(summary)) {
        div(
          strong("Validatie wordt uitgevoerd..."),
          br(),
          span("Even geduld", class = "text-muted small")
        )
      } else {
        div(
          strong(paste(summary$total_rows, "rijen gevalideerd")),
          br(), br(),
          div(
            style = "text-align: left;",
            div(
              style = "color: #28a745;",
              icon("check-circle"), " ", summary$exact_matches, " exacte matches"
            ),
            div(
              style = "color: #ffc107;",
              icon("exclamation-triangle"), " ", summary$fuzzy_matches, " suggesties"
            ),
            div(
              style = "color: #dc3545;",
              icon("times-circle"), " ", summary$poor_matches, " handmatige invoer"
            ),
            if (summary$empty_values > 0) {
              div(
                style = "color: #6c757d;",
                icon("circle"), " ", summary$empty_values, " lege velden"
              )
            }
          )
        )
      }
    })
    
    # Show validation table condition
    output$show_validation <- reactive({
      !is.null(validation_data())
    })
    outputOptions(output, "show_validation", suspendWhenHidden = FALSE)
    
    # Validation results table
    output$validation_table <- DT::renderDataTable({
      req(validation_data())
      
      results <- validation_data()
      
      # Check for existing zaken and add duplicate warning
      existing_check <- sapply(results$zaak_id, function(id) {
        existing <- lees_zaken(filters = list(zaak_id = id))
        nrow(existing) > 0
      })
      
      # Create display table with color coding and duplicate info
      display_data <- data.frame(
        "Zaak ID" = results$zaak_id,
        "Status import" = ifelse(existing_check, "⚠️ BIJWERKEN", "🆕 NIEUW"),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      # Add dropdown fields with status colors
      dropdown_fields <- c("Type Dienst", "Rechtsgebied", "Status", "Aanvragende Directie")
      
      for (field in dropdown_fields) {
        original_col <- paste0(field, "_original")
        suggested_col <- paste0(field, "_suggested")
        status_col <- paste0(field, "_status")
        
        if (all(c(original_col, suggested_col, status_col) %in% names(results))) {
          display_data[[paste0(field, " (Origineel)")]] <- results[[original_col]]
          display_data[[paste0(field, " (Suggestie)")]] <- results[[suggested_col]]
          display_data[[paste0(field, " (Status)")]] <- results[[status_col]]
        }
      }
      
      dt <- DT::datatable(
        display_data,
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50),
          scrollX = TRUE,
          autoWidth = FALSE,
          dom = 'frtip'
        ),
        rownames = FALSE,
        class = 'cell-border stripe compact'
      )
      
      # Add color formatting for status columns
      status_columns <- grep("Status", names(display_data))
      
      for (col in status_columns) {
        dt <- dt %>% DT::formatStyle(
          columns = col,
          backgroundColor = DT::styleEqual(
            c("exact", "good_match", "fuzzy_match", "poor_match", "empty"),
            c("#d4edda", "#d4edda", "#fff3cd", "#f8d7da", "#e9ecef")
          ),
          color = DT::styleEqual(
            c("exact", "good_match", "fuzzy_match", "poor_match", "empty"),
            c("#155724", "#155724", "#856404", "#721c24", "#6c757d")
          )
        )
      }
      
      return(dt)
    })
    
    # Handle cell edits in validation table
    observeEvent(input$validation_table_cell_edit, {
      info <- input$validation_table_cell_edit
      
      cli_alert_info("Cell edit detected: row {info$row}, col {info$col}, value '{info$value}'")
      
      # Update validation_data with the new value
      current_data <- validation_data()
      if (!is.null(current_data)) {
        
        # Map display column to data column
        display_names <- names(validation_table_output())
        col_name <- display_names[info$col + 1]  # +1 because DT is 0-indexed
        
        cli_alert_info("Updating column: {col_name}")
        
        # Update the validation data
        # Note: This is a simplified approach - in production you'd want more robust mapping
        validation_data(current_data)
        
        # Trigger table refresh
        # The table will automatically re-render with updated data
      }
    })
    
    # Enable/disable navigation based on validation completion
    observe({
      has_validation <- !is.null(validation_data())
      
      if (has_validation) {
        updateActionButton(session, "btn_next_corrections", disabled = FALSE)
      } else {
        updateActionButton(session, "btn_next_corrections", disabled = TRUE)
      }
    })
    
    # ========================================================================
    # CORRECTIONS ENGINE
    # ========================================================================
    
    # Generate corrections data when user reaches corrections tab
    observeEvent(current_step(), {
      if (current_step() == 4 && !is.null(validation_data())) {
        cli_alert_info("User reached corrections step - generating corrections list")
        
        # Reset previous corrections data
        corrections_data(NULL)
        corrections_summary(NULL)
        
        tryCatch({
          results <- validation_data()
          
          # Find all items that need correction (fuzzy_match or poor_match)
          correction_items <- list()
          item_counter <- 1
          
          dropdown_fields <- c("Type Dienst", "Rechtsgebied", "Status", "Aanvragende Directie")
          
          for (row in 1:nrow(results)) {
            zaak_id <- results$zaak_id[row]
            
            for (field in dropdown_fields) {
              status_col <- paste0(field, "_status")
              original_col <- paste0(field, "_original")
              suggested_col <- paste0(field, "_suggested")
              confidence_col <- paste0(field, "_confidence")
              
              if (all(c(status_col, original_col, suggested_col) %in% names(results))) {
                status <- results[[status_col]][row]
                
                if (status %in% c("fuzzy_match", "poor_match")) {
                  correction_items[[item_counter]] <- list(
                    id = paste0("item_", item_counter),
                    row_id = row,
                    zaak_id = zaak_id,
                    field = field,
                    original = results[[original_col]][row],
                    suggested = results[[suggested_col]][row],
                    confidence = results[[confidence_col]][row],
                    status = status,
                    user_choice = "suggestion"  # Default to suggestion
                  )
                  item_counter <- item_counter + 1
                }
              }
            }
          }
          
          corrections_data(correction_items)
          
          # Generate summary
          fuzzy_count <- sum(sapply(correction_items, function(x) x$status == "fuzzy_match"))
          poor_count <- sum(sapply(correction_items, function(x) x$status == "poor_match"))
          
          corrections_summary(list(
            total_items = length(correction_items),
            fuzzy_matches = fuzzy_count,
            poor_matches = poor_count,
            resolved_items = 0
          ))
          
          cli_alert_success("Corrections list generated: {length(correction_items)} items")
          
          # Enable/disable the Next button based on corrections needed
          if (length(correction_items) == 0) {
            cli_alert_info("No corrections needed - enabling Next button")
            updateActionButton(session, "btn_next_import", disabled = FALSE)
          } else {
            cli_alert_info("Corrections needed - disabling Next button until resolved")
            updateActionButton(session, "btn_next_import", disabled = TRUE)
          }
          
        }, error = function(e) {
          cli_alert_danger("Error generating corrections: {e$message}")
          corrections_data(list())  # Empty list instead of NULL
          corrections_summary(list(
            total_items = 0,
            fuzzy_matches = 0,
            poor_matches = 0,
            resolved_items = 0
          ))
          # Enable button if no corrections needed due to error
          updateActionButton(session, "btn_next_import", disabled = FALSE)
        })
      }
    })
    
    # Corrections status output
    output$corrections_status <- renderUI({
      summary <- corrections_summary()
      
      if (is.null(summary)) {
        div(
          strong("Problemen worden geladen..."),
          br(),
          span("Even geduld", class = "text-muted small")
        )
      } else if (summary$total_items == 0) {
        div(
          strong("Geen problemen gevonden!"),
          br(),
          span("Alle validaties zijn correct", class = "text-success small")
        )
      } else {
        div(
          strong(paste(summary$total_items, "problemen gevonden")),
          br(), br(),
          div(
            style = "text-align: left;",
            div(
              style = "color: #ffc107;",
              icon("exclamation-triangle"), " ", summary$fuzzy_matches, " suggesties"
            ),
            div(
              style = "color: #dc3545;",
              icon("times-circle"), " ", summary$poor_matches, " handmatige keuze"
            ),
            div(
              style = "color: #28a745;",
              icon("check-circle"), " ", summary$resolved_items, " opgelost"
            )
          )
        )
      }
    })
    
    # Show corrections condition
    output$show_corrections <- reactive({
      !is.null(corrections_data()) && length(corrections_data()) > 0
    })
    outputOptions(output, "show_corrections", suspendWhenHidden = FALSE)
    
    # Generate corrections list UI
    output$corrections_list <- renderUI({
      req(corrections_data())
      
      items <- corrections_data()
      
      if (length(items) == 0) {
        return(div(
          class = "text-center p-4",
          icon("check-circle", class = "fa-3x text-success mb-3"),
          br(),
          h5("Geen problemen gevonden!"),
          p("Alle validaties zijn correct.", class = "text-muted")
        ))
      }
      
      # Get dropdown options for manual selection
      dropdown_opties <- list()
      dropdown_opties$type_dienst <- get_dropdown_opties("type_dienst", exclude_fallback = TRUE)
      dropdown_opties$rechtsgebied <- get_dropdown_opties("rechtsgebied", exclude_fallback = TRUE) 
      dropdown_opties$status_zaak <- get_dropdown_opties("status_zaak", exclude_fallback = TRUE)
      dropdown_opties$aanvragende_directie <- get_dropdown_opties("aanvragende_directie", exclude_fallback = TRUE)
      
      # Create UI for each correction item
      correction_cards <- lapply(1:length(items), function(i) {
        item <- items[[i]]
        
        # Map field to dropdown category
        category_map <- list(
          "Type Dienst" = "type_dienst",
          "Rechtsgebied" = "rechtsgebied",
          "Status" = "status_zaak", 
          "Aanvragende Directie" = "aanvragende_directie"
        )
        
        category <- category_map[[item$field]]
        options <- if (!is.null(category)) dropdown_opties[[category]] else list()
        
        # Status color
        status_color <- if (item$status == "fuzzy_match") "#ffc107" else "#dc3545"
        status_text <- if (item$status == "fuzzy_match") "Suggestie" else "Handmatige keuze"
        
        div(
          class = "card mb-3 corrections-card",
          style = paste0("border-left: 4px solid ", status_color),
          div(
            class = "card-header d-flex justify-content-between align-items-center",
            div(
              strong(paste("Probleem", i, "van", length(items))),
              " - Zaak: ", strong(item$zaak_id),
              " - Veld: ", strong(item$field)
            ),
            span(status_text, class = "badge", style = paste0("background-color: ", status_color))
          ),
          div(
            class = "card-body",
            div(
              class = "row",
              div(
                class = "col-md-6",
                h6("Originele waarde:"),
                p(if (is.null(item$original) || item$original == "") "Leeg" else item$original, 
                  class = "text-muted font-monospace")
              ),
              div(
                class = "col-md-6",
                h6("Gesuggereerde waarde:"),
                p(if (is.null(item$suggested) || item$suggested == "") "Geen suggestie" else item$suggested,
                  class = "text-success font-monospace")
              )
            ),
            
            hr(),
            
            h6("Kies uw actie:"),
            
            # Option 1: Use suggestion (if available)
            if (!is.null(item$suggested) && item$suggested != "") {
              div(
                class = "form-check mb-2",
                tags$input(
                  type = "radio",
                  class = "form-check-input",
                  name = paste0("choice_", item$id),
                  id = paste0(ns("choice_"), item$id, "_suggestion"),
                  value = "suggestion",
                  checked = "checked"
                ),
                tags$label(
                  class = "form-check-label",
                  `for` = paste0(ns("choice_"), item$id, "_suggestion"),
                  HTML(paste("✓ Gebruik suggestie:", "<strong>", item$suggested, "</strong>"))
                )
              )
            },
            
            # Option 2: Manual selection with inline dropdown
            div(
              class = "form-check mb-2",
              div(
                class = "d-flex align-items-center",
                div(
                  class = "me-3",
                  tags$input(
                    type = "radio",
                    class = "form-check-input",
                    name = paste0("choice_", item$id),
                    id = paste0(ns("choice_"), item$id, "_manual"),
                    value = "manual",
                    checked = if (is.null(item$suggested) || item$suggested == "") "checked" else NULL
                  ),
                  tags$label(
                    class = "form-check-label",
                    `for` = paste0(ns("choice_"), item$id, "_manual"),
                    "🔧 Handmatig kiezen:"
                  )
                ),
                div(
                  class = "flex-grow-1",
                  style = "min-width: 200px;",
                  conditionalPanel(
                    condition = paste0("$('input[name=\"choice_", item$id, "\"]:checked').val() == 'manual'"),
                    if (item$field == "Aanvragende Directie") {
                      # Multi-select for Aanvragende Directie
                      selectizeInput(
                        ns(paste0("manual_", item$id)),
                        label = NULL,
                        choices = names(options),
                        selected = NULL,
                        multiple = TRUE,
                        options = list(
                          placeholder = "Selecteer directies...",
                          plugins = list('remove_button'),
                          dropdownParent = 'body'  # Prevent overflow issues
                        )
                      )
                    } else {
                      # Single select for other fields with overflow prevention
                      div(
                        style = "position: relative; z-index: 1000;",
                        selectizeInput(
                          ns(paste0("manual_", item$id)),
                          label = NULL,
                          choices = c("Selecteer..." = "", names(options)),
                          selected = "",
                          multiple = FALSE,
                          options = list(
                            placeholder = "Selecteer...",
                            dropdownParent = 'body'  # Prevent overflow issues
                          )
                        )
                      )
                    }
                  )
                )
              )
            ),
            
            # JavaScript to handle radio button behavior
            tags$script(paste0("
              $('input[name=\"choice_", item$id, "\"]').change(function() {
                var selectedValue = $('input[name=\"choice_", item$id, "\"]:checked').val();
                if (selectedValue) {
                  Shiny.setInputValue('", ns(paste0("choice_", item$id)), "', selectedValue);
                }
              });
            "))
          )
        )
      })
      
      tagList(correction_cards)
    })
    
    
    # Monitor corrections completion
    observe({
      items <- corrections_data()
      
      if (!is.null(items) && length(items) > 0) {
        resolved_count <- 0
        
        for (item in items) {
          choice_id <- paste0("choice_", item$id)
          choice <- input[[choice_id]]
          
          # If no explicit choice made, check if suggestion is available (default behavior)
          if (is.null(choice)) {
            # Default behavior: if suggestion exists, it's pre-selected
            if (!is.null(item$suggested) && item$suggested != "") {
              resolved_count <- resolved_count + 1
            }
            # If no suggestion exists, it needs manual input (not resolved)
          } else {
            if (choice == "suggestion") {
              resolved_count <- resolved_count + 1
            } else if (choice == "manual") {
              manual_id <- paste0("manual_", item$id)
              manual_value <- input[[manual_id]]
              
              # Check if manual value is provided
              if (!is.null(manual_value)) {
                if (item$field == "Aanvragende Directie") {
                  # For multi-select, check if at least one option is selected
                  if (length(manual_value) > 0 && !all(manual_value == "")) {
                    resolved_count <- resolved_count + 1
                  }
                } else {
                  # For single select, check if a value is selected
                  if (manual_value != "") {
                    resolved_count <- resolved_count + 1
                  }
                }
              }
            }
          }
        }
        
        # Update summary
        summary <- corrections_summary()
        if (!is.null(summary)) {
          summary$resolved_items <- resolved_count
          corrections_summary(summary)
        }
        
        # Enable/disable import button
        # If no items, then all is resolved
        if (length(items) == 0) {
          all_resolved <- TRUE
        } else {
          all_resolved <- resolved_count == length(items)
        }
        updateActionButton(session, "btn_next_import", disabled = !all_resolved)
      }
    })
    
    # ========================================================================
    # TAB NAVIGATION
    # ========================================================================
    
    # Handle navigation to upload tab
    observeEvent(input$btn_next_upload, {
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_upload")
      current_step(2)
      cli_alert_info("User navigated to Upload tab")
    })
    
    # Handle back to template tab
    observeEvent(input$btn_back_template, {
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_template")
      current_step(1)
      cli_alert_info("User navigated back to Template tab")
    })
    
    # Handle next to validation tab
    observeEvent(input$btn_next_validation, {
      cli_alert_info("Next to validation button clicked")
      
      if (is.null(uploaded_data())) {
        cli_alert_warning("No uploaded data available for validation")
        return()
      }
      
      cli_alert_info("Navigating to validation tab...")
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_validation")
      current_step(3)
      cli_alert_success("User navigated to Validation tab")
    })
    
    # Handle back to upload tab from validation
    observeEvent(input$btn_back_upload, {
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_upload")
      current_step(2)
      cli_alert_info("User navigated back to Upload tab")
    })
    
    # Handle next to corrections tab
    observeEvent(input$btn_next_corrections, {
      req(validation_data())
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_corrections")
      current_step(4)
      cli_alert_info("User navigated to Corrections tab")
      
      # Generate corrections immediately when navigating to tab
      cli_alert_info("Generating corrections list...")
      
      tryCatch({
        results <- validation_data()
        
        # Find all items that need correction (fuzzy_match or poor_match)
        correction_items <- list()
        item_counter <- 1
        
        dropdown_fields <- c("Type Dienst", "Rechtsgebied", "Status", "Aanvragende Directie")
        
        for (row in 1:nrow(results)) {
          zaak_id <- results$zaak_id[row]
          
          for (field in dropdown_fields) {
            status_col <- paste0(field, "_status")
            original_col <- paste0(field, "_original")
            suggested_col <- paste0(field, "_suggested")
            confidence_col <- paste0(field, "_confidence")
            
            if (all(c(status_col, original_col, suggested_col) %in% names(results))) {
              status <- results[[status_col]][row]
              
              if (status %in% c("fuzzy_match", "poor_match")) {
                correction_items[[item_counter]] <- list(
                  id = paste0("item_", item_counter),
                  row_id = row,
                  zaak_id = zaak_id,
                  field = field,
                  original = results[[original_col]][row],
                  suggested = results[[suggested_col]][row],
                  confidence = results[[confidence_col]][row],
                  status = status,
                  user_choice = "suggestion"  # Default to suggestion
                )
                item_counter <- item_counter + 1
              }
            }
          }
        }
        
        corrections_data(correction_items)
        
        # Generate summary
        fuzzy_count <- sum(sapply(correction_items, function(x) x$status == "fuzzy_match"))
        poor_count <- sum(sapply(correction_items, function(x) x$status == "poor_match"))
        
        corrections_summary(list(
          total_items = length(correction_items),
          fuzzy_matches = fuzzy_count,
          poor_matches = poor_count,
          resolved_items = 0
        ))
        
        cli_alert_success("Corrections list generated: {length(correction_items)} items")
        
        # If no corrections needed, enable the Next button immediately
        if (length(correction_items) == 0) {
          updateActionButton(session, "btn_next_import", disabled = FALSE)
        }
        
      }, error = function(e) {
        cli_alert_danger("Error generating corrections: {e$message}")
        corrections_data(NULL)
        corrections_summary(NULL)
      })
    })
    
    # Handle back to validation tab from corrections
    observeEvent(input$btn_back_validation, {
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_validation")
      current_step(3)
      cli_alert_info("User navigated back to Validation tab")
    })
    
    # Handle next to import tab
    observeEvent(input$btn_next_import, {
      req(corrections_data())
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_import")
      current_step(5)
      cli_alert_info("User navigated to Import tab")
    })
    
    # Track tab changes for wizard progress
    observeEvent(input$wizard_tabs, {
      tab_mapping <- list(
        "tab_template" = 1,
        "tab_upload" = 2,
        "tab_validation" = 3,
        "tab_corrections" = 4,
        "tab_import" = 5
      )
      
      if (!is.null(input$wizard_tabs) && input$wizard_tabs %in% names(tab_mapping)) {
        step <- tab_mapping[[input$wizard_tabs]]
        current_step(step)
        cli_alert_info("User switched to wizard step {step}: {input$wizard_tabs}")
      }
    })
    
    # ========================================================================
    # STAP 5: FINALE IMPORT FUNCTIONALITEIT 
    # ========================================================================
    
    # Reactive waarden voor import
    import_data <- reactiveVal()
    import_results <- reactiveVal()
    import_completed <- reactiveVal(FALSE)
    
    # Prepare final import data when reaching step 5
    observe({
      req(input$wizard_tabs == "tab_import")
      req(uploaded_data(), corrections_data())
      
      cli_alert_info("Preparing final import data...")
      
      # Get original uploaded data
      original_data <- uploaded_data()
      corrections <- corrections_data()
      
      # Apply all corrections to create final import dataset
      final_data <- original_data
      
      # Apply auto-accepted exact matches from validation data
      validation_results <- validation_data()
      if (!is.null(validation_results)) {
        dropdown_fields <- c("Type Dienst", "Rechtsgebied", "Status", "Aanvragende Directie")
        
        for (field_name in dropdown_fields) {
          status_col <- paste0(field_name, "_status")
          suggested_col <- paste0(field_name, "_suggested")
          
          if (all(c(status_col, suggested_col) %in% names(validation_results))) {
            for (row in 1:nrow(validation_results)) {
              status <- validation_results[[status_col]][row]
              suggested <- validation_results[[suggested_col]][row]
              
              # Auto-apply exact matches (including promoted good matches)
              if (status == "exact" && !is.null(suggested) && suggested != "") {
                final_data[row, field_name] <- suggested
                write_debug_log(paste("Auto-applied exact match for row", row, field_name, ":", suggested))
              }
            }
          }
        }
      }
      
      # Apply corrections based on user choices (only for fuzzy/poor matches)
      if (!is.null(corrections) && length(corrections) > 0) {
        for (item in corrections) {
          row_idx <- item$row_id
          field_name <- item$field
          choice_id <- paste0("choice_", item$id)
          choice <- input[[choice_id]]
          
          # Determine final value based on user choice
          final_value <- NULL
          
          if (is.null(choice) && !is.null(item$suggested) && item$suggested != "") {
            # Default: use suggestion if available
            final_value <- item$suggested
          } else if (!is.null(choice)) {
            if (choice == "suggestion") {
              final_value <- item$suggested
            } else if (choice == "manual") {
              manual_id <- paste0("manual_", item$id)
              manual_value <- input[[manual_id]]
              
              if (field_name == "Aanvragende Directie") {
                # For multi-select, join with comma
                if (!is.null(manual_value) && length(manual_value) > 0) {
                  final_value <- paste(manual_value, collapse = ", ")
                }
              } else {
                final_value <- manual_value
              }
            }
          }
          
          # Apply correction to final data
          if (!is.null(final_value) && final_value != "") {
            final_data[row_idx, field_name] <- final_value
            write_debug_log(paste("Applied user correction for row", row_idx, field_name, ":", final_value))
          }
        }
      }
      
      import_data(final_data)
      
      # DEBUG: Save import overview for analysis
      tryCatch({
        write.csv(final_data, "debug_import_overview.csv", row.names = FALSE)
        write_debug_log(paste("DEBUG: Saved import overview to debug_import_overview.csv with", nrow(final_data), "rows and", ncol(final_data), "columns"))
        write_debug_log(paste("DEBUG: Column names:", paste(names(final_data), collapse = ", ")))
      }, error = function(e) {
        write_debug_log(paste("DEBUG: Error saving import overview:", e$message), "WARNING")
      })
      
      cli_alert_success("Final import data prepared: {nrow(final_data)} rows")
    })
    
    # Import status summary
    output$import_status <- renderUI({
      req(import_data())
      
      data <- import_data()
      
      # Check for duplicates
      existing_zaken <- sapply(data$`Zaak ID`, function(id) {
        existing <- lees_zaken(filters = list(zaak_id = id))
        nrow(existing) > 0
      })
      
      duplicate_count <- sum(existing_zaken)
      new_count <- sum(!existing_zaken)
      
      if (import_completed()) {
        results <- import_results()
        if (!is.null(results)) {
          div(
            h6("Import Voltooid!", class = "text-success"),
            p(paste("Succesvol:", results$success_count), class = "text-success small"),
            p(paste("Fouten:", results$error_count), class = "text-danger small"),
            p(paste("Totaal:", nrow(data)), class = "text-muted small")
          )
        }
      } else {
        warning_card <- NULL
        if (duplicate_count > 0) {
          warning_card <- div(
            class = "alert alert-warning mb-3",
            icon("exclamation-triangle"),
            strong(" Waarschuwing: "),
            paste(duplicate_count, "zaken bestaan al en worden bijgewerkt."),
            br(),
            tags$small("Bestaande data wordt overschreven met de nieuwe waarden uit Excel.")
          )
        }
        
        div(
          h6("Klaar voor Import!", class = "text-primary"),
          p(paste(nrow(data), "zaken klaar voor import"), class = "small"),
          if (new_count > 0) p(paste("🆕", new_count, "nieuwe zaken"), class = "small text-success"),
          if (duplicate_count > 0) p(paste("⚠️", duplicate_count, "bestaande zaken (worden bijgewerkt)"), class = "small text-warning"),
          warning_card,
          hr(),
          actionButton(
            ns("btn_start_import"),
            "Start Import",
            class = "btn-success btn-lg",
            icon = icon("upload")
          )
        )
      }
    })
    
    # Import preview table
    output$import_preview <- renderUI({
      req(import_data())
      
      data <- import_data()
      
      # Show preview of final data
      DT::dataTableOutput(ns("import_preview_table"))
    })
    
    output$import_preview_table <- DT::renderDataTable({
      req(import_data())
      
      data <- import_data()
      
      # Show all columns in readable format
      display_data <- data
      
      # Convert any remaining database values to display names
      dropdown_field_mapping <- list(
        "Type Dienst" = "type_dienst",
        "Rechtsgebied" = "rechtsgebied", 
        "Status" = "status_zaak"
      )
      
      for (field in names(dropdown_field_mapping)) {
        if (field %in% names(display_data)) {
          category <- dropdown_field_mapping[[field]]
          display_data[[field]] <- sapply(display_data[[field]], function(x) {
            if (is.null(x) || is.na(x) || x == "") return("")
            tryCatch({
              get_weergave_naam_cached(category, x)
            }, error = function(e) {
              # Return original value if conversion fails
              as.character(x)
            })
          })
        }
      }
      
      DT::datatable(
        display_data,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          language = list(url = '//cdn.datatables.net/plug-ins/1.10.11/i18n/Dutch.json')
        ),
        rownames = FALSE,
        class = 'cell-border stripe compact'
      )
    })
    
    # Show/hide results
    output$show_results <- reactive({
      import_completed()
    })
    outputOptions(output, "show_results", suspendWhenHidden = FALSE)
    
    # Back to corrections button
    observeEvent(input$btn_back_corrections, {
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_corrections")
      current_step(4)
      cli_alert_info("User navigated back to Corrections tab")
    })
    
    # NEW SIMPLIFIED IMPORT LOGIC - matches handmatige invoer exactly
    perform_simplified_import <- function(final_data) {
      write_debug_log("=== SIMPLIFIED IMPORT PROCESS STARTED ===")
      write_debug_log(paste("Processing", nrow(final_data), "rows"))
      
      success_count <- 0
      error_count <- 0
      error_messages <- list()
      
      for (i in 1:nrow(final_data)) {
        row <- final_data[i, ]
        zaak_id <- row$`Zaak ID`
        
        write_debug_log(paste("=== ROW", i, "- ZAAK ID:", zaak_id, "==="))
        
        result <- tryCatch({
          
          # Convert dropdown display names to database values - SIMPLIFIED
          convert_dropdown <- function(display_value, category) {
            if (is.null(display_value) || is.na(display_value) || display_value == "") {
              return(NA_character_)
            }
            
            options <- get_dropdown_opties(category, exclude_fallback = TRUE)
            
            # Find exact match by display name
            for (j in 1:length(options)) {
              if (names(options)[j] == display_value) {
                return(as.character(options[j]))
              }
            }
            
            # No match found
            write_debug_log(paste("  WARNING: No match for", display_value, "in", category), "WARNING")
            return(NA_character_)
          }
          
          # Convert date - SIMPLIFIED
          convert_date <- function(date_input) {
            if (is.null(date_input) || is.na(date_input) || date_input == "") {
              return(as.character(Sys.Date()))
            }
            
            date_str <- as.character(date_input)
            
            # Try Dutch format first
            result <- tryCatch({
              parsed <- as.Date(date_str, format = "%d-%m-%Y")
              if (!is.na(parsed)) {
                return(as.character(parsed))
              }
              return(as.character(Sys.Date()))
            }, error = function(e) as.character(Sys.Date()))
            
            return(result)
          }
          
          # Convert deadline - SIMPLIFIED
          convert_deadline <- function(deadline_input) {
            if (is.null(deadline_input) || is.na(deadline_input) || deadline_input == "") {
              return(NA_character_)
            }
            
            deadline_str <- as.character(deadline_input)
            
            # Try Dutch format first
            result <- tryCatch({
              parsed <- as.Date(deadline_str, format = "%d-%m-%Y")
              if (!is.na(parsed)) {
                return(as.character(parsed))
              }
              return(NA_character_)
            }, error = function(e) NA_character_)
            
            return(result)
          }
          
          # Convert budget fields - SIMPLIFIED
          convert_budget <- function(budget_input) {
            if (is.null(budget_input) || is.na(budget_input) || budget_input == "") {
              return(NA_real_)
            }
            
            # Remove currency symbols and convert to numeric
            budget_str <- as.character(budget_input)
            budget_clean <- gsub("[^0-9.,]", "", budget_str)
            budget_clean <- gsub(",", ".", budget_clean)  # Convert comma to decimal point
            
            result <- tryCatch({
              as.numeric(budget_clean)
            }, error = function(e) NA_real_)
            
            return(result)
          }
          
          # Create zaak_data with ALL FIELDS like handmatige invoer
          zaak_data <- data.frame(
            zaak_id = zaak_id,
            datum_aanmaak = convert_date(row$`Datum Aanmaak`),
            zaakaanduiding = if (!is.null(row$Zaakaanduiding) && !is.na(row$Zaakaanduiding) && row$Zaakaanduiding != "") row$Zaakaanduiding else NA_character_,
            type_dienst = convert_dropdown(row$`Type Dienst`, "type_dienst"),
            rechtsgebied = convert_dropdown(row$Rechtsgebied, "rechtsgebied"),
            status_zaak = convert_dropdown(row$Status, "status_zaak"),
            deadline = convert_deadline(row$Deadline),
            # Additional fields from Excel
            advocaat = if (!is.null(row$Advocaat) && !is.na(row$Advocaat) && row$Advocaat != "") row$Advocaat else NA_character_,
            adv_kantoor = if (!is.null(row$Advocatenkantoor) && !is.na(row$Advocatenkantoor) && row$Advocatenkantoor != "") row$Advocatenkantoor else NA_character_,
            la_budget_wjz = convert_budget(row$`Budget WJZ (€)`),
            budget_andere_directie = convert_budget(row$`Budget Andere Directie (€)`),
            financieel_risico = convert_budget(row$`Financieel Risico (€)`),
            opmerkingen = if (!is.null(row$Opmerkingen) && !is.na(row$Opmerkingen) && row$Opmerkingen != "") row$Opmerkingen else NA_character_,
            stringsAsFactors = FALSE
          )
          
          write_debug_log(paste("  Created minimal zaak_data for:", zaak_id))
          write_debug_log(paste("  Data:", paste(capture.output(str(zaak_data)), collapse = " ")))
          
          # Handle directies - SIMPLIFIED
          directies <- NULL
          if (!is.null(row$`Aanvragende Directie`) && !is.na(row$`Aanvragende Directie`) && row$`Aanvragende Directie` != "") {
            directie_names <- trimws(strsplit(row$`Aanvragende Directie`, ",")[[1]])
            directies <- sapply(directie_names, function(name) convert_dropdown(name, "aanvragende_directie"), USE.NAMES = FALSE)
            directies <- directies[!is.na(directies)]
          }
          
          write_debug_log(paste("  Directies:", paste(directies, collapse = ", ")))
          
          # Check if zaak exists
          existing <- lees_zaken(filters = list(zaak_id = zaak_id))
          
          # Get current user name
          user_name <- "excel_import"  # Default fallback
          if (!is.null(current_user)) {
            tryCatch({
              user_name <- current_user()
              if (is.null(user_name) || user_name == "") {
                user_name <- "excel_import"
              }
            }, error = function(e) {
              write_debug_log(paste("  Error getting current user:", e$message))
              user_name <- "excel_import"
            })
          }
          
          write_debug_log(paste("  Using user:", user_name))
          
          if (nrow(existing) > 0) {
            write_debug_log(paste("  UPDATING existing zaak:", zaak_id))
            update_zaak(zaak_id, zaak_data, user_name, directies)
          } else {
            write_debug_log(paste("  ADDING new zaak:", zaak_id))
            voeg_zaak_toe(zaak_data, user_name, directies)
          }
          
          write_debug_log(paste("  SUCCESS:", zaak_id))
          "success"
          
        }, error = function(e) {
          write_debug_log(paste("  ERROR for", zaak_id, ":", e$message), "ERROR")
          return(list(error = e$message))
        })
        
        # Count results
        if (is.character(result) && result == "success") {
          success_count <- success_count + 1
        } else {
          error_count <- error_count + 1
          error_messages[[length(error_messages) + 1]] <- paste("Zaak", zaak_id, ":", if(is.list(result)) result$error else result)
        }
      }
      
      return(list(
        success_count = success_count,
        error_count = error_count,
        error_messages = error_messages,
        total_count = nrow(final_data)
      ))
    }
    
    # Start import button - NEW SIMPLIFIED LOGIC
    observeEvent(input$btn_start_import, {
      req(import_data())
      
      write_debug_log("=== STARTING NEW SIMPLIFIED IMPORT ===")
      
      # Show progress
      withProgress(message = "Importeren van zaken...", value = 0, {
        
        data <- import_data()
        total_rows <- nrow(data)
        
        # Set progress to 50% while processing
        incProgress(0.5, detail = paste("Verwerking", total_rows, "zaken..."))
        
        # Execute simplified import
        results <- perform_simplified_import(data)
        
        # Set progress to 100%
        incProgress(0.5, detail = "Voltooid!")
        
        # Store results
        import_results(results)
        import_completed(TRUE)
        
        # Update current step to show completion
        if (results$success_count > 0) {
          current_step(6)  # Set to completed state
        }
        
        write_debug_log(paste("IMPORT COMPLETED:", results$success_count, "success,", results$error_count, "errors"))
        
        # Show notification
        if (results$error_count == 0) {
          show_notification(
            paste("Import succesvol voltooid:", results$success_count, "zaken geïmporteerd"), 
            type = "message"
          )
        } else {
          show_notification(
            paste("Import voltooid met fouten:", results$success_count, "succesvol,", results$error_count, "fouten"), 
            type = "warning"
          )
        }
        
        # Disable import button and trigger data refresh
        updateActionButton(session, "btn_start_import", disabled = TRUE)
        
        if (results$success_count > 0 && !is.null(data_refresh_trigger)) {
          cli_alert_info("Triggering global data refresh for imported cases")
          data_refresh_trigger(data_refresh_trigger() + 1)
        }
      })
    })
    
    # Import results display
    output$import_results <- renderUI({
      req(import_completed(), import_results())
      
      results <- import_results()
      
      result_cards <- list()
      
      # Success summary
      if (results$success_count > 0) {
        result_cards[[length(result_cards) + 1]] <- div(
          class = "alert alert-success",
          icon("check-circle"),
          strong(" Succesvol: "), 
          paste(results$success_count, "zaken geïmporteerd")
        )
      }
      
      # Error summary and details
      if (results$error_count > 0) {
        error_details <- div(
          class = "mt-2",
          h6("Foutmeldingen:"),
          tags$ul(
            lapply(results$error_messages, function(msg) {
              tags$li(msg, class = "small text-muted")
            })
          )
        )
        
        result_cards[[length(result_cards) + 1]] <- div(
          class = "alert alert-danger",
          icon("exclamation-triangle"),
          strong(" Fouten: "), 
          paste(results$error_count, "zaken konden niet worden geïmporteerd"),
          error_details
        )
      }
      
      # Action buttons
      result_cards[[length(result_cards) + 1]] <- div(
        class = "mt-3 d-grid gap-2 d-md-flex",
        actionButton(
          ns("btn_restart_import"),
          "Nieuwe Import",
          class = "btn-primary",
          icon = icon("refresh")
        )
      )
      
      tagList(result_cards)
    })
    
    # Restart import process
    observeEvent(input$btn_restart_import, {
      # Reset all reactive values
      uploaded_data(NULL)
      validation_data(NULL)
      corrections_data(NULL)
      import_data(NULL)
      import_results(NULL)
      import_completed(FALSE)
      current_step(1)
      
      # Navigate back to step 1
      updateTabsetPanel(session, "wizard_tabs", selected = "tab_template")
      
      # Re-enable import button
      updateActionButton(session, "btn_start_import", disabled = FALSE)
      
      cli_alert_info("Import process restarted")
      show_notification("Import proces opnieuw gestart", type = "message")
    })
    
  })
}