# debug_picker_update.R
# =====================
# Debug waarom testwaarde niet verschijnt in pickerInput

source("global.R")

cat("🔍 Debugging pickerInput Update Issues\n")
cat("======================================\n\n")

# Test 1: Check what get_dropdown_opties returns
cat("📋 Step 1: Testing get_dropdown_opties('status_zaak')\n")
cat("----------------------------------------------------\n")
choices <- get_dropdown_opties("status_zaak")
cat(sprintf("Found %d choices:\n", length(choices)))
for (i in 1:length(choices)) {
  cat(sprintf("  %d. Value: '%s' => Label: '%s'\n", i, choices[i], names(choices)[i]))
}

# Test 2: Check database volgorde vs alfabetische sortering
cat("\n📊 Step 2: Database volgorde vs get_dropdown_opties output\n")
cat("--------------------------------------------------------\n")

con <- get_db_connection()
db_data <- dbGetQuery(con, "
  SELECT waarde, weergave_naam, volgorde, actief
  FROM dropdown_opties 
  WHERE categorie = 'status_zaak' AND actief = 1
  ORDER BY volgorde
")
dbDisconnect(con)

cat("Database order (by volgorde):\n")
for (i in 1:nrow(db_data)) {
  cat(sprintf("  %d. '%s' => '%s' (volgorde: %d)\n", 
              i, db_data$waarde[i], db_data$weergave_naam[i], db_data$volgorde[i]))
}

cat("\nget_dropdown_opties order (alfabetisch):\n")
for (i in 1:length(choices)) {
  cat(sprintf("  %d. '%s' => '%s'\n", i, choices[i], names(choices)[i]))
}

# Test 3: Check if the issue is with updatePickerInput format
cat("\n🔧 Step 3: Testing pickerInput format\n")
cat("------------------------------------\n")
cat("Named vector format (current):\n")
str(choices)

cat("\nList format (alternative for pickerInput):\n")
choices_list <- list(
  text = names(choices),
  value = as.character(choices)
)
str(choices_list)

cat("\n💡 Potential Issues:\n")
cat("-------------------\n")
cat("1. pickerInput might not handle named vectors correctly\n")
cat("2. updatePickerInput might need different format than updateSelectInput\n")
cat("3. Alfabetische sortering overschrijft database volgorde\n")
cat("4. testwaarde staat op volgorde=0, dus zou eerste moeten zijn\n")

cat("\n🧪 Recommendations:\n")
cat("------------------\n")
cat("• Try passing choices in different format to updatePickerInput\n")
cat("• Check if volgorde-based sorting works better\n")
cat("• Test with simple vector: c('value1', 'value2')\n")

cat("\n✅ Debug analysis completed!\n")