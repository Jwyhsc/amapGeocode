#' Get coordinate from location
#'
#' @param address Required.\cr
#' Structured address information. \cr
#' Rules: Country/Region, Province/State, City, County/District, Town, Country, Road, Number, Room, Building.
#' @param key Optional.\cr
#' Amap Key. \cr
#' Applied from 'AutoNavi' Map API official website\url{https://lbs.amap.com/dev/}
#' @param city Optional.\cr
#' Specify the City. \cr
#' Support: city in Chinese, full pinyin, citycode, adcode\url{https://lbs.amap.com/api/webservice/download}.\cr
#' The default value is NULL which will search country-wide. The default value is NULL
#' @param sig Optional.\cr
#' Digital Signature.\cr
#' How to use this argument? Please check here{https://lbs.amap.com/faq/account/key/72}
#' @param output Optional.\cr
#'  Output Data Structure. \cr
#' Support JSON and XML. The default value is JSON.
#' @param callback Optional.\cr
#' Callback Function. \cr
#' The value of callback is the customized function. Only available with JSON output.
#' If you don't understand, it means you don't need it, just like me.
#' @param to_table Optional.\cr
#' Transform response content to data.table.
#' @param keep_bad_request Optional.\cr
#' Keep Bad Request to avoid breaking a workflow, especially meaningful in a batch request
#' @param max_core Optional.\cr
#' A threshold of max cores for parallel operation. There is no need to set a `max_core` generally.
#' But for some extreme high performance case, like `AMD Threadripper` and `Intel Xeon`,
#' super multiple-core CPU will meet the limitation of queries per second.
#'
#' @return
#' Returns a JSON, XML or data.table of results containing detailed geocode information. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
#' @export
#'
#' @examples
#' \dontrun{
#' library(amapGeocode)
#'
#' # Before the `getCoord()` is executed,
#' # the token should be set by `option(amap_key = 'key')`
#' # or set by key argument in `getCoord()`
#'
#' # Get geocode as a data.table
#' getCoord('IFS Chengdu')
#' # Get geocode as a XML
#' getCoord('IFS Chengdu', output = 'XML')
#'
#' }
#'
#' @seealso \code{\link{extractCoord}}

getCoord <-
  # A wrap of getCoord.individual
  function(address,
           key = NULL,
           city = NULL,
           sig = NULL,
           output = NULL,
           callback = NULL,
           to_table = TRUE,
           keep_bad_request = TRUE,
           max_core = NULL) {
    if (length(address) == 1) {
      # if there is one address, use getCoord.individual directly
      getCoord.individual(
        key = key,
        address = address,
        city = city,
        sig = sig,
        output = output,
        callback = callback,
        to_table = to_table,
        keep_bad_request = keep_bad_request
      )
    } else {
      # Create local parallel cluster
      cluster <- parallel_cluster_maker(max_core = max_core)
      # if there is multiple addresses, use getCoord.individual by parLapply
      ls_queries <-
        parallel::parLapply(
          cl = cluster,
          address,
          getCoord.individual,
          key = key,
          city = city,
          sig = sig,
          output = output,
          callback = callback,
          to_table = to_table,
          keep_bad_request = keep_bad_request
        )
      # stop cluster
      parallel::stopCluster(cluster)
      # detect return list of raw requests or `rbindlist` parsed data.table
      if (isTRUE(to_table)) {
        return(data.table::rbindlist(ls_queries))
      } else {
        return(ls_queries)
      }
    }
  }

