#' Get location from coordinate
#'
#' @param lng Required. \cr
#' Longitude in decimal
#' @param lat Required. \cr
#' Latitude in decimal
#' @param key Optional.\cr
#' Amap Key. \cr
#' Applied from 'AutoNavi' Map API official website\url{https://lbs.amap.com/dev/}
#' @param poitype Optional.\cr
#' Return nearby POI types.\cr
#' When `extensions = all`, this argument makes sense. For detailed poitype type, please refer\url{https://lbs.amap.com/api/webservice/download}
#' @param radius Optional.\cr
#' Searching radius.\cr
#' radius ranges from 0 to 3000, the default value is 1000, unit: meter.
#' @param extensions Optional.\cr
#' Return results controller.\cr
#' `base`: the default value, it only return base information about coordinate.\cr
#' `all`: it will return nearby POI, road information and cross information.
#' @param roadlevel Optional.\cr
#' Road levels.\cr
#' When `extensions = all`, this argument makes sense. \cr
#' `roadlevel=0`, return all roads.\cr
#' `roadlevel=1`, only return main roads.
#' @param sig Optional.\cr
#' Digital Signature.\cr
#' How to use this argument? Please check here{https://lbs.amap.com/faq/account/key/72}
#' @param output Optional.\cr
#' Output Data Structure. \cr
#' Support JSON and XML. The default value is JSON.
#' @param callback Optional.\cr
#' Callback Function. \cr
#' The value of callback is the customized function. Only available with JSON output.
#' If you don't understand, it means you don't need it, just like me.
#' @param homeorcorp Optional.\cr
#' Optimize the order of returned POI or not.\cr
#' When `extensions = all`, this argument makes sense. \cr
#' `homeorcorp=0`, do not optimize, by default.\cr
#' `homeorcorp=1`, home related POIs are first, by default.\cr
#' `homeorcorp=2`, corporation related POIs are first, by default.\cr
#' @param to_table Optional.\cr
#' Transform response content to tibble.\cr
#'
#' @return
#' Returns a JSON, XML or Tibble of results containing detailed reverse geocode information. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
#' @export
#' @examples
#' \dontrun{
#' library(amapGeocode)
#'
#' # Set the amap_key which is applied from 'AutoNavi' Map Services for amapGeocde globally.
#' options(amap_key = 'REPLACE THIS BY YOUR KEY')
#
#' # Get reverse-geocode as a tibble
#' getLocation(104.043284, 30.666864)
#' # Get reverse-geocode as a XML
#' getLocation('104.043284, 30.666864', output = 'XML')
#'
#' }
#'
#' @seealso \code{\link{extractCoord}}
getLocation <-
  function(lng,
           lat,
           key = NULL,
           poitype = NULL,
           radius = NULL,
           extensions = NULL,
           roadlevel = NULL,
           sig = NULL,
           output = NULL,
           callback = NULL,
           homeorcorp = 0,
           to_table = TRUE) {
    if (length(lng) != length(lat)) {
      stop('The numbers of Longitude and Latitude are mismatched')
    }
    if (length(lng) == 1) {
      # if there is one address, use getCoord.individual directly
      getLocation.individual(
        lng = lng,
        lat = lat,
        key = key,
        poitype = poitype,
        radius = radius,
        extensions = extensions,
        roadlevel = roadlevel,
        sig = sig,
        output = output,
        callback = callback,
        homeorcorp = homeorcorp,
        to_table = to_table
      )
    } else {
      # if there is multiple addresses, use getCoord.individual by laapply
      ls_queries <-
        purrr::map2(
          lng,
          lat,
          getLocation.individual,
          key = key,
          poitype = poitype,
          radius = radius,
          extensions = extensions,
          roadlevel = roadlevel,
          sig = sig,
          output = output,
          callback = callback,
          homeorcorp = homeorcorp,
          to_table = to_table
        )
      # detect return list of raw requests or `bind_rows` parsed tibble
      if (isTRUE(to_table)) {
        ls_queries %>%
          dplyr::bind_rows() %>%
          return()
      } else {
        return(ls_queries)
      }
    }
  }

