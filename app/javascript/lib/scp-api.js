/**
 * @fileoverview JavaScript client for Single Cell Portal REST API
 *
 * Succinct, well-documented SCP API wrappers, also enabling easy mocks
 *
 * API docs: https://singlecell.broadinstitute.org/single_cell/api
 */

import camelcaseKeys from 'camelcase-keys'
import _compact from 'lodash/compact'

import { accessToken } from './../components/UserProvider'
import {
  logFilterSearch, logSearch, logDownloadAuthorization, mapFiltersForLogging
} from './scp-api-metrics'

// If true, returns mock data for all API responses.  Only for dev.
let globalMock = false

const defaultBasePath = '/single_cell/api/v1'

const defaultInit = {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
}

if (
  accessToken !== '' // accessToken is a blank string when not signed in
) {
  defaultInit.headers = Object.assign(defaultInit.headers, {
    'Authorization': `Bearer ${accessToken}`
  })
}

/**
 * Get a one-time authorization code for download, and its lifetime in seconds
 *
 * TODO:
 * - Update API to use "expires_in" instead of "time_interval"
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_auth_code_path
 *
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object described in "Example return" above
 *
 * @example
 *
 * // returns {authCode: 123456, timeInterval: 1800}
 * fetchAuthCode(true)
 */
export async function fetchAuthCode(mock=false) {
  let init = defaultInit
  if (mock === false && globalMock === false) {
    init = Object.assign({}, defaultInit, {
      method: 'POST'
    })
  }
  logDownloadAuthorization()
  return await scpApi('/search/auth_code', init, mock)
}

/**
 * Returns list of all available search facets, including default filter values
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_facets_path
 *
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object containing camel-cased data from API
 */
export async function fetchFacets(mock=false) {
  const facets = await scpApi('/search/facets', defaultInit, mock)

  mapFiltersForLogging(facets, true)

  return facets
}

/**
 * Sets flag on whether to use mock data for all API responses.
 *
 * This method is useful for tests and certain development scenarios,
 * e.g. when evolving a new API or to work around occasional API blockers.
 *
 * @param {Boolean} flag Whether to use mock data for all API responses
 */
export function setGlobalMockFlag(flag) {
  globalMock = flag
}

// Modifiable in setMockOrigin, used in unit tests
let mockOrigin = ''

/**
 * Sets origin (e.g. http://localhost:3000) for mocked SCP API URLs
 *
 * This enables mock data to be used from Jest tests
 *
 * @param {Boolean} origin Origin (e.g. http://localhost:3000) for mocked SCP API URLs
 */
export function setMockOrigin(origin) {
  mockOrigin = origin
}

/**
 * Returns a list of matching filters for a given facet
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_facet_filters_path
 *
 * @param {String} facet Identifier of facet
 * @param {String} query User-supplied query string
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object containing camel-cased data from API
 *
 * @example
 *
 * // returns Promise for mock JSON
 * // in /mock_data/facet_filters_disease_tuberculosis.json
 * fetchFacetFilters('disease', 'tuberculosis', true);
 *
 * // returns Promise for live JSON as shown example from
 * // "Docs" link above (but camel-cased)
 * fetchFacetFilters('disease', 'tuberculosis');
 */
export async function fetchFacetFilters(facet, query, mock=false) {
  let queryString = `?facet=${facet}&query=${query}`
  if (mock || globalMock) {
    queryString = `_${facet}_${query}`
  }

  logFilterSearch(facet, query)

  const pathAndQueryString = `/search/facet_filters${queryString}`

  const filters = await scpApi(pathAndQueryString, defaultInit, mock)

  mapFiltersForLogging(filters)

  return filters
}

/**
 *  Returns number of files and bytes (by file type), to preview bulk download
 *
 * Docs:
 * https://singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_bulk_download_size_path
 *
 * @param {Array} List of study accessions to preview download
 * @param {Array} fileTypes List of file types in studies to preview download
 *
 * @example returns Promise for JSON
 * {"Expression":{"total_files":4,"total_bytes":1797720765},"Metadata":{"total_files":2,"total_bytes":865371}}
 * fetchDownloadSize([SCP200, SCP201], ["Expression", "Metadata"])
 */
export async function fetchDownloadSize(accessions, fileTypes, mock=false) {
  const fileTypesString = fileTypes.join(',')
  const queryString = `?accessions=${accessions}&file_types=${fileTypesString}`
  const pathAndQueryString = `/search/bulk_download_size/${queryString}`
  return await scpApi(pathAndQueryString, defaultInit, mock)
}

/**
 * Returns a list of matching studies given a keyword and facets
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_facet_filters_path
 *
 * @param {String} type Type of query to perform (study- or cell-based)
 * @param {Object} searchParams  User-supplied search parameters including
 *            {String}  terms: User-supplied query string
 *            {Object}  facets: User-supplied list facets and filters
 *            {Integer} page: User-supplied list facets and filters
 *            {String}  order: User-supplied query ordering field
 *            {String}  preset: User-supplied query preset (e.g. 'covid19')
 * @param {Boolean} mock Whether to use mock data
 * @returns {Promise} Promise object containing camel-cased data from API
 *
 * @example
 *
 * fetchSearch('study', 'tuberculosis');
 */
export async function fetchSearch(
  type, searchParams, mock=false
) {
  const path = `/search?${buildSearchQueryString(type, searchParams)}`

  const searchResults = await scpApi(path, defaultInit, mock)

  logSearch(type, searchParams)

  return searchResults
}

/** Constructs query string used for /search REST API endpoint */
export function buildSearchQueryString(type, searchParams) {
  const facetsParam = buildFacetQueryString(searchParams.facets)
  const otherParamString = ['page', 'order', 'terms', 'preset'].map(param => {
    return searchParams[param] ? `&${param}=${searchParams[param]}` : ''
  }).join('')

  return `type=${type}${otherParamString}${facetsParam}`
}

/** Serializes "facets" URL parameter for /search API endpoint */
function buildFacetQueryString(facets) {
  if (!facets || !Object.keys(facets).length) {
    return ''
  }
  const rawURL = _compact(Object.keys(facets).map(facetId => {
    if (facets[facetId].length) {
      return `${facetId}:${facets[facetId].join(',')}`
    }
  })).join('+')
  // encodeURIComponent needed for the + , : characters
  return `&facets=${encodeURIComponent(rawURL)}`
}

/** Deserializes "facets" URL parameter into facets object */
export function buildFacetsFromQueryString(facetsParamString) {
  const facets = {}
  if (facetsParamString) {
    facetsParamString.split('+').forEach(facetString => {
      const facetArray = facetString.split(':')
      facets[facetArray[0]] = facetArray[1].split(',')
    })
  }
  return facets
}

/**
 * Client for SCP REST API.  Less fetch boilerplate, easier mocks.
 *
 * @param {String} path | Relative path for API endpoint, e.g. /search/auth_code
 * @param {Object} init | Object for settings, just like standard fetch `init`
 * @param {Boolean} mock | Whether to use mock data.  Helps development, tests.
 */
export default async function scpApi(path, init, mock=false) {
  if (globalMock) mock = true
  const basePath =
    (mock || globalMock) ? `${mockOrigin}/mock_data` : defaultBasePath
  let fullPath = basePath + path
  if (mock) fullPath += '.json' // e.g. /mock_data/search/auth_code.json

  const response = await fetch(fullPath, init)
  const json = await response.json()

  // Converts API's snake_case to JS-preferrable camelCase,
  // for easy destructuring assignment.
  return camelcaseKeys(json)
}
