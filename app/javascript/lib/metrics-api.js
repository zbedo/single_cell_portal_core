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
  props = Object.assign(props, { appId: 'single-cell-portal' })

  const body = {
    body: JSON.stringify({
      event: name,
      properties: props
    })
  }
  const init = Object.assign(defaultInit, body)
  fetch(`${bardDomain}/api/event`, init)
}
