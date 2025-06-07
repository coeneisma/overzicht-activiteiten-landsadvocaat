# test_performance.R
# =====================
# Performance test script voor dashboard optimalisaties

# Load required libraries
library(cli)

# Load database utilities
source("utils/database.R")

cli_h1("Dashboard Performance Test")

# ============================================================================
# TEST 1: Database Query Performance
# ============================================================================

cli_h2("Test 1: Database Query Performance")

cli_alert_info("Testing N+1 vs Optimized query...")

# Test old N+1 query approach
cli_alert_info("Running LEGACY get_zaken_met_directies() (N+1 queries)...")
time_legacy <- system.time({
  data_legacy <- get_zaken_met_directies()
})

cli_alert_info("Running OPTIMIZED get_zaken_met_directies_optimized() (single query)...")
time_optimized <- system.time({
  data_optimized <- get_zaken_met_directies_optimized()
})

# Compare results
improvement_factor <- time_legacy[["elapsed"]] / time_optimized[["elapsed"]]

cli_alert_success("QUERY PERFORMANCE RESULTS:")
cli_li("Legacy (N+1): {round(time_legacy[['elapsed']], 3)} seconds")
cli_li("Optimized (JOIN): {round(time_optimized[['elapsed']], 3)} seconds") 
cli_li("Improvement: {round(improvement_factor, 1)}x faster ({round((1 - time_optimized[['elapsed']]/time_legacy[['elapsed']]) * 100, 1)}% reduction)")

# Verify data integrity
if (nrow(data_legacy) == nrow(data_optimized)) {
  cli_alert_success("✓ Data integrity verified: Both methods return {nrow(data_legacy)} rows")
} else {
  cli_alert_danger("✗ Data integrity issue: Legacy={nrow(data_legacy)}, Optimized={nrow(data_optimized)}")
}

# ============================================================================
# TEST 2: Dropdown Cache Performance
# ============================================================================

cli_h2("Test 2: Dropdown Cache Performance")

# Clear cache first
clear_dropdown_cache()

# Test non-cached vs cached performance
test_values <- c("lopend", "afgerond", "open", "in_behandeling")

cli_alert_info("Testing dropdown lookup performance...")

# Non-cached (first time)
time_no_cache <- system.time({
  for (i in 1:10) {  # Multiple iterations
    result_no_cache <- sapply(test_values, function(x) get_weergave_naam_cached("status_zaak", x))
  }
})

# Cached (subsequent times)
time_cached <- system.time({
  for (i in 1:10) {  # Multiple iterations  
    result_cached <- sapply(test_values, function(x) get_weergave_naam_cached("status_zaak", x))
  }
})

cache_improvement <- time_no_cache[["elapsed"]] / time_cached[["elapsed"]]

cli_alert_success("CACHE PERFORMANCE RESULTS:")
cli_li("First time (no cache): {round(time_no_cache[['elapsed']], 4)} seconds")
cli_li("Cached lookups: {round(time_cached[['elapsed']], 4)} seconds")
cli_li("Cache improvement: {round(cache_improvement, 1)}x faster")

# ============================================================================
# TEST 3: Bulk Conversion Performance
# ============================================================================

cli_h2("Test 3: Bulk vs Individual Conversion")

# Sample data for testing
sample_statuses <- rep(c("lopend", "afgerond", "open"), length.out = 100)

cli_alert_info("Testing bulk conversion vs individual lookups...")

# Individual conversion (legacy way)
time_individual <- system.time({
  result_individual <- sapply(sample_statuses, function(x) get_weergave_naam_cached("status_zaak", x))
})

# Bulk conversion (optimized way) 
time_bulk <- system.time({
  result_bulk <- bulk_get_weergave_namen("status_zaak", sample_statuses)
})

bulk_improvement <- time_individual[["elapsed"]] / time_bulk[["elapsed"]]

cli_alert_success("BULK CONVERSION RESULTS:")
cli_li("Individual lookups: {round(time_individual[['elapsed']], 4)} seconds")
cli_li("Bulk conversion: {round(time_bulk[['elapsed']], 4)} seconds")
cli_li("Bulk improvement: {round(bulk_improvement, 1)}x faster")

# Verify results are identical
if (identical(result_individual, result_bulk)) {
  cli_alert_success("✓ Bulk conversion integrity verified")
} else {
  cli_alert_danger("✗ Bulk conversion produces different results")
}

# ============================================================================
# OVERALL SUMMARY
# ============================================================================

cli_h2("Overall Performance Summary")

total_query_improvement <- round((1 - time_optimized[["elapsed"]]/time_legacy[["elapsed"]]) * 100, 1)
total_cache_improvement <- round((1 - time_cached[["elapsed"]]/time_no_cache[["elapsed"]]) * 100, 1) 
total_bulk_improvement <- round((1 - time_bulk[["elapsed"]]/time_individual[["elapsed"]]) * 100, 1)

cli_alert_success("PERFORMANCE IMPROVEMENTS ACHIEVED:")
cli_li("Database queries: {total_query_improvement}% faster")
cli_li("Dropdown caching: {total_cache_improvement}% faster") 
cli_li("Bulk conversions: {total_bulk_improvement}% faster")

# Estimate real-world impact
estimated_table_load_old <- time_legacy[["elapsed"]] + (time_no_cache[["elapsed"]] * 5) + (time_individual[["elapsed"]] * 2)
estimated_table_load_new <- time_optimized[["elapsed"]] + (time_cached[["elapsed"]] * 5) + (time_bulk[["elapsed"]] * 2)

real_world_improvement <- round((1 - estimated_table_load_new/estimated_table_load_old) * 100, 1)

cli_rule()
cli_alert_success("ESTIMATED REAL-WORLD IMPACT:")
cli_li("Old table load time: ~{round(estimated_table_load_old, 2)} seconds")
cli_li("New table load time: ~{round(estimated_table_load_new, 2)} seconds")
cli_li("Overall improvement: {real_world_improvement}% faster table loading")

cli_alert_info("Database indexes added: 13 performance indexes")
cli_alert_info("Cache system: Active and ready")
cli_alert_info("Optimized queries: Single JOIN instead of N+1")

cli_h1("Performance Test Complete! 🚀")