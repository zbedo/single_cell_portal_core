import React from 'react'
import KeywordSearch from '../../app/javascript/components/KeywordSearch'
import { mount } from 'enzyme'


describe('<KeywordSearch/> rendering>', () => {
  it('should render </KeywordSearch> elements', () => {
    const example = mount(<KeywordSearch/>)
    expect(example.exists('.study-keyword-search')).toEqual(true)
  })
})
