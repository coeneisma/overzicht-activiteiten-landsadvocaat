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
        reden_inzet = !is.null(input$reden_inzet) && length(input$reden_inzet) > 0
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
          
          # Update the selectInput with force refresh
          updateSelectInput(session, category, choices = c("Alle" = "", choices), selected = "")
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
            
            updateDateRangeInput(session, "datum_range", 
                                 start = min_date, 
                                 end = max_date)
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
      
      # Apply filters step by step
      filtered <- data
      
      # Text search in zaak_id and omschrijving
      if (!is.null(input$search_text) && !is.na(input$search_text) && nchar(input$search_text) > 0) {
        search_term <- tolower(input$search_text)
        filtered <- filtered %>%
          filter(
            grepl(search_term, tolower(ifelse(is.na(zaak_id), "", zaak_id)), fixed = TRUE) |
              grepl(search_term, tolower(ifelse(is.na(omschrijving), "", omschrijving)), fixed = TRUE)
          )
      }
      
      # Dropdown filters
      if (!is.null(input$type_dienst) && length(input$type_dienst) > 0) {
        filtered <- filtered %>% filter(type_dienst %in% input$type_dienst)
      }
      
      if (!is.null(input$rechtsgebied) && length(input$rechtsgebied) > 0) {
        filtered <- filtered %>% filter(rechtsgebied %in% input$rechtsgebied)
      }
      
      if (!is.null(input$type_procedure) && length(input$type_procedure) > 0) {
        filtered <- filtered %>% filter(type_procedure %in% input$type_procedure)
      }
      
      if (!is.null(input$status_zaak) && length(input$status_zaak) > 0) {
        filtered <- filtered %>% filter(status_zaak %in% input$status_zaak)
      }
      
      if (!is.null(input$hoedanigheid_partij) && length(input$hoedanigheid_partij) > 0) {
        filtered <- filtered %>% filter(hoedanigheid_partij %in% input$hoedanigheid_partij)
      }
      
      if (!is.null(input$type_wederpartij) && length(input$type_wederpartij) > 0) {
        filtered <- filtered %>% filter(type_wederpartij %in% input$type_wederpartij)
      }
      
      if (!is.null(input$reden_inzet) && length(input$reden_inzet) > 0) {
        filtered <- filtered %>% filter(reden_inzet %in% input$reden_inzet)
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
      
      # Organization filters
      if (!is.null(input$aanvragende_directie) && length(input$aanvragende_directie) > 0) {
        filtered <- filtered %>% filter(aanvragende_directie %in% input$aanvragende_directie)
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
    
    # Debug info (development)
    output$filter_debug <- renderText({
      active <- active_filters()
      active_names <- names(active)[unlist(active)]
      
      if (length(active_names) > 0) {
        paste("Actieve filters:", paste(active_names, collapse = ", "))
      } else {
        "Geen actieve filters"
      }
    })
    
    # ========================================================================
    # RESET FILTERS
    # ========================================================================
    
    observeEvent(input$reset_filters, {
      
      # Reset all inputs
      updateTextInput(session, "search_text", value = "")
      
      # Reset dropdown filters
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
        updateDateRangeInput(session, "datum_range", start = min_date, end = max_date)
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
            "Omschrijving" = omschrijving,
            "Type Dienst" = type_dienst,
            "Rechtsgebied" = rechtsgebied,
            "Status" = status_zaak,
            "Aanvragende Directie" = aanvragende_directie,
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