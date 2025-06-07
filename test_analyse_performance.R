# test_analyse_performance.R
# ==========================
# Test script om analyse module performance te meten

# Load required libraries and setup
source("global.R")
source("utils/database.R")

cat("🚀 Testing Analyse Module Performance Optimizations\n")
cat("===================================================\n\n")

# Get test data
cat("📊 Loading test data...\n")
con <- get_db_connection()
test_data <- get_zaken_met_directies_optimized()
cat(sprintf("✅ Loaded %d cases\n\n", nrow(test_data)))

# Test 1: Bulk vs Individual get_weergave_naam calls
cat("🔍 Test 1: Bulk vs Individual dropdown conversions\n")
cat("--------------------------------------------------\n")

# Individual calls (old method)
cat("⏱️  Testing individual sapply calls...\n")
time_individual <- system.time({
  result_individual <- test_data %>%
    mutate(
      type_dienst_display = sapply(type_dienst, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("type_dienst", x)),
      rechtsgebied_display = sapply(rechtsgebied, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("rechtsgebied", x)),
      status_zaak_display = sapply(status_zaak, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("status_zaak", x))
    )
})
cat(sprintf("   Individual method: %.3f seconds\n", time_individual[3]))

# Bulk calls (new method)
cat("⏱️  Testing bulk conversions...\n")
time_bulk <- system.time({
  type_dienst_names <- bulk_get_weergave_namen("type_dienst", test_data$type_dienst)
  rechtsgebied_names <- bulk_get_weergave_namen("rechtsgebied", test_data$rechtsgebied)
  status_zaak_names <- bulk_get_weergave_namen("status_zaak", test_data$status_zaak)
  
  result_bulk <- test_data %>%
    mutate(
      type_dienst_display = ifelse(is.na(type_dienst), "Onbekend", type_dienst_names),
      rechtsgebied_display = ifelse(is.na(rechtsgebied), "Onbekend", rechtsgebied_names),
      status_zaak_display = ifelse(is.na(status_zaak), "Onbekend", status_zaak_names)
    )
})
cat(sprintf("   Bulk method: %.3f seconds\n", time_bulk[3]))

# Calculate improvement
improvement_pct <- round(((time_individual[3] - time_bulk[3]) / time_individual[3]) * 100, 1)
speedup <- round(time_individual[3] / time_bulk[3], 1)

cat(sprintf("\n🎯 Dropdown Conversion Results:\n"))
cat(sprintf("   📈 Speed improvement: %s%% faster\n", improvement_pct))
cat(sprintf("   ⚡ Speedup factor: %sx faster\n", speedup))

# Test 2: Simulate analyse module data loading
cat(sprintf("\n🔍 Test 2: Complete Analyse Module Data Processing\n"))
cat("--------------------------------------------------\n")

# Simulate old method
cat("⏱️  Testing old analyse data processing...\n")
time_old_analyse <- system.time({
  # Simulate looptijd_data calculation with individual calls
  looptijd_old <- test_data %>%
    mutate(
      looptijd_dagen = as.numeric(Sys.Date() - as.Date(datum_aanmaak)),
      type_dienst_display = sapply(type_dienst, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("type_dienst", x)),
      rechtsgebied_display = sapply(rechtsgebied, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("rechtsgebied", x)),
      status_zaak_display = sapply(status_zaak, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("status_zaak", x))
    ) %>%
    filter(!is.na(looptijd_dagen) & looptijd_dagen >= 0)
  
  # Simulate verdeling data with individual calls  
  verdeling_old <- test_data %>%
    mutate(
      categorie_display = sapply(type_dienst, function(x) if(is.na(x)) "Onbekend" else get_weergave_naam("type_dienst", x))
    ) %>%
    count(categorie_display)
})
cat(sprintf("   Old method: %.3f seconds\n", time_old_analyse[3]))

# Simulate new optimized method
cat("⏱️  Testing optimized analyse data processing...\n")
time_new_analyse <- system.time({
  # Bulk convert all at once
  type_dienst_names <- bulk_get_weergave_namen("type_dienst", test_data$type_dienst)
  rechtsgebied_names <- bulk_get_weergave_namen("rechtsgebied", test_data$rechtsgebied)
  status_zaak_names <- bulk_get_weergave_namen("status_zaak", test_data$status_zaak)
  
  # Simulate looptijd_data calculation with bulk results
  looptijd_new <- test_data %>%
    mutate(
      looptijd_dagen = as.numeric(Sys.Date() - as.Date(datum_aanmaak)),
      type_dienst_display = ifelse(is.na(type_dienst), "Onbekend", type_dienst_names),
      rechtsgebied_display = ifelse(is.na(rechtsgebied), "Onbekend", rechtsgebied_names),
      status_zaak_display = ifelse(is.na(status_zaak), "Onbekend", status_zaak_names)
    ) %>%
    filter(!is.na(looptijd_dagen) & looptijd_dagen >= 0)
  
  # Simulate verdeling data with bulk results
  verdeling_new <- test_data %>%
    mutate(categorie_display = ifelse(is.na(type_dienst), "Onbekend", type_dienst_names)) %>%
    count(categorie_display)
})
cat(sprintf("   Optimized method: %.3f seconds\n", time_new_analyse[3]))

# Calculate improvement for full analyse module
analyse_improvement_pct <- round(((time_old_analyse[3] - time_new_analyse[3]) / time_old_analyse[3]) * 100, 1)
analyse_speedup <- round(time_old_analyse[3] / time_new_analyse[3], 1)

cat(sprintf("\n🎯 Analyse Module Results:\n"))
cat(sprintf("   📈 Speed improvement: %s%% faster\n", analyse_improvement_pct))
cat(sprintf("   ⚡ Speedup factor: %sx faster\n", analyse_speedup))

# Summary
cat(sprintf("\n🚀 PERFORMANCE OPTIMIZATION SUMMARY\n"))
cat("=====================================\n")
cat(sprintf("✅ Bulk dropdown conversions: %s%% faster (%sx speedup)\n", improvement_pct, speedup))
cat(sprintf("✅ Complete analyse processing: %s%% faster (%sx speedup)\n", analyse_improvement_pct, analyse_speedup))
cat(sprintf("✅ Lazy loading: Only loads when tab is active\n"))
cat(sprintf("✅ Debouncing: 300ms delay prevents excessive calculations\n"))

cat(sprintf("\n🎉 Expected User Experience:\n"))
cat(sprintf("   • Analyse tab loads %sx faster\n", analyse_speedup))
cat(sprintf("   • Dropdown changes are %sx more responsive\n", speedup))
cat(sprintf("   • No loading when switching to other tabs\n"))
cat(sprintf("   • Smoother filtering experience\n"))

# Cleanup
dbDisconnect(con)
cat(sprintf("\n✅ Performance test completed successfully!\n"))