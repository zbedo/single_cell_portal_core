/* eslint-disable no-undef */

const fetch = require('node-fetch')
const process = require('process')
import scpApi, {
  fetchAuthCode,
  fetchFacetFilters,
  setGlobalMockFlag,
  fetchSearch
} from '../../app/javascript/lib/scp-api'

describe('JavaScript client for SCP REST API', () => {
  beforeAll(() => {
    global.fetch = fetch
    process.on('unhandledRejection', up => {throw up})
  })
  // afterEach(() => {
  //   global.fetch.mockClear()
  //   delete global.fetch
  // })

  // it('returns `authCode` and `timeInterval` from fetchAuthCode', async () => {
  //   const { authCode, timeInterval } = await fetchAuthCode()
  //   expect(authCode).toBe(123456)
  //   expect(timeInterval).toBe(1800)
  // })

  // it('returns 10 filters from fetchFacetFilters', async () => {
  //   const apiData = await fetchFacetFilters('disease', 'tuberculosis')
  //   expect(apiData.filters).toHaveLength(10)
  // })

  // // Note: tests that mock global.fetch must be put after tests that don't
  // // mock it.  jest.restoreAllMocks() doesn't clear everything as expected,
  // // nor does anything else.

  // // Consider using isolateModules for this type of thing
  // it('includes `Authorization: Bearer` in requests when signed in', () => {
  //   return new Promise(done => {
  //   // Spy on `fetch()` and its contingent methods like `json()`,
  //   // because we want to intercept the outgoing request
  //     const mockSuccessResponse = {}
  //     const mockJsonPromise = Promise.resolve(mockSuccessResponse)
  //     const mockFetchPromise = Promise.resolve({
  //       json: () => {mockJsonPromise}
  //     })
  //     jest.spyOn(global, 'fetch').mockImplementation(() => {
  //       mockFetchPromise
  //     })

  //     fetchFacetFilters('disease', 'tuberculosis')

  //     expect(global.fetch).toHaveBeenCalledWith(
  //       expect.anything(),
  //       expect.objectContaining({
  //         method: 'GET',
  //         headers: {
  //           'Content-Type': 'application/json',
  //           'Accept': 'application/json',
  //           'Authorization': 'Bearer test'
  //         }
  //       })
  //     )
  //     process.nextTick(() => {
  //       jest.restoreAllMocks()
  //       done()
  //     })
  //   })
  // })

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
