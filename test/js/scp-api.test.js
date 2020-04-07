/* eslint-disable no-undef */

const fetch = require('node-fetch')
import scpApi, {
  fetchAuthCode,
  fetchFacetFilters
} from '../../app/javascript/lib/scp-api'

describe('JavaScript client for SCP REST API', () => {
  beforeAll(() => {
    global.fetch = fetch
  })
  // Note: tests that mock global.fetch must be cleared after every test
  afterEach(() => {
    // Restores all mocks back to their original value
    jest.restoreAllMocks()
  })

  it('returns `authCode` and `timeInterval` from fetchAuthCode', async () => {
    const { authCode, timeInterval } = await fetchAuthCode()
    expect(authCode).toBe(123456)
    expect(timeInterval).toBe(1800)
  })

  it('returns 10 filters from fetchFacetFilters', async () => {
    const apiData = await fetchFacetFilters('disease', 'tuberculosis')
    expect(apiData.filters).toHaveLength(10)
  })

  it('includes `Authorization: Bearer` in requests when signed in', () => {
    return new Promise(done => {
    // Spy on `fetch()` and its contingent methods like `json()`,
    // because we want to intercept the outgoing request
      const mockSuccessResponse = {}
      const mockJsonPromise = Promise.resolve(mockSuccessResponse)
      const mockFetchPromise = Promise.resolve({
        json: () => {mockJsonPromise}
      })
      jest.spyOn(global, 'fetch').mockImplementation(() => {
        mockFetchPromise
      })

      fetchFacetFilters('disease', 'tuberculosis')

      expect(global.fetch).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer test'
          }
        })
      )
    })
  })

  it('catches 500 errors', async () => {
    const mockErrorResponse = {
      type: 'basic',
      url: 'http://localhost:3000/single_cell/api/v1/search?type=study',
      redirected: false,
      status: 500,
      ok: false,
      statusText: 'Internal Server Error'
    }
    jest.spyOn(global, 'fetch').mockReturnValue(Promise.resolve(mockErrorResponse))
    const actual_response = await scpApi('/test/path', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    }, false)
    expect(actual_response.status).toEqual(500)
    expect(actual_response.ok).toEqual(false)
  })
})
