import { accessToken } from './../components/UserProvider'

// See note in logSearch
let isPageLoadSearch = true

const defaultInit = {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json'
  }
}

const bardDomainsByEnv = {
  'development': 'https://terra-bard-dev.appspot.com',
  'staging': 'https://terra-bard-alpha.appspot.com',
  'production': 'https://terra-bard-prod.appspot.com'
}
let bardDomain = ''
const env = ''
let userId = ''
if ('SCP' in window) {
  bardDomain = bardDomainsByEnv[window.SCP.environment]

  // To consider: Replace SCP-specific userId with DSP-wide userId
  userId = window.SCP.userId
}

/**
 * Log page view, i.e. page load
 */
export function logPageView() {
  log('page:view')
}

/** Log click on page.  Delegates to more element-specific loggers. */
export function logClick(event) {
  const target = event.target
  const tag = target.localName.toLowerCase() // local tag name

  if (tag === 'a') {
    logClickLink(target)
  } else if (tag === 'button') {
    logClickButton(target)
  } else if (tag === 'input') {
    logClickInput(target)
  } else {
    logClickOther(target)
  }
}

/**
 * Log click on link, i.e. anchor (<a ...) tag
 */
function logClickLink(target) {
  const props = { text: target.text }
  log('click:link', props)
}

/**
 * Log click on button, e.g. for pagination, "Apply", etc.
 */
function logClickButton(target) {
  const props = { text: target.text }
  log('click:button', props)

  // Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
  ga('send', 'event', 'click', 'button')
}

/**
 * Get label elements for an input element
 *
 * From https://stackoverflow.com/a/15061155
 */
function getLabelsForInputElement(element) {
  let labels
  const id = element.id

  if (element.labels) {
    return element.labels
  }

  if (id) {
    labels = Array.from(document.querySelector(`label[for='${id}']`))
  }

  while (element = element.parentNode) {
    if (element.tagName.toLowerCase() == 'label') {
      labels.push(element)
    }
  }

  return labels
};

/**
 * Log click on input by type, e.g. text, number, checkbox
 */
function logClickInput(target) {
  const domLabels = getLabelsForInputElement(target)

  // User-facing label
  const label = domLabels.length > 0 ? domLabels[0].innerText : ''

  const props = { label }
  const element = `input-${target.type}`
  log(`click:${element}`, props)

  // Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
  ga('send', 'event', 'click', element) // eslint-disable-line no-undef
}

/**
 * Log clicks on elements that are not otherwise classified
 */
function logClickOther(target) {
  const props = { text: target.text }
  log('click:other', props)

  // Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
  ga('send', 'event', 'click', 'other') // eslint-disable-line no-undef
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
 * together in Mixpanel's alphabetized list, log these as "facet-disease" and
 * "facet-species".
 *
 * Also renames filters from opaque IDs (e.g. MONDO_0018076) to huamn-readable
 * labels (e.g. tuberculosis).
 */
function getFriendlyFilterListByFacet(facets) {
  const filterListByFacet = {}
  Object.entries(facets).forEach(([facet, filters]) => {
    const friendlyFacet = `facet-${facet}`
    const friendlyFilters = filters.map(filterId => {
      // This global variable is initialized in application.html.erb
      // and populated in scp-api.js
      return window.SCP.filterNamesById[filterId]
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
 * Log metrics to Mixpanel via Bard web service
 *
 * @param {String} name
 * @param {Object} props
 */
export function log(name, props={}) {
  // If/when Mixpanel is extended beyond home page, remove study name from
  // appPath at least for non-public studies to align with Terra's on
  // identifiable data we want to omit this logging.
  const appPath = window.location.pathname

  props = Object.assign(props, {
    appId: 'single-cell-portal',
    timestamp: Date.now(),
    appPath,
    userId,
    env
  })

  const body = {
    body: JSON.stringify({
      event: name,
      properties: props
    })
  }
  const init = Object.assign(defaultInit, body)

  // Remove once Bard and Mixpanel are ready for SCP
  if ('SCP' in window && window.SCP.environment !== 'production') {
    fetch(`${bardDomain}/api/event`, init)
  }
}
