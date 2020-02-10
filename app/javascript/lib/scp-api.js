/**
 * @fileoverview JavaScript client for Single Cell Portal REST API
 * 
 * Succinct, well-documented SCP API wrappers, also enabling easy mocks
 * 
 * API docs: https://singlecell.broadinstitute.org/single_cell/api
 */
import camelcaseKeys from 'camelcase-keys';

const defaultBasePath = '/single_cell/api/v1';

// If true, returns mock data for all API responses.  Only for dev.
const globalMock = false;

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
 * Client for SCP REST API.  Less fetch boilerplate, easier mocks.
 * 
 * @param {String} path | Relative path for API endpoint, e.g. /search/auth_code
 * @param {Boolean} mock | Whether to use mock data.  Helps development, tests.
 */
export default async function scpApi(path, mock=false) {
  
  if (globalMock) mock = true;
  const basePath = (mock || globalMock) ? '/mock_data' : defaultBasePath;
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
  
  // Converts API's snake_case to JS-preferrable camelCase,
  // for easy destructuring assignment.
  return camelcaseKeys(json);
}
