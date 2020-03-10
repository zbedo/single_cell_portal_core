import { accessToken } from './../components/UserProvider'

const defaultInit = {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${accessToken}`
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
 * Log search metrics
 */
export function logSearch(type, terms, facets, page) {
  const props = { type, terms, page }
  log('search', props)
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
  console.log('init')
  console.log(init)
  // fetch(`${bardDomain}/event`, init)
  fetch('https://terra-bard-dev.appspot.com/api/event', init)
}