#' Get an individual location from coordinate
#'
#' @param lng Required. \cr
#' Longitude in decimal
#' @param lat Required. \cr
#' Latitude in decimal
#' @param key Optional.\cr
#' Amap Key. \cr
#' Applied from 'AutoNavi' Map API official website\url{https://lbs.amap.com/dev/}
#' @param poitype Optional.\cr
#' Return nearby POI types.\cr
#' When `extensions = all`, this argument makes sense. For detailed poitype type, please refer\url{https://lbs.amap.com/api/webservice/download}
#' @param radius Optional.\cr
#' Searching radius.\cr
#' radius ranges from 0 to 3000, the default value is 1000, unit: meter.
#' @param extensions Optional.\cr
#' Return results controller.\cr
#' `base`: the default value, it only return base information about coordinate.\cr
#' `all`: it will return nearby POI, road information and cross information.
#' @param roadlevel Optional.\cr
#' Road levels.\cr
#' When `extensions = all`, this argument makes sense. \cr
#' `roadlevel=0`, return all roads.\cr
#' `roadlevel=1`, only return main roads.
#' @param sig Optional.\cr
#' Digital Signature.\cr
#' How to use this argument? Please check here{https://lbs.amap.com/faq/account/key/72}
#' @param output Optional.\cr
#' Output Data Structure. \cr
#' Support JSON and XML. The default value is JSON.
#' @param callback Optional.\cr
#' Callback Function. \cr
#' The value of callback is the customized function. Only available with JSON output.
#' If you don't understand, it means you don't need it, just like me.
#' @param homeorcorp Optional.\cr
#' Optimize the order of returned POI or not.\cr
#' When `extensions = all`, this argument makes sense. \cr
#' `homeorcorp=0`, do not optimize, by default.\cr
#' `homeorcorp=1`, home related POIs are first, by default.\cr
#' `homeorcorp=2`, corporation related POIs are first, by default.\cr
#' @param to_table Optional.\cr
#' Transform response content to tibble.\cr
#'
#' @return
#' Returns a JSON, XML or Tibble of results containing detailed reverse geocode information. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
getLocation.individual <-
  function(lng,
           lat,
           key = NULL,
           poitype = NULL,
           radius = NULL,
           extensions = NULL,
           roadlevel = NULL,
           sig = NULL,
           output = NULL,
           callback = NULL,
           homeorcorp = 0,
           to_table = TRUE) {
    # Arguments check ---------------------------------------------------------
    # Check if key argument is set or not
    # If there is no key, try to get amap_key from option and set as key
    if (is.null(key)) {
      if (is.null(getOption('amap_key'))) {
        stop(
          'Please set key argument or set amap_key globally by this command
             options(amap_key = your key)'
        )
      }
      key = getOption('amap_key')
    }
    # Combine lng and lat as location
    # Internal Function from Helpers, no export
    location = num_coord_to_str_loc(lng, lat)
    # assemble url and parameter ----------------------------------------------

    base_url = 'https://restapi.amap.com/v3/geocode/regeo'

    query_parm = list(
      key = key,
      location = location,
      poitype = poitype,
      radius = radius,
      extensions = extensions,
      roadlevel = roadlevel,
      sig = sig,
      output = output,
      callback = callback,
      homeorcorp = homeorcorp
    )

    # GET a response with full url --------------------------------------------

    res <-
      httr::RETRY('GET', url = base_url, query = query_parm)
    httr::stop_for_status(res)
    res_content <-
      httr::content(res)

    # Transform response to tibble or return directly -------------------------

    if (isTRUE(to_table)) {
      extractLocation(res_content) %>%
        return()
    } else {
      return(res_content)
    }
  }

#' Extract location from coordinate request
#'
#' @param res Required.\cr
#' Response from getLocation.
#'
#' @return
#' Returns a tibble which extracts detailed location information from results of getLocation. See \url{https://lbs.amap.com/api/webservice/guide/api/georegeo} for more information.
#' @export
#' @examples
#' \dontrun{
#' library(dplyr)
#' library(amapGeocode)
#'
#' # Set the amap_key which is applied from 'AutoNavi' Map Services for amapGeocde globally.
#' options(amap_key = 'REPLACE THIS BY YOUR KEY')
#
#' # Get reverse-geocode as a XML
#' getLocation(104.043284, 30.666864, output = 'XML') %>%
#'    # extract reverse-geocode regions as a tibble
#'    extractLocation()
#' }
#'
#' @seealso \code{\link{getLocation}}

extractLocation <- function(res) {
  # Detect what kind of response will go to parse ------------------------------
  xml_detect <-
    any(stringr::str_detect(class(res), 'xml_document'))
  # Convert xml2 to list
  if (isTRUE(xml_detect)) {
    # get the number of retruned address
    res <-
      res %>% xml2::as_list() %>% '$'('response')
  }

  # check the status of request
  request_stat <-
    res$status

  # If request_stat is failure
  # Return the failure information
  if (request_stat == '0') {
    stop(res$info)
  }

  # get addressComponent from regeocode
  regeocode <-
    res$regeocode

  # detect thee number of response
  # there is no count parameter in this query
  # due to this, use the number of formatted_address
  # as the count of queries.
  obj_count <-
    regeocode$formatted_address %>%
    length()

  if (obj_count == 0) {
    tibble::tibble(
      country = NA,
      province = NA,
      city = NA,
      district = NA,
      township = NA,
      citycode  = NA,
      towncode = NA
    )
  } else {
    addressComponent <-
      regeocode$addressComponent
    # assemble information tible
    var_name = c('country',
                 'province',
                 'city',
                 'district',
                 'township',
                 'citycode',
                 'towncode')
    # extract value of above parameters
    ls_var <-
      lapply(var_name,
             function(x) {
               x = ifelse(sjmisc::is_empty(addressComponent[[x]]),
                          NA,
                          addressComponent[[x]])
             }) %>%
      as.data.frame()
    tibble::tibble(formatted_address = regeocode$formatted_address[[1]],
                   ls_var) %>%
      # set name of tibble
      stats::setNames(c('formatted_address', var_name))
  }
}