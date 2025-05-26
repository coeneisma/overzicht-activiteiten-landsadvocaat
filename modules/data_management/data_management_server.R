# modules/data_management/data_management_server.R
# ==================================================
# MINIMAL VERSION - Step 1: Basic Data Table Only

#' Data Management Module Server - Minimal
#' 
#' Handles basic data display and statistics
#' 
#' @param id Module namespace ID
#' @param filtered_data Reactive containing filtered case data
#' @param raw_data Reactive containing all case data
#' @param data_refresh_trigger Reactive value to trigger data refresh
#' @param current_user Reactive containing current username
#' @return List with reactive values and functions
data_management_server <- function(id, filtered_data, raw_data, data_refresh_trigger, current_user) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # SUMMARY STATISTICS
    # ========================================================================
    
    # Total cases (all data)
    output$stat_total <- renderText({
      data <- raw_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      total <- nrow(data)
      format(total, big.mark = ".")
    })
    
    # Filtered cases
    output$stat_filtered <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      filtered <- nrow(data)
      format(filtered, big.mark = ".")
    })
    
    # Open cases (from filtered data)
    output$stat_open <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      open_count <- sum(data$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE)
      format(open_count, big.mark = ".")
    })
    
    # Recent cases (this month, from filtered data)
    output$stat_recent <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      current_month <- format(Sys.Date(), "%Y-%m")
      recent_count <- sum(format(data$datum_aanmaak, "%Y-%m") == current_month, na.rm = TRUE)
      format(recent_count, big.mark = ".")
    })
    
    # Last updated timestamp
    output$last_updated <- renderText({
      # Trigger on data refresh
      data_refresh_trigger()
      format(Sys.time(), "%H:%M:%S")
    })
    
    # ========================================================================
    # BASIC DATA TABLE
    # ========================================================================
    
    output$zaken_table <- DT::renderDataTable({
      
      data <- filtered_data()
      
      # Show message if no data
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen zaken gevonden. Pas filters aan of voeg nieuwe zaken toe."),
          options = list(
            searching = FALSE, 
            paging = FALSE, 
            info = FALSE,
            ordering = FALSE
          ),
          rownames = FALSE
        ))
      }
      
      # Prepare display data (basic columns only)
      display_data <- data %>%
        select(
          "Zaak ID" = zaak_id,
          "Datum" = datum_aanmaak,
          "Omschrijving" = omschrijving,
          "Type Dienst" = type_dienst,
          "Rechtsgebied" = rechtsgebied,
          "Status" = status_zaak,
          "Directie" = aanvragende_directie,
          "Advocaat" = advocaat
        ) %>%
        mutate(
          Datum = format_date_nl(Datum),
          # Truncate long descriptions
          Omschrijving = ifelse(
            nchar(Omschrijving) > 60, 
            paste0(substr(Omschrijving, 1, 57), "..."), 
            Omschrijving
          )
        )
      
      # Create simple DataTable
      DT::datatable(
        display_data,
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          scrollX = TRUE,
          autoWidth = FALSE,
          dom = 'frtip',  # Simple layout: filter, table, info, pagination
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ items",
            infoEmpty = "Geen items beschikbaar",
            infoFiltered = "(gefilterd van _MAX_ totaal items)",
            paginate = list(
              first = "Eerste",
              last = "Laatste",
              `next` = "Volgende",
              previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE
      ) %>%
        # Simple status color coding
        DT::formatStyle(
          "Status",
          backgroundColor = DT::styleEqual(
            c("Open", "In_behandeling", "Afgerond", "On_hold"),
            c("#fff3cd", "#d1ecf1", "#d4edda", "#f8d7da")
          )
        )
      
    }, server = TRUE)
    
    # ========================================================================
    # SIMPLE BUTTON ACTIONS
    # ========================================================================
    
    # Refresh button
    observeEvent(input$btn_refresh, {
      cli_alert_info("Manual data refresh requested by user: {current_user()}")
      data_refresh_trigger(data_refresh_trigger() + 1)
      show_notification("Data ververst", type = "message")
    })
    
    # Nieuwe zaak button (placeholder for now)
    observeEvent(input$btn_nieuwe_zaak, {
      cli_alert_info("New case button clicked by user: {current_user()}")
      show_notification("Nieuwe zaak functie wordt in de volgende stap toegevoegd", type = "message")
    })
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    return(list(
      # Statistics
      get_stats = reactive({
        list(
          total = nrow(raw_data()),
          filtered = nrow(filtered_data()),
          open = sum(filtered_data()$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE),
          recent = sum(format(filtered_data()$datum_aanmaak, "%Y-%m") == format(Sys.Date(), "%Y-%m"), na.rm = TRUE)
        )
      }),
      
      # Data refresh function
      refresh_data = function() {
        data_refresh_trigger(data_refresh_trigger() + 1)
      }
    ))
  })
}