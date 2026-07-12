library(dataRetrieval)
library(dplyr)
library(data.table)
library(readr)

DT <- function(x, ...) {
  data.table:::`[.data.table`(x, ...)[]
}


##------------------------------------------------------------------------------
## (0) Helper function
##------------------------------------------------------------------------------

## Water temperature (degrees C) has been measured (with gaps) since 1986-10-17.
## Mean daily dischage (feet^3/sec) has been measure every day since 1986-10-17.
USGS_gage_daily_parameters <-
    function(gage_ID, dates = c("1986-10-17", "2050-01-01"))
{
    ## Parameter & statistic codes at, respectively:
    ## (https://api.waterdata.usgs.gov/ogcapi/v0/collections/parameter-codes/items)
    ## (https://api.waterdata.usgs.gov/ogcapi/v0/collections/statistic-codes/items)
    water_temp_C <- "00010"  ## Daily temperature, degrees C
    discharge_cfs <- "00060" ## Daily mean cubic feet/second
    statistic_id <- "00003"  ## MEAN
    tmp <- read_waterdata_daily(monitoring_location_id = gage_ID,
                                parameter_code = water_temp_C,
                                statistic_id = statistic_id,
                                time = dates,
                                skipGeometry = TRUE) %>%
        data.table()
    cfs <- read_waterdata_daily(monitoring_location_id = gage_ID,
                                parameter_code = discharge_cfs,
                                statistic_id = statistic_id,
                                time = dates,
                                skipGeometry = TRUE) %>%
        data.table()
    cfs <- cfs[, .(date = time, cfs = value)]
    tmp <- tmp[, .(date = time, tmp = value)] %>%
        setkey(date)
    x <- tmp[cfs, ]
    x[]
}


##------------------------------------------------------------------------------
## (1) Fetch daily data from Lees Ferry gage
##------------------------------------------------------------------------------

## Fetch Lees Ferry temperature & discharge data
site_LF   <- "USGS-09380000" ## Colorado River at Lees Ferry AZ
DAT <- USGS_gage_daily_parameters(site_LF)


##------------------------------------------------------------------------------
## (2) Load monthly energy variables and fitted model parameters
##------------------------------------------------------------------------------

##---------------------------##
## Monthly mean input values ##
##---------------------------##
## Air temperature (Ta, degrees C)
Ta <- c(2.61098310295238, 5.37994076942857, 10.1960167388571, 14.132380952381,
        19.9978627047619, 25.7710941042857, 28.900673322381, 27.1456989247619,
        22.7706716052381, 15.1597542233333, 7.69103174604762, 2.4701228877619)
## Solar radiation (GHI)
GHI <- c(127.18298573619, 160.422012495238, 226.649716447619, 276.963306295238,
         325.504432095238, 346.618821747619, 280.036774033333, 256.201574771429,
         239.347570666667, 194.563222390476, 144.42754072381, 115.010091321905)
##
## library(readxl)
## vals <-
##     "../Models/Dibble_etal_2020/Dibble_model_inputs.xlsx" %>%
##     read_xlsx(sheet = "Monthly_inputs", range = "B1:N5") %>%
##     data.table() %>%
##     melt(id.vars = "variable", variable.name = "month")
## ## Air temperature (Ta, degrees C)
## Ta <- vals[variable == "T_a", value]
## ## Solar radiation (GHI)
## GHI <- vals[variable == "GHI", value]


##-------------------------##
## Fitted parameter values ##
##-------------------------##
beta0 <- 19.53
betaA <-  7.01
betaS <-  1.66
b     <-  0.63
k     <-  0.08


##------------------------------------------------------------------------------
## (3) Compute temp at river mile 10 from observations at Lees Ferry (RM0)
## ------------------------------------------------------------------------------

f <- function(date = "2024-01-10",
              T0_LF = 9.51318234,
              Q = 14177.9107)
{
    ## Extract input values for current month
    month <- month(as.Date(date))
    Ta <- Ta[month]
    GHI <- GHI[month]

    ## Convert ft^3/s to m^3/s, following pattern in spreadsheet model formulae
    Q <- Q/(3.281^3)

    ## Center and scale, using values in spreadsheet model formulae
    Ta <- (Ta - 15.20539) / 10
    GHI <- (GHI - 225.339848) / 100

    ## T_e from Equation S3 (page 14)
    Te <- beta0 + (betaA * Ta) + (betaS * GHI)

    ## Term multiplying RM in exponential decay portion of the formula.
    ##
    ## NOTE: this equation (with "-b" rather than "b" in the exponent) is
    ## correct, not the equation recorded on p. 3 of Dibble 2020's Appendix S2.
    e_mult <- -(k*(Q^-b))

    ## Use formula "in reverse" to compute Glen Canyon outlet water temp from
    ## measured temperature at Lees Ferry, 15 miles downstream.
    RM <- 15
    T0 <- ((T0_LF - Te)/(exp(e_mult * RM))) + Te

    ## Use formula in "forward" direction to compute temp RM miles downstream
    RM <- 25
    Te + (T0 - Te)*(exp(e_mult * RM)) |>
        round(4)
}

## Apply function to each observation
DAT[, tmp := f(date, tmp, cfs)]

## Write results to stdout (as required for an Observable Framework data loader)
cat(format_csv(DAT, na = ""))

## Manually write to file, solely for testing purposes
## fwrite(DAT, "RM10_water_temp.6377a3bf.csv", na = "")
