# Test voor SelectInput Dropdown Layering Fix
# =============================================
# Focus op accordion panels waar het probleem echt optreedt

library(shiny)
library(bslib)

# Test UI om dropdown layering probleem exact te reproduceren
ui <- page_sidebar(
  title = "SelectInput Dropdown Layering Test",
  
  sidebar = sidebar(
    width = 300,
    
    # EXACT REPLICA van filters module structure
    accordion(
      id = "test_accordion",
      open = FALSE,
      
      # Test Panel - net als Classificatie panel in filters
      accordion_panel(
        title = div(icon("tags"), " Test Classificatie"),
        value = "test_classificatie",
        
        # PROBLEEM: Deze drie dropdowns boven elkaar
        div(
          class = "mb-3",
          selectInput(
            "test_type_dienst",
            "Type Dienst:",
            choices = c("Juridisch Advies" = "advies", 
                       "Procesbegeleiding" = "proces",
                       "Contractbeoordeling" = "contract"),
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        div(
          class = "mb-3", 
          selectInput(
            "test_rechtsgebied",
            "Rechtsgebied:",
            choices = c("Bestuursrecht" = "bestuur",
                       "Civiel recht" = "civiel", 
                       "Arbeidsrecht" = "arbeid"),
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        div(
          class = "mb-3",
          selectInput(
            "test_status",
            "Status:",
            choices = c("Lopend" = "lopend",
                       "Afgerond" = "afgerond",
                       "On hold" = "on_hold"),
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        )
      )
    )
  ),
  
  # DEBUGGING CSS - om het probleem te isoleren
  tags$style(HTML("
    /* DEBUG: Maak accordion panels zichtbaar */
    .accordion-item {
      border: 2px solid blue !important;
    }
    
    .accordion-body {
      border: 1px dashed green !important;
    }
    
    /* DEBUG: Maak selectInput containers zichtbaar */
    .shiny-input-container {
      border: 1px solid orange !important;
      margin: 2px !important;
    }
    
    /* DEBUG: Maak form-select zichtbaar */
    .form-select {
      border: 2px solid red !important;
    }
    
    /* MOGELIJK PROBLEEM: accordion overflow restricties */
    .accordion, .accordion-item, .accordion-body {
      overflow: visible !important;
    }
    
    /* MOGELIJKE OPLOSSING 1: Force accordion z-index management */
    .accordion-item {
      position: relative !important;
      z-index: auto !important;
    }
    
    .accordion-body {
      position: relative !important;
      z-index: auto !important;
      overflow: visible !important;
    }
    
    /* MOGELIJKE OPLOSSING 2: selectInput specifieke fixes */
    .accordion-body .shiny-input-container {
      position: relative !important;
      z-index: 1000 !important;
      overflow: visible !important;
    }
    
    .accordion-body .form-select {
      position: relative !important;
      z-index: 10000 !important;
    }
    
    /* MOGELIJKE OPLOSSING 3: Stacked input containers krijgen incrementele z-index */
    .accordion-body .shiny-input-container:nth-child(1) { z-index: 3000 !important; }
    .accordion-body .shiny-input-container:nth-child(2) { z-index: 2000 !important; }
    .accordion-body .shiny-input-container:nth-child(3) { z-index: 1000 !important; }
    
    /* MOGELIJKE OPLOSSING 4: Force dropdown options to break out */
    .form-select[multiple] option {
      z-index: 99999 !important;
    }
  ")),
  
  # Main content
  div(
    class = "p-4",
    h3("🔍 Dropdown Layering Debug Test"),
    
    div(
      class = "alert alert-info",
      h5("Test Instructies:"),
      tags$ol(
        tags$li("Open het 'Test Classificatie' accordion panel"),
        tags$li("Klik op de eerste dropdown (Type Dienst)"),
        tags$li("Check of dropdown opties VOOR de tweede dropdown (Rechtsgebied) verschijnen"),
        tags$li("Als ze erachter verdwijnen, dan is het probleem bevestigd"),
        tags$li("Test alle drie dropdowns")
      )
    ),
    
    div(
      class = "alert alert-warning",
      h5("🎯 Root Cause Hypotheses:"),
      tags$ul(
        tags$li("Accordion body heeft overflow: hidden"),
        tags$li("Bootstrap accordion z-index stacking context"),
        tags$li("Shiny input containers hebben verkeerde positioning"),
        tags$li("Form-select elements hebben geen escalating z-index")
      )
    ),
    
    h4("📊 Current Values:"),
    verbatimTextOutput("debug_values")
  )
)

server <- function(input, output, session) {
  output$debug_values <- renderText({
    paste(
      "Type Dienst:", if(is.null(input$test_type_dienst)) "NULL" else paste(input$test_type_dienst, collapse = ", "),
      "\nRechtsgebied:", if(is.null(input$test_rechtsgebied)) "NULL" else paste(input$test_rechtsgebied, collapse = ", "),
      "\nStatus:", if(is.null(input$test_status)) "NULL" else paste(input$test_status, collapse = ", ")
    )
  })
}

# Run test app
if (interactive()) {
  shinyApp(ui = ui, server = server)
}