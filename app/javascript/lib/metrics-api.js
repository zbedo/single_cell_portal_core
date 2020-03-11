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
if ('SCP' in window) {
  bardDomain = bardDomainsByEnv[window.SCP.environment]
}

/**
 * Log page view, i.e. page load
 */
export function logPageView() {
  const props = { url: document.location.href }
  log('page:view', props)
}

/** Log click on page.  Delegates to more element-specific loggers. */
export function logClick(event) {
  const target = event.target
  const tag = target.localName.toLowerCase() // local tag name
  const props = {}

  if (tag === 'a') {
    logClickLink(target, props)
  } else if (tag === 'button') {
    logClickButton(target, props)
  } else if (tag === 'input') {
    logClickInput(target, props)
  } else {
    logClickOther(target, props)
  }
}

/**
 * Log click on link, i.e. anchor (<a ...) tag
 */
function logClickLink(target, props) {
  props = Object.assign(props, {
    text: target.text
  })
  log('click:link', props)
}

/**
 * Log click on button
 */
function logClickButton(target, props) {
  props = Object.assign(props, {
    text: target.text
  })
  log('click:button', props)
}

/**
 * Get the text of any label for an input
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
function logClickInput(target, props) {
  const labels = getLabelsForInputElement(target)

  // User-facing label
  const label = labels.length > 0 ? labels[0].innerText : ''

  props = Object.assign(props, { label })

  log(`click:input-${target.type}`, props)
}

/**
 * Log clicks on elements that are not otherwise classified
 */
function logClickOther(target, props) {
  props = Object.assign(props, {
    text: target.text
  })
  log('click:other', props)
}


/**
 * Log study search metrics.  Might support gene, cell search in future.
 */
export function logSearch(type, terms, facets, page) {
  const defaultProps = { type, terms, page }
  const numTerms = terms.split(' ').length

  const props = Object.assign(defaultProps, { numTerms })

  log('search', props)
}

/**
 * Log filter search metrics
 */
export function logFilterSearch(facet, terms) {
  const defaultProps = { facet, terms }
  const numTerms = terms.split(' ').length

  const props = Object.assign(defaultProps, { numTerms })

  log('search-filter', props)
}

/**
 * Log metrics to Mixpanel via Bard web service
 *
 * @param {String} name
 * @param {Object} props
 */
export default function log(name, props) {
  props = Object.assign(props, {
    appId: 'single-cell-portal',
    distinct_id: 'scp-placeholder-0', // TODO: Make this generic
    cohort: 'dev'
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