#' Get an individual coordinate from location
#'
#' @param address Required.\cr
#' Structured address information. \cr
#' Rules: Country/Region, Province/State, City, County/District, Town, Country, Road, Number, Room, Building.
#' @param key Optional.\cr
#' Amap Key. \cr
#' Applied from 'AutoNavi' Map API official website\url{https://lbs.amap.com/dev/}
#' @param city Optional.\cr
#' Specify the City. \cr
#' Support: city in Chinese, full pinyin, citycode, adcode\url{https://lbs.amap.com/api/webservice/download}.\cr
#' The default value is NULL which will search country-wide. The default value is NULL
#' @param sig Optional.\cr
#' Digital Signature.\cr
#' How to use this argument? Please check here{https://lbs.amap.com/faq/account/key/72}
#' @param output Optional.\cr
#'  Output Data Structure. \cr
#' Support JSON and XML. The default value is JSON.
#' @param callback Optional.\cr
#' Callback Function. \cr
#' The value of callback is the customized function. Only available with JSON output.
#' If you don't understand, it means you don't need it, just like me.
#' @param to_table Optional.\cr
#' Transform response content to data.table.\cr
#' @param keep_bad_request Optional.\cr
#' Keep Bad Request to avoid breaking a workflow, especially meaningful in a batch request
#' @return
#' Returns a JSON, XML or data.table of results containing detailed geocode information. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
getCoord.individual <-
  function(address,
           key = NULL,
           city = NULL,
           sig = NULL,
           output = NULL,
           callback = NULL,
           to_table = TRUE,
           keep_bad_request = TRUE) {
    # Arguments check ---------------------------------------------------------
    # Check if key argument is set or not
    # If there is no key, try to get amap_key from option and set as key
    if (is.null(key)) {
      if (is.null(getOption('amap_key'))) {
        stop(
          'Please set key argument or set amap_key globally by this command
             options(amap_key = your key)',
          call. = FALSE
        )
      }
      key = getOption('amap_key')
    }
    # If to_table has been set, replace output as XML
    # Will be remove once JSON extract function finished
    # if (isTRUE(to_table)) {
    #   output = 'XML'
    # }

    # assemble url and parameter ----------------------------------------------
    base_url = 'https://restapi.amap.com/v3/geocode/geo'

    query_parm = list(
      key = key,
      address = address,
      city = city,
      sig = sig,
      output = output,
      callback = callback
    )

    # GET a response with full url --------------------------------------------
    res <- httr::RETRY("GET", url = base_url, query = query_parm)

    if (!keep_bad_request) {
      httr::stop_for_status(res)
    } else {
      httr::warn_for_status(res, paste0(address, 'makes an unsuccessfully request'))
    }

    res_content <-
      httr::content(res)

    # Transform response to data.table or return directly -------------------------

    if (isTRUE(to_table)) {
      return(extractCoord(res_content))
    } else {
      return(res_content)
    }
  }

#' Extract coordinate from location request
#'
#' @param res Required.\cr
#' Response from getCoord.
#'
#' @return
#' Returns a data.table which extracts detailed coordinate information from results of getCoord. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
#' @export
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#' library(amapGeocode)
#'
#' # Before the `getCoord()` is executed,
#' # the token should be set by `option(amap_key = 'key')`
#' # or set by key argument in `getCoord()`
#'
#' # Get geocode as a XML
#' getCoord('IFS Chengdu', output = 'XML') %>%
#'    # extract geocode regions as a data.table
#'    extractCoord()
#' }
#'
#' @seealso \code{\link{getCoord}}

extractCoord <- function(res) {
  # If there is a bad request, return a data.table directly.
  if (length(res) == 0) {
    data.table::data.table(
      lng = NA,
      lat = NA,
      formatted_address = 'Bad Request',
      country = NA,
      province = NA,
      city = NA,
      district = NA,
      township = NA,
      street = NA,
      number = NA,
      citycode = NA,
      adcode = NA
    )
  } else {
    # Detect what kind of response will go to parse ------------------------------
    xml_detect <-
      any(stringr::str_detect(class(res), 'xml_document'))
    # Convert xml2 to list
    if (isTRUE(xml_detect)) {
      # get the number of retruned address
      res <-
        xml2::as_list(res)
      res <-
        res$response
    }

    # detect whether request succeed or not
    if (res$status != 1) {
      stop(res$info,
           call. = FALSE)
    }

    # detect thee number of response
    obj_count <-
      res$count
    # Return a row with all NA
    if (obj_count == 0) {
      data.table::data.table(
        lng = NA,
        lat = NA,
        formatted_address = NA,
        country = NA,
        province = NA,
        city = NA,
        district = NA,
        township = NA,
        street = NA,
        number = NA,
        citycode = NA,
        adcode = NA
      )
    } else if (obj_count == 1) {
      # get geocodes node for futher parse
      geocode <-
        res$geocodes[[1]]
      # parse lng and lat from location
      location_in_coord =
        # Internal Function from Helpers, no export
        str_loc_to_num_coord(geocode$location)
      # set parameter name
      var_name <-
        c(
          'formatted_address',
          'country',
          'province',
          'city',
          'district',
          'township',
          'street',
          'number',
          'citycode',
          'adcode'
        )
      # extract value of above parameters
      ls_var <- lapply(var_name,
                       function(x) {
                         x = ifelse(sjmisc::is_empty(geocode[[x]]), NA, geocode[[x]])
                       }) %>%
        as.data.frame()

      data.table::data.table(lng = location_in_coord[[1]],
                             lat = location_in_coord[[2]],
                             ls_var) %>%
        # set name of
        stats::setNames(c('lng', 'lat', var_name))
    }
  }
}
