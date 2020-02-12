/**
 * @fileoverview JavaScript client for Single Cell Portal REST API
 *
 * Succinct, well-documented SCP API wrappers, also enabling easy mocks
 *
 * API docs: https://singlecell.broadinstitute.org/single_cell/api
 */
import camelcaseKeys from 'camelcase-keys';

const defaultBasePath = '/single_cell/api/v1';

// API endpoints that use HTTP methods other than the SCP API default
const otherMethods = {
  '/search/auth_code': 'POST'
};

const otherHeaders = {
  '/search/auth_code': {
    'Authorization': 'Bearer ' + window.userAccessToken
  }
}

/**
 * Get a one-time authorization code for download, and its lifetime in seconds
 *
 * TODO:
 * - Update API to use "expires_in" instead of "time_interval", for understandability
 *
 * Example return:
 * {
 *  authCode: 12345,
 *  timeInterval: 1800
 * }
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_auth_code_path
 *
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object described in "Example return" above
 */
export async function fetchAuthCode(mock=false) {
  return await scpApi('/search/auth_code', mock);
}

/**
 * Returns a list of all available search facets, including default filter values
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_facets_path
 *
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object containing camel-cased data from API
 */
export async function fetchFacets(mock=false) {
  return await scpApi('/search/facets', mock);
}

// If true, returns mock data for all API responses.  Only for dev.
let globalMock = false;

/**
 * Sets flag on whether to use mock data for all API responses.
 *
 * This method is useful for tests and certain development scenarios,
 * e.g. when evolving a new API or to work around occasional API blockers.
 *
 * @param {Boolean} flag Whether to use mock data for all API responses
 */
export function setGlobalMockFlag(flag) {
  globalMock = flag;
}

// Modifiable in setMockOrigin, used in unit tests
let mockOrigin = '';

/**
 * Sets origin (e.g. http://localhost:3000) for mocked SCP API URLs
 *
 * This enables mock data to be used from Jest tests
 *
 * @param {Boolean} origin Origin (e.g. http://localhost:3000) for mocked SCP API URLs
 */
export function setMockOrigin(origin) {
  mockOrigin = origin;
}

/**
 * Returns a list of matching filters for a given facet
 *
 * Docs: https:///singlecell.broadinstitute.org/single_cell/api/swagger_docs/v1#!/Search/search_facet_filters_path
 *
 * @example
 * // returns Promise for mock JSON in /mock_data/facets_filters_disease_tuberculosis.json
 * fetchFacetsFilters('disease', 'tuberculosis', true);
 * // returns Promise for live JSON as shown example from "Docs" link above (but camel-cased)
 * fetchFacetsFilters('disease', 'tuberculosis');
 * @param {String} facet Identifier of facet
 * @param {String} query User-supplied query string
 * @param {Boolean} mock Whether to use mock data.  Helps development, tests.
 * @returns {Promise} Promise object containing camel-cased data from API
 */
export async function fetchFacetsFilters(facet, query, mock=false) {

  const queryString = (!(mock || globalMock)) ? `?facet=${facet}&query=${query}` : `_${facet}_${query}`;

  return await scpApi(`/search/facets_filters${queryString}`, mock);
}

/**
 * Client for SCP REST API.  Less fetch boilerplate, easier mocks.
 *
 * @param {String} path | Relative path for API endpoint, e.g. /search/auth_code
 * @param {Boolean} mock | Whether to use mock data.  Helps development, tests.
 */
export default async function scpApi(path, mock=false) {
  console.log('in scpApi, path: ', path)
  if (globalMock) mock = true;
  const basePath = (mock || globalMock) ? mockOrigin + '/mock_data' : defaultBasePath;
  const method = (!mock && path in otherMethods) ? otherMethods[path] : 'GET';
  let fullPath = basePath + path;
  if (mock) fullPath += '.json'; // e.g. /mock_data/search/auth_code.json

  const baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
  const headers = (!mock && path in otherHeaders) ? otherHeaders[path] : {};
  const allHeaders = Object.assign(baseHeaders, headers);

  const response = await fetch(fullPath, {
    method: method,
    headers: allHeaders
  });
  const json = await response.json();

  console.log('json', json)
  // Converts API's snake_case to JS-preferrable camelCase,
  // for easy destructuring assignment.
  return camelcaseKeys(json);
}
