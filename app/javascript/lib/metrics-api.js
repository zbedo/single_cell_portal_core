import { accessToken } from './../components/UserProvider'

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

  log(`click:input-${target.type}`, props)
}

/**
 * Log clicks on elements that are not otherwise classified
 */
function logClickOther(target) {
  const props = { text: target.text }
  log('click:other', props)
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
 * Log study search metrics.  Might support gene, cell search in future.
 */
export function logSearch(type, terms, facets, page) {
  const numTerms = getNumberOfTerms(terms)
  // const defaultProps = { type, terms, page }
  // const numTerms = getNumberOfTerms(terms)

  // const props = Object.assign(defaultProps, { numTerms })

  // log('search', props)
  ga('send', 'event', 'faceted-search', 'study-search', 'num-terms', numTerms)
}

/**
 * Log filter search metrics
 */
export function logFilterSearch(facet, terms) {
  const numTerms = getNumberOfTerms(terms)

  const defaultProps = { facet, terms }
  const props = Object.assign(defaultProps, { numTerms })

  // log('search-filter', props)
  ga('send', 'event', 'faceted-search', 'search-filter', 'num-terms', numTerms)
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
  fetch(`${bardDomain}/api/event`, init)
}
