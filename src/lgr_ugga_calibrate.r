lgr_ugga_calibrate <- function() {

  # Exit if currently sampling reference gases
  if (!site_info[[site]]$reprocess && tail(nd$ID_CO2, 1) != -10) {
    stop('Calibrations disabled. Sampling reference tank at: ', site)
  }

  # Import recent data to ensure bracketing reference measurements
  if (!site_info[[site]]$reprocess) {
    N <- 1 + (as.numeric(format(nd$Time_UTC[1], tz = 'UTC', '%d')) == 1)
    files <- tail(dir(file.path('data', site, instrument, 'qaqc'),
                      pattern = '.*\\.{1}dat', full.names = T), N)
    nd <- read_files(files)
  }

  # Invalidate measured mole fraction for records that fail to pass qaqc
  invalid <- c('CO2d_ppm', 'CH4d_ppm')
  nd[nd$QAQC_Flag %in% 2:4, invalid] <- NA

  # cal_co2 <- with(nd, calibrate_linear(Time_UTC, CO2d_ppm, ID_CO2))
  # cal_ch4 <- with(nd, calibrate_linear(Time_UTC, CH4d_ppm, ID_CH4))
  cal_co2 <- nd %>%
    group_by(yyyy = format(Time_UTC, '%Y', tz = 'UTC')) %>%
    do(with(., calibrate_linear(Time_UTC, CO2d_ppm, ID_CO2))) %>%
    ungroup() %>%
    select(-yyyy)
  cal_ch4 <- nd %>%
    group_by(yyyy = format(Time_UTC, '%Y', tz = 'UTC')) %>%
    do(with(., calibrate_linear(Time_UTC, CH4d_ppm, ID_CH4))) %>%
    ungroup() %>%
    select(-yyyy)
  cal <- bind_cols(
    cal_co2 %>% select(time, cal, meas, m, b, n, rsq, rmse, id),
    cal_ch4 %>% select(cal, meas, m, b, n, rsq, rmse, id)
  )
  colnames(cal) <- data_info[[instrument]]$calibrated$col_names[1:ncol(cal)]

  # Set QAQC flag giving priority to initial QAQC then calibration QAQC
  cal$QAQC_Flag <- nd$QAQC_Flag
  cal$QAQC_Flag[cal$QAQC_Flag == 0] <- cal_co2$qaqc[cal$QAQC_Flag == 0]
  cal$QAQC_Flag[cal$QAQC_Flag == 0] <- cal_ch4$qaqc[cal$QAQC_Flag == 0]

  if (nrow(cal) != nrow(nd))
    stop('Calibration script returned wrong number of records at: ', site)

  last_cal <- with(cal, tail(which((ID_CO2 == -10 & CO2d_n > 0) |
                                     (ID_CH4 == -10 & CH4d_n > 0)), 1))
  cal[1:last_cal, ]
}
