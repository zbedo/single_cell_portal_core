/* eslint-disable no-undef */

import React from 'react'
import { mount } from 'enzyme'

const fetch = require('node-fetch')

import DownloadButton from '../../app/javascript/components/DownloadButton'
import * as UserProvider from '../../app/javascript/components/UserProvider'
import * as StudySearchProvider
  from '../../app/javascript/components/search/StudySearchProvider'

describe('Download components for faceted search', () => {
  beforeAll(() => {
    global.fetch = fetch

    const userContext = { accessToken: 'test' }
    const studySearchContext = {
      results: { matchingAccessions: ['SCP1', 'SCP2'] }
    }

    jest.spyOn(UserProvider, 'useContextUser')
      .mockImplementation(() => {
        return userContext
      })

    jest.spyOn(StudySearchProvider, 'useContextStudySearch')
      .mockImplementation(() => {
        return studySearchContext
      })
  })

  it('shows Download button', async () => {
    const wrapper = mount((< DownloadButton />))
    expect(wrapper.find('DownloadButton')).toHaveLength(1)
  })

  it('shows modal upon clicking Download button', async () => {
    const wrapper = mount(<DownloadButton />)

    // To consider: Having to call "wrapper.find('Modal').first()" is tedious,
    // but assigning it to a variable fails to capture updates.  Find a
    // more succinct approach that captures updates.
    expect(wrapper.find('Modal').first().prop('show')).toEqual(false)
    wrapper.find('#download-button > span').simulate('click')

    expect(wrapper.find('Modal').first().prop('show')).toEqual(true)
  })
})
