const fetch = require('node-fetch');

import {
  fetchAuthCode,
  fetchFacets,
  fetchFacetsFilters
} from '../../app/javascript/lib/scp-api';

describe('JavaScript client for SCP REST API', () => {
  beforeAll(() => {
    global.fetch = fetch;
  });

  it('should return `authCode` and `timeInterval` from fetchAuthCode', async () => {
    const {authCode, timeInterval} = await fetchAuthCode();
    expect(authCode).toBe(123456);
    expect(timeInterval).toBe(1800);
  });

  it('should return 10 filters from fetchFacetFilters', async () => {
    const apiData = await fetchFacetsFilters('disease', 'tuberculosis');
    expect(apiData.filters).toHaveLength(10);
  });

});
