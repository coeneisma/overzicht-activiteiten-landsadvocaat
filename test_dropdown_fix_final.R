# Definitieve SelectInput Dropdown Test
# =====================================
# Test verschillende contexts om root cause te vinden

library(shiny)
library(bslib)

ui <- page_sidebar(
  title = "SelectInput Context Test",
  
  sidebar = sidebar(
    width = 350,
    
    # TEST 1: Direct in sidebar (geen accordion)
    h4("🔬 Test 1: Direct in Sidebar"),
    div(
      class = "border p-2 mb-3",
      selectInput("direct1", "Direct 1:", choices = letters[1:5], multiple = TRUE),
      selectInput("direct2", "Direct 2:", choices = letters[6:10], multiple = TRUE),
      selectInput("direct3", "Direct 3:", choices = letters[11:15], multiple = TRUE)
    ),
    
    # TEST 2: In accordion (zoals filters module)
    h4("🎯 Test 2: In Accordion (Probleem Context)"),
    accordion(
      id = "test_acc",
      accordion_panel(
        title = "Accordion Test Panel",
        selectInput("acc1", "Accordion 1:", choices = letters[1:5], multiple = TRUE),
        selectInput("acc2", "Accordion 2:", choices = letters[6:10], multiple = TRUE), 
        selectInput("acc3", "Accordion 3:", choices = letters[11:15], multiple = TRUE)
      )
    ),
    
    # TEST 3: In card (zoals andere modules)
    h4("📋 Test 3: In Card"),
    card(
      card_body(
        selectInput("card1", "Card 1:", choices = letters[1:5], multiple = TRUE),
        selectInput("card2", "Card 2:", choices = letters[6:10], multiple = TRUE),
        selectInput("card3", "Card 3:", choices = letters[11:15], multiple = TRUE)
      )
    )
  ),
  
  # FINAL CSS SOLUTION ATTEMPT
  tags$style(HTML("
    /* =================================================================== */
    /* FINAL SELECTINPUT LAYERING SOLUTION                                */
    /* =================================================================== */
    
    /* Hypothesis: Problem is in accordion body overflow/stacking context */
    
    /* SOLUTION 1: Complete overflow reset on all containers */
    .sidebar,
    .sidebar *,
    .bslib-sidebar, 
    .bslib-sidebar *,
    .accordion,
    .accordion-item,
    .accordion-header,
    .accordion-body,
    .card,
    .card-body {
      overflow: visible !important;
    }
    
    /* SOLUTION 2: Reset all auto z-indexes that might interfere */
    .accordion-item,
    .accordion-body,
    .card,
    .card-body {
      z-index: auto !important;
      position: relative !important;
      isolation: auto !important;
      contain: none !important;
    }
    
    /* SOLUTION 3: Give each container level a base z-index */
    .sidebar .shiny-input-container {
      position: relative !important;
      overflow: visible !important;
    }
    
    /* SOLUTION 4: Progressively higher z-index for higher elements */
    .sidebar div:nth-child(1) .shiny-input-container { z-index: 100 !important; }
    .sidebar div:nth-child(2) .shiny-input-container { z-index: 99 !important; }
    .sidebar div:nth-child(3) .shiny-input-container { z-index: 98 !important; }
    .sidebar div:nth-child(4) .shiny-input-container { z-index: 97 !important; }
    .sidebar div:nth-child(5) .shiny-input-container { z-index: 96 !important; }
    
    /* Same for accordion content */
    .accordion-body div:nth-child(1) .shiny-input-container { z-index: 200 !important; }
    .accordion-body div:nth-child(2) .shiny-input-container { z-index: 199 !important; }
    .accordion-body div:nth-child(3) .shiny-input-container { z-index: 198 !important; }
    .accordion-body div:nth-child(4) .shiny-input-container { z-index: 197 !important; }
    .accordion-body div:nth-child(5) .shiny-input-container { z-index: 196 !important; }
    
    /* SOLUTION 5: Select elements inherit container z-index */
    .sidebar .form-select[multiple] {
      position: relative !important;
      z-index: inherit !important;
    }
    
    /* DEBUGGING: Visual indicators */
    .form-select { border: 2px solid red !important; }
    .shiny-input-container { margin: 5px 0 !important; }
    
    /* TEST: Force 3D acceleration to create new stacking context */
    .sidebar .shiny-input-container {
      transform: translateZ(0) !important;
      backface-visibility: hidden !important;
    }
  ")),
  
  # Main content  
  div(
    class = "p-4",
    h2("🧪 SelectInput Layering Diagnostics"),
    
    div(
      class = "alert alert-info",
      h4("Test Protocol:"),
      tags$ol(
        tags$li(strong("Test 1 (Direct):"), " Open first dropdown. Does it appear in front of second?"),
        tags$li(strong("Test 2 (Accordion):"), " Open accordion, then test first dropdown vs second."),
        tags$li(strong("Test 3 (Card):"), " Same test in card context."),
        tags$li(strong("Compare:"), " Which context shows the problem?")
      )
    ),
    
    div(
      class = "alert alert-warning", 
      h4("Expected Behavior:"),
      p("✅ Higher dropdown (first in DOM) should ALWAYS appear in front of lower ones."),
      p("❌ If lower dropdowns hide the higher ones, CSS z-index fix is needed.")
    ),
    
    h4("📊 Debug Values:"),
    verbatimTextOutput("all_values")
  )
)

server <- function(input, output, session) {
  output$all_values <- renderText({
    paste(
      "DIRECT:", paste(input$direct1, collapse=","), "|", paste(input$direct2, collapse=","), "|", paste(input$direct3, collapse=","),
      "\nACCORDION:", paste(input$acc1, collapse=","), "|", paste(input$acc2, collapse=","), "|", paste(input$acc3, collapse=","),
      "\nCARD:", paste(input$card1, collapse=","), "|", paste(input$card2, collapse=","), "|", paste(input$card3, collapse=",")
    )
  })
}

if (interactive()) {
  shinyApp(ui = ui, server = server)
}