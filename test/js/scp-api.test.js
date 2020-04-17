// Without disabling eslint code, Promises are auto inserted
/* eslint-disable*/

const fetch = require('node-fetch')
import scpApi, { fetchAuthCode, fetchFacetFilters } from 'lib/scp-api'

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

  it('catches 500 errors', async () => {
    const mockErrorResponse = {
      type: 'basic',
      url: 'http://localhost:3000/single_cell/api/v1/search?type=study',
      redirected: false,
      status: 500,
      ok: false,
      statusText: 'Internal Server Error'
    }
    jest
      .spyOn(global, 'fetch')
      .mockReturnValue(Promise.resolve(mockErrorResponse))
    const actualResponse = await scpApi('/test/path', {}, false)
    expect(actualResponse.status).toEqual(500)
    expect(actualResponse.ok).toEqual(false)
  })
})
