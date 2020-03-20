import React from 'react'
import KeywordSearch from '../../app/javascript/components/KeywordSearch'
import { shallow } from 'enzyme'
import Button from 'react-bootstrap/lib/Button'
import Form from 'react-bootstrap/lib/Form'


describe('<KeywordSearch/> rendering>', () => {
  it('should render </KeywordSearch> elements', () => {
    const keywordSearch = shallow(<KeywordSearch/>)
    expect(keywordSearch.find(Form)).toHaveLength(1)
    expect(keywordSearch.find('input')).toHaveLength(1)
    expect(keywordSearch.find(Button)).toHaveLength(1)
  })
})
