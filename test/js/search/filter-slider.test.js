import React from 'react'
import * as ReactAll from 'react'
import { mount } from 'enzyme'
import * as Reach from '@reach/router'

const fetch = require('node-fetch')

import FacetControl from 'components/FacetControl'
import { PropsStudySearchProvider } from 'providers/StudySearchProvider'
import { SearchSelectionContext } from 'providers/SearchSelectionProvider'

const testNoUnitFacet = {
  name: "bmi",
  type: "number",
  id: "bmi",
  links: [],
  filters: [],
  unit: null,
  max: 50,
  min: 1,
  allUnits: null
}

const testUnitFacet = {
  name: "age",
  type: "number",
  id: "age",
  links: [],
  filters: [],
  unit: 'years',
  max: 150,
  min: 1,
  allUnits: null
}

describe('Filter slider works with facet with no units', () => {
  it('handles slider selections', async () => {
    const routerNav = jest.spyOn(Reach, 'navigate')

    let bmiFacet = () => {
      return wrapper.find('#facet-bmi').first()
    }
    const wrapper = mount((
      <PropsStudySearchProvider searchParams={{terms: '', facets:{}, page: 1}}>
        <FacetControl facet={testNoUnitFacet}/>
      </PropsStudySearchProvider>
    ))
    bmiFacet().find('a').first().simulate('click')
    expect(bmiFacet().find('button.facet-apply-button').hasClass('active')).toEqual(true)
    expect(bmiFacet().find('input[type="number"]').length).toEqual(2)
    expect(bmiFacet().find('input[type="number"]').first().props().value).toEqual(1)
    expect(bmiFacet().find('input[type="number"]').last().props().value).toEqual(50)
    expect(bmiFacet().find('select').length).toEqual(0)

    bmiFacet().find('input[type="number"]').first().simulate('change', {
      target: {value: 30}
    })
    expect(bmiFacet().find('button.facet-apply-button').hasClass('active')).toEqual(true)
    bmiFacet().find('button.facet-apply-button').simulate('click')
    expect(routerNav).toHaveBeenLastCalledWith('?type=study&page=1&facets=bmi%3A30%2C50%2C')
  });
});

describe('Filter slider behavior', () => {
  it('handles empty text boxes', async () => {
    const routerNav = jest.spyOn(Reach, 'navigate')

    let ageFacet = () => {
      return wrapper.find('#facet-age').first()
    }
    const wrapper = mount((
      <PropsStudySearchProvider searchParams={{terms: '', facets:{age:['', 150, 'years']}, page: 1}}>
          <FacetControl facet={testUnitFacet}/>
      </PropsStudySearchProvider>
    ))
    ageFacet().find('a').first().simulate('click')
    expect(ageFacet().find('input[type="number"]').length).toEqual(2)
    expect(ageFacet().find('input[type="number"]').first().props().value).toEqual('')
    expect(ageFacet().find('input[type="number"]').last().props().value).toEqual(150)
    expect(ageFacet().find('button.facet-apply-button').hasClass('active')).toEqual(false)

    ageFacet().find('input[type="number"]').first().simulate('change', {
      target: {value: 30}
    })
    expect(ageFacet().find('button.facet-apply-button').hasClass('active')).toEqual(true)
    ageFacet().find('button.facet-apply-button').simulate('click')
    expect(routerNav).toHaveBeenLastCalledWith('?type=study&page=1&facets=age%3A30%2C150%2Cyears')
  });
});

