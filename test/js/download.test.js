import React from 'react';
import { mount } from 'enzyme';

const fetch = require('node-fetch');

import DownloadButton from '../../app/javascript/components/DownloadButton';

describe('Download components for faceted search', () => {
  beforeAll(() => {
    global.fetch = fetch;
  });

  it('should show Download button', async () => {
    const wrapper = mount((< DownloadButton />));
    expect(wrapper.find('DownloadButton')).toHaveLength(1);
  });

  it('should show Bulk Download modal upon clicking Download button', async () => {
    const wrapper = mount((< DownloadButton />));

    // TODO: Having to call "wrapper.find('Modal').first()" is tedious,
    // but assigning it to a variable fails to capture updates.  Find a
    // more succinct approach that captures updates.
    expect(wrapper.find('Modal').first().prop('show')).toEqual(false);
    wrapper.find('#download-button > span').simulate('click');

    expect(wrapper.find('Modal').first().prop('show')).toEqual(true);
  });

});
