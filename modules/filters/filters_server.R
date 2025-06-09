# modules/filters/filters_server.R
# ==============================

#' Filter Module Server
#' 
#' Handles filtering logic for case data using dbplyr
#' 
#' @param id Module namespace ID
#' @param raw_data Reactive containing unfiltered data
#' @param data_refresh_trigger Reactive value that triggers data refresh
#' @param dropdown_refresh_trigger Reactive value that triggers dropdown refresh
#' @return Reactive containing filtered data
filters_server <- function(id, raw_data, data_refresh_trigger, dropdown_refresh_trigger = reactiveVal(0)) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES
    # ========================================================================
    
    # Track if filters are initialized
    filters_initialized <- reactiveVal(FALSE)
    
    # Store dropdown choices
    dropdown_choices <- reactiveValues()
    
    # Track which filters are active
    active_filters <- reactive({
      list(
        search = !is.null(input$search_text) && nchar(input$search_text) > 0,
        type_dienst = !is.null(input$type_dienst) && length(input$type_dienst) > 0,
        rechtsgebied = !is.null(input$rechtsgebied) && length(input$rechtsgebied) > 0,
        type_procedure = !is.null(input$type_procedure) && length(input$type_procedure) > 0,
        status_zaak = !is.null(input$status_zaak) && length(input$status_zaak) > 0,
        datum_range = !is.null(input$datum_range) && 
          (!is.null(input$datum_range[1]) || !is.null(input$datum_range[2])),
        aanvragende_directie = !is.null(input$aanvragende_directie) && length(input$aanvragende_directie) > 0,
        advocaat = !is.null(input$advocaat) && length(input$advocaat) > 0,
        adv_kantoor = !is.null(input$adv_kantoor) && length(input$adv_kantoor) > 0,
        budget = (!is.null(input$budget_min) && input$budget_min > 0) || 
          (!is.null(input$budget_max) && input$budget_max > 0),
        risico = (!is.null(input$risico_min) && input$risico_min > 0) || 
          (!is.null(input$risico_max) && input$risico_max > 0),
        hoedanigheid_partij = !is.null(input$hoedanigheid_partij) && length(input$hoedanigheid_partij) > 0,
        type_wederpartij = !is.null(input$type_wederpartij) && length(input$type_wederpartij) > 0,
        reden_inzet = !is.null(input$reden_inzet) && length(input$reden_inzet) > 0,
        aansprakelijkheid = !is.null(input$aansprakelijkheid) && nchar(input$aansprakelijkheid) > 0
      )
    })
    
    # ========================================================================
    # INITIALIZE FILTER CHOICES
    # ========================================================================
    
    # Load dropdown choices from database
    observe({
      req(nrow(raw_data()) > 0)  # Only run when we have data
      
      # Trigger on data refresh or dropdown refresh
      data_refresh_trigger()
      dropdown_refresh_trigger()
      
      tryCatch({
        # Load dropdown options for each category
        dropdown_categories <- c("type_dienst", "rechtsgebied", "type_procedure", "status_zaak",
                                 "hoedanigheid_partij", "type_wederpartij", "reden_inzet",
                                 "aanvragende_directie")
        
        for (category in dropdown_categories) {
          choices <- get_dropdown_opties(category)
          dropdown_choices[[category]] <- choices
          
          # Add "Geen waarde" option for NA values (consistent for all categories)
          all_choices <- c("Alle" = "", "Geen waarde" = "__NA__", choices)
          
          # All dropdowns use selectInput - works reliably with fixed CSS
          updateSelectInput(session, category, choices = all_choices, selected = "")
        }
        
        # Load unique values from actual data for non-dropdown fields
        data <- raw_data()
        if (nrow(data) > 0) {
          
          # Advocaat choices
          advocaat_choices <- sort(unique(data$advocaat[!is.na(data$advocaat) & data$advocaat != ""]))
          if (length(advocaat_choices) > 0) {
            names(advocaat_choices) <- advocaat_choices
            updateSelectInput(session, "advocaat", choices = c("Alle" = "", advocaat_choices))
          }
          
          # Advocatenkantoor choices
          kantoor_choices <- sort(unique(data$adv_kantoor[!is.na(data$adv_kantoor) & data$adv_kantoor != ""]))
          if (length(kantoor_choices) > 0) {
            names(kantoor_choices) <- kantoor_choices
            updateSelectInput(session, "adv_kantoor", choices = c("Alle" = "", kantoor_choices))
          }
          
          # Set default date range based on data
          if (!is.null(data$datum_aanmaak) && any(!is.na(data$datum_aanmaak))) {
            min_date <- min(data$datum_aanmaak, na.rm = TRUE)
            max_date <- max(data$datum_aanmaak, na.rm = TRUE)
            
            # Set end date to today (to include all cases up to now)
            end_date <- Sys.Date()  # Always use today as end date
            updateDateRangeInput(session, "datum_range", 
                                 start = min_date, 
                                 end = end_date)
          }
        }
        
        filters_initialized(TRUE)
        cli_alert_success("Filter choices loaded successfully ({length(dropdown_categories)} categories)")
        
      }, error = function(e) {
        cli_alert_danger("Error loading filter choices: {e$message}")
        show_notification("Fout bij laden filteropties", type = "warning")
      })
    })
    
    # ========================================================================
    # QUICK DATE FILTERS
    # ========================================================================
    
    # Last month
    observeEvent(input$date_last_month, {
      end_date <- Sys.Date()
      start_date <- seq(end_date, length = 2, by = "-1 months")[2]
      updateDateRangeInput(session, "datum_range", start = start_date, end = end_date)
    })
    
    # Last quarter
    observeEvent(input$date_last_quarter, {
      end_date <- Sys.Date()
      start_date <- seq(end_date, length = 2, by = "-3 months")[2]
      updateDateRangeInput(session, "datum_range", start = start_date, end = end_date)
    })
    
    # This year
    observeEvent(input$date_this_year, {
      current_year <- format(Sys.Date(), "%Y")
      start_date <- as.Date(paste0(current_year, "-01-01"))
      end_date <- Sys.Date()
      updateDateRangeInput(session, "datum_range", start = start_date, end = end_date)
    })
    
    # ========================================================================
    # FILTERED DATA
    # ========================================================================
    
    # Main filtering logic using dbplyr approach
    filtered_data <- reactive({
      req(filters_initialized())
      
      data <- raw_data()
      
      # Return empty if no data
      if (is.null(data) || nrow(data) == 0) {
        return(data.frame())
      }
      
      # Add directies column for filtering (same logic as in data_management)
      data_with_directies <- data %>%
        rowwise() %>%
        mutate(
          directies = {
            dirs <- get_zaak_directies(zaak_id)
            if (length(dirs) == 0 || all(is.na(dirs))) {
              NA_character_
            } else {
              dirs <- dirs[!is.na(dirs) & dirs != ""]
              if (length(dirs) == 0) {
                NA_character_
              } else {
                weergave_namen <- sapply(dirs, function(d) {
                  get_weergave_naam_cached("aanvragende_directie", d)
                })
                paste(weergave_namen, collapse = ", ")
              }
            }
          }
        ) %>%
        ungroup()
      
      # Apply filters step by step
      filtered <- data_with_directies
      
      # Text search in all text fields AND dropdown display names
      if (!is.null(input$search_text) && !is.na(input$search_text) && nchar(input$search_text) > 0) {
        search_term <- tolower(input$search_text)
        
        # Helper function to get display name for dropdown search
        get_display_name_for_search <- function(category, value) {
          if (is.na(value) || value == "") return("")
          tryCatch({
            get_weergave_naam_cached(category, value)
          }, error = function(e) {
            return(as.character(value))  # Fallback to original value
          })
        }
        
        filtered <- filtered %>%
          filter(
            # Basis tekstvelden
            grepl(search_term, tolower(ifelse(is.na(zaak_id), "", zaak_id)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(zaakaanduiding), "", zaakaanduiding)), fixed = TRUE) |
              # Organisatie velden
              grepl(search_term, tolower(ifelse(is.na(proza_link), "", proza_link)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(wjz_mt_lid), "", wjz_mt_lid)), fixed = TRUE) |
              # Financiële tekstvelden
              grepl(search_term, tolower(ifelse(is.na(kostenplaats), "", kostenplaats)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(intern_ordernummer), "", intern_ordernummer)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(grootboekrekening), "", grootboekrekening)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(budgetcode), "", budgetcode)), fixed = TRUE) |
              # Advocatuur velden
              grepl(search_term, tolower(ifelse(is.na(advocaat), "", advocaat)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(adv_kantoor), "", adv_kantoor)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(adv_kantoor_contactpersoon), "", adv_kantoor_contactpersoon)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(budget_beleid), "", budget_beleid)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(advies_vertegenw_bestuursR), "", advies_vertegenw_bestuursR)), fixed = TRUE) |
              # Overige tekstvelden
              grepl(search_term, tolower(ifelse(is.na(locatie_formulier), "", locatie_formulier)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(contactpersoon), "", contactpersoon)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(opmerkingen), "", opmerkingen)), fixed = TRUE) |
              # Dropdown weergave namen (Nederlandse labels)
              grepl(search_term, tolower(sapply(type_dienst, function(x) get_display_name_for_search("type_dienst", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(type_procedure, function(x) get_display_name_for_search("type_procedure", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(rechtsgebied, function(x) get_display_name_for_search("rechtsgebied", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(hoedanigheid_partij, function(x) get_display_name_for_search("hoedanigheid_partij", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(type_wederpartij, function(x) get_display_name_for_search("type_wederpartij", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(reden_inzet, function(x) get_display_name_for_search("reden_inzet", x))), fixed = TRUE) |
              grepl(search_term, tolower(sapply(status_zaak, function(x) get_display_name_for_search("status_zaak", x))), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(aansprakelijkheid), "", aansprakelijkheid)), fixed = TRUE) |
              # Directies (comma-separated values, zoek in display names)
              grepl(search_term, tolower(ifelse(is.na(directies), "", directies)), fixed = TRUE)
          )
      }
      
      # Helper function for dropdown filtering with "Geen waarde" support
      apply_dropdown_filter <- function(data, input_values, column_name) {
        if (is.null(input_values) || length(input_values) == 0) {
          return(data)
        }
        
        # Check if "Geen waarde" (__NA__) is selected
        if ("__NA__" %in% input_values) {
          # Remove __NA__ from input_values and get the real values
          real_values <- input_values[input_values != "__NA__"]
          
          # Filter for both NA values and the selected real values
          if (length(real_values) > 0) {
            data %>% filter(is.na(!!sym(column_name)) | !!sym(column_name) %in% real_values)
          } else {
            # Only "Geen waarde" selected - filter for NA values only
            data %>% filter(is.na(!!sym(column_name)))
          }
        } else {
          # Normal filtering without NA values
          data %>% filter(!!sym(column_name) %in% input_values)
        }
      }
      
      # Dropdown filters
      filtered <- apply_dropdown_filter(filtered, input$type_dienst, "type_dienst")
      filtered <- apply_dropdown_filter(filtered, input$rechtsgebied, "rechtsgebied")
      filtered <- apply_dropdown_filter(filtered, input$type_procedure, "type_procedure")
      
      filtered <- apply_dropdown_filter(filtered, input$status_zaak, "status_zaak")
      filtered <- apply_dropdown_filter(filtered, input$hoedanigheid_partij, "hoedanigheid_partij")
      filtered <- apply_dropdown_filter(filtered, input$type_wederpartij, "type_wederpartij")
      filtered <- apply_dropdown_filter(filtered, input$reden_inzet, "reden_inzet")
      
      # Aansprakelijkheid filter (JA/NEE/NA values)
      if (!is.null(input$aansprakelijkheid) && nchar(input$aansprakelijkheid) > 0) {
        if (input$aansprakelijkheid == "__NA__") {
          # Filter for NA values
          filtered <- filtered %>% filter(is.na(aansprakelijkheid))
        } else {
          # Filter for specific value (JA or NEE)
          filtered <- filtered %>% filter(aansprakelijkheid == input$aansprakelijkheid)
        }
      }
      
      # Date range filter
      if (!is.null(input$datum_range)) {
        if (!is.null(input$datum_range[1])) {
          filtered <- filtered %>% filter(datum_aanmaak >= input$datum_range[1])
        }
        if (!is.null(input$datum_range[2])) {
          filtered <- filtered %>% filter(datum_aanmaak <= input$datum_range[2])
        }
      }
      
      # Organization filters - Directies (treated differently due to comma-separated values)
      if (!is.null(input$aanvragende_directie) && length(input$aanvragende_directie) > 0) {
        
        # Check if "Geen waarde" (__NA__) is selected
        if ("__NA__" %in% input$aanvragende_directie) {
          # Remove __NA__ from input_values and get the real values
          real_values <- input$aanvragende_directie[input$aanvragende_directie != "__NA__"]
          
          if (length(real_values) > 0) {
            # Filter for both NA directies AND the selected real values
            # Convert selected database values to display names for matching
            selected_display_names <- sapply(real_values, function(x) {
              get_weergave_naam("aanvragende_directie", x)
            })
            
            filtered <- filtered %>% 
              filter(is.na(directies) | sapply(directies, function(dirs) {
                if (is.na(dirs)) return(FALSE)  # Already handled by is.na(directies)
                any(sapply(selected_display_names, function(name) grepl(name, dirs, fixed = TRUE)))
              }))
          } else {
            # Only "Geen waarde" selected - filter for NA values only
            filtered <- filtered %>% filter(is.na(directies))
          }
        } else {
          # Normal filtering without NA values
          # Convert selected database values to display names for matching
          selected_display_names <- sapply(input$aanvragende_directie, function(x) {
            get_weergave_naam("aanvragende_directie", x)
          })
          
          filtered <- filtered %>% 
            filter(!is.na(directies) & sapply(directies, function(dirs) {
              any(sapply(selected_display_names, function(name) grepl(name, dirs, fixed = TRUE)))
            }))
        }
      }
      
      if (!is.null(input$advocaat) && length(input$advocaat) > 0) {
        filtered <- filtered %>% filter(advocaat %in% input$advocaat)
      }
      
      if (!is.null(input$adv_kantoor) && length(input$adv_kantoor) > 0) {
        filtered <- filtered %>% filter(adv_kantoor %in% input$adv_kantoor)
      }
      
      # Financial filters
      if (!is.null(input$budget_min) && !is.na(input$budget_min) && input$budget_min > 0) {
        filtered <- filtered %>% filter((la_budget_wjz + budget_andere_directie) >= input$budget_min)
      }
      
      if (!is.null(input$budget_max) && !is.na(input$budget_max) && input$budget_max > 0) {
        filtered <- filtered %>% filter((la_budget_wjz + budget_andere_directie) <= input$budget_max)
      }
      
      if (!is.null(input$risico_min) && !is.na(input$risico_min) && input$risico_min > 0) {
        filtered <- filtered %>% filter(financieel_risico >= input$risico_min)
      }
      
      if (!is.null(input$risico_max) && !is.na(input$risico_max) && input$risico_max > 0) {
        filtered <- filtered %>% filter(financieel_risico <= input$risico_max)
      }
      
      # Note: No need to filter deleted cases since they are permanently deleted
      
      return(filtered)
    }) %>% 
      debounce(300)  # Debounce for performance
    
    # ========================================================================
    # OUTPUTS
    # ========================================================================
    
    # Filtered count
    output$filtered_count <- renderText({
      count <- nrow(filtered_data())
      format(count, big.mark = ".")
    })
    
    # Has active filters indicator
    output$has_active_filters <- reactive({
      any(unlist(active_filters()))
    })
    outputOptions(output, "has_active_filters", suspendWhenHidden = FALSE)
    
    # Show apply button (for very large datasets)
    output$show_apply_button <- reactive({
      # Show apply button if raw data has more than 1000 rows
      nrow(raw_data()) > 1000
    })
    outputOptions(output, "show_apply_button", suspendWhenHidden = FALSE)
    
    # ========================================================================
    # RESET FILTERS
    # ========================================================================
    
    observeEvent(input$reset_filters, {
      
      # Reset all inputs
      updateTextInput(session, "search_text", value = "")
      
      # Reset dropdown filters - all use selectInput now
      dropdown_inputs <- c("type_dienst", "rechtsgebied", "type_procedure", "status_zaak",
                           "hoedanigheid_partij", "type_wederpartij", "reden_inzet", 
                           "aanvragende_directie", "advocaat", "adv_kantoor")
      
      for (input_id in dropdown_inputs) {
        updateSelectInput(session, input_id, selected = character(0))
      }
      
      # Reset date range to full range
      data <- raw_data()
      if (nrow(data) > 0 && !is.null(data$datum_aanmaak)) {
        min_date <- min(data$datum_aanmaak, na.rm = TRUE)
        max_date <- max(data$datum_aanmaak, na.rm = TRUE)
        # Reset to today as end date
        end_date <- Sys.Date()  # Always use today
        updateDateRangeInput(session, "datum_range", start = min_date, end = end_date)
      }
      
      # Reset numeric inputs
      updateNumericInput(session, "budget_min", value = NA)
      updateNumericInput(session, "budget_max", value = NA)
      updateNumericInput(session, "risico_min", value = NA)
      updateNumericInput(session, "risico_max", value = NA)
      
      cli_alert_info("Filters reset")
      show_notification("Alle filters zijn gereset", type = "message")
    })
    
    # ========================================================================
    # EXPORT FILTERED DATA
    # ========================================================================
    
    output$export_filtered <- downloadHandler(
      filename = function() {
        paste0("gefilterde_zaken_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        data <- filtered_data()
        
        # Select and rename columns for export
        export_data <- data %>%
          select(
            "Zaak ID" = zaak_id,
            "Datum" = datum_aanmaak,
            "Zaakaanduiding" = zaakaanduiding,
            "Type Dienst" = type_dienst,
            "Rechtsgebied" = rechtsgebied,
            "Status" = status_zaak,
            "Aanvragende Directie" = directies,
            "Budget WJZ" = la_budget_wjz,
            "Budget Andere Directie" = budget_andere_directie,
            "Financieel Risico" = financieel_risico,
            "Advocaat" = advocaat,
            "Advocatenkantoor" = adv_kantoor
          )
        
        writexl::write_xlsx(export_data, file)
        
        cli_alert_success("Filtered data exported: {nrow(export_data)} rows")
        show_notification(paste("Data geëxporteerd:", nrow(export_data), "zaken"), type = "message")
      }
    )
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    # Return filtered data for other modules to use
    return(list(
      filtered_data = filtered_data,
      filter_count = reactive({ nrow(filtered_data()) }),
      has_active_filters = reactive({ any(unlist(active_filters())) }),
      reset_filters = function() { 
        updateActionButton(session, "reset_filters")
      }
    ))
  })
}