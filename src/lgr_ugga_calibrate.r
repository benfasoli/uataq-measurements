lgr_ugga_calibrate <- function() {

  if (!site_config$reprocess && !grepl('trx', site)) {
    # Exit if currently sampling reference gases
    if (tail(nd$ID_CO2, 1) != -10) 
      stop('Calibrations disabled. Sampling reference tank at: ', site)
    
    # Import recent data to ensure bracketing reference measurements
    N <- 1 + (as.numeric(format(nd$Time_UTC[1], tz = 'UTC', '%d')) == 1)
    files <- tail(dir(file.path('data', site, instrument, 'qaqc'),
                      pattern = '.*\\.{1}dat', full.names = T), N)
    nd <- read_files(files)
  }

  # Invalidate measured mole fraction for records that fail to pass qaqc,
  #   excluding cal tank references (QAQC_Flag == -9)
  invalid <- c('CO2d_ppm', 'CH4d_ppm')
  nd[with(nd, QAQC_Flag < 0 & QAQC_Flag != -9), invalid] <- NA

  grouped <- nd %>%
    group_by(yyyy = format(Time_UTC, '%Y', tz = 'UTC'))

  cal_co2 <- grouped %>%
    do(with(., calibrate_linear(Time_UTC, CO2d_ppm, ID_CO2))) %>%
    ungroup() %>%
    select(-yyyy)
  cal_ch4 <- grouped %>%
    do(with(., calibrate_linear(Time_UTC, CH4d_ppm, ID_CH4))) %>%
    ungroup() %>%
    select(-yyyy)
  cal <- bind_cols(
    cal_co2 %>% select(time, cal, meas, m, b, n, rsq, rmse, id),
    cal_ch4 %>% select(cal, meas, m, b, n, rsq, rmse, id)
  )
  colnames(cal) <- data_config[[instrument]]$calibrated$col_names[1:ncol(cal)]

  # Set QAQC flag giving priority to calibration QAQC then initial QAQC
  cal$QAQC_Flag <- cal_co2$qaqc
  mask <- cal$QAQC_Flag == 0 | is.na(cal$QAQC_Flag)
  cal$QAQC_Flag[mask] <- cal_ch4$qaqc[mask]
  mask <- cal$QAQC_Flag == 0 | is.na(cal$QAQC_Flag)
  cal$QAQC_Flag[mask] <- nd$QAQC_Flag[mask]

  if (nrow(cal) != nrow(nd))
    stop('Calibration script returned wrong number of records at: ', site)

  last_cal <- with(cal, tail(which((ID_CO2 == -10 & CO2d_n > 0) |
                                     (ID_CH4 == -10 & CH4d_n > 0)), 1))
  if (length(last_cal) == 0) return(cal)
  cal[1:last_cal, ]
}
