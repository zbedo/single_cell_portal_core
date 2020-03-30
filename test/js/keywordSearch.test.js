import React from 'react'
import * as Reach from '@reach/router'
import { mount } from 'enzyme'

import KeywordSearch from '../../app/javascript/components/KeywordSearch'
import { PropsStudySearchProvider } from 'components/search/StudySearchProvider';

describe('<KeywordSearch/> rendering>', () => {
  it('should render </KeywordSearch> elements', () => {
    const example = mount(<KeywordSearch/>)
    expect(example.exists('.study-keyword-search')).toEqual(true)
    expect(example.find('svg.svg-inline--fa').hasClass('fa-search')).toEqual(true)
  })

  it('should show the clear button after a search with keyword', () => {
    const routerNav = jest.spyOn(Reach, 'navigate')
    const example = mount(
      <PropsStudySearchProvider searchParams={{terms: 'foobar'}}>
        <KeywordSearch/>
      </PropsStudySearchProvider>
    )
    expect(example.find('svg.svg-inline--fa').hasClass('fa-times')).toEqual(true)
    example.find('form').simulate('submit')
    expect(routerNav).toHaveBeenLastCalledWith('?type=study&page=1')
  })
})
