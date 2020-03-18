/**
 * @fileoverview Functions for client-side usage analytics of SCP REST API
 */

import { log } from './metrics-api'

// See note in logSearch
let isPageLoadSearch = true

const filterNamesById = {}

/**
 * Populates global id-to-name map of retrieved filters, for easier analytics.
 * See downstream use of window.SCP.filterNamesById in metrics-api.js.
 */
export function mapFiltersForLogging(facetsOrFilters, isFacets=false) {
  // If testing, skip.  Tech debt to reconsider later.
  if ('SCP' in window === false) return

  // This construct is kludgy, but helps cohesion and encapsulation
  // by putting related dense code here instead of in the calling functions
  if (isFacets) {
    const facets = facetsOrFilters
    facets.map(facet => {
      facet.filters.map(filter => {
        filterNamesById[filter.id] = filter.name
      })
    })
  } else {
    let filters = facetsOrFilters
    // handle facet filter search results
    if (facetsOrFilters.filters) {
      filters = facetsOrFilters.filters
    }
    filters.map(filter => {
      filterNamesById[filter.id] = filter.name
    })
  }
}

/**
 * Count terms, i.e. space-delimited strings, and consider [""] to have 0 terms
 */
function getNumberOfTerms(terms) {
  let numTerms = 0
  const splitTerms = terms.split(' ')
  if (splitTerms.length > 0 && splitTerms[0] !== '') {
    numTerms = splitTerms.length
  }
  return numTerms
}

/**
 * Counts facets (e.g. species, disease) and filters (e.g. human, COVID-19)
 */
function getNumFacetsAndFilters(facets) {
  const numFacets = Object.keys(facets).length
  const numFilters =
    Object.values(facets).reduce((prevNumFilters, filterArray) => {
      return prevNumFilters + filterArray.length
    }, 0)

  return [numFacets, numFilters]
}

/**
 * Returns human-friendly list of applied filters for each facet
 *
 * This enables us to more feasibly answer "What filters are people using?"
 *
 * Renames keys in facets for easier discoverability as event properties in
 * Mixpanel.  E.g. instead of "disease" and "species", which will not appear
 * together in Mixpanel's alphabetized list, log these as "filtersDisease" and
 * "filtersSpecies".
 *
 * Also renames filters from opaque IDs (e.g. MONDO_0018076) to human-readable
 * labels (e.g. tuberculosis).
 */
function getFriendlyFilterListByFacet(facets) {
  const filterListByFacet = {}
  Object.entries(facets).forEach(([facet, filters]) => {
    const friendlyFacet = `filters${facet[0].toUpperCase() + facet.slice(1)}`
    const friendlyFilters = filters.map(filterId => {
      // This global variable is initialized in application.html.erb
      // and populated in scp-api.js
      return filterNamesById[filterId]
    })
    filterListByFacet[friendlyFacet] = friendlyFilters
  })
  return filterListByFacet
}

/**
 * Log study search metrics.  Might support gene, cell search in future.
 */
export function logSearch(type, terms, facets, page) {
  if (isPageLoadSearch === true) {
    // This prevents over-reporting searches.
    // Loading home page triggers search, which is a side-effect / artifact
    // with regard to tracking user interactions.  This variable is set to
    // false once per page load as a way to omit such artifacts from logging.
    isPageLoadSearch = false
    return
  }

  const numTerms = getNumberOfTerms(terms)
  const [numFacets, numFilters] = getNumFacetsAndFilters(facets)
  const facetList = Object.keys(facets)

  const filterListByFacet = getFriendlyFilterListByFacet(facets)

  const simpleProps = {
    type, terms, page,
    numTerms, numFacets, numFilters, facetList
  }
  const props = Object.assign(simpleProps, filterListByFacet)

  log('search', props)

  // Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
  ga( // eslint-disable-line no-undef
    'send', 'event', 'faceted-search', 'study-search',
    'num-terms', numTerms
  )
}

/**
 * Log filter search metrics
 */
export function logFilterSearch(facet, terms) {
  const numTerms = getNumberOfTerms(terms)

  const defaultProps = { facet, terms }
  const props = Object.assign(defaultProps, { numTerms })
  log('search-filter', props)

  // Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
  ga( // eslint-disable-line no-undef
    'send', 'event', 'faceted-search', 'search-filter',
    'num-terms', numTerms
  )
}

/**
 * Log when a download is authorized.
 * This is our best web-client-side methodology for measuring downloads.
 */
export function logDownloadAuthorization() {
  log('download-authorization')
  ga('send', 'event', 'faceted-search', 'download-authorization') // eslint-disable-line no-undef, max-len
}
