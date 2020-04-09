import React from 'react';
import * as ReactAll from 'react';
import { mount } from 'enzyme';

import Study from 'components/search/results/Study';

const facetMatchedStudy = {
  name: 'Tuberculosis subtypes in human male blood',
  description: 'stuff and things',
  cell_count: 130,
  facet_matches: {
    facet_search_weight: 1,
    organ: [{id: 'id1', name: 'blood'}]
  }
}

const complexFacetMatchedStudy = {
  name: 'Tuberculosis subtypes in human male blood',
  description: 'stuff and things',
  cell_count: 130,
  facet_matches: {
    facet_search_weight: 1,
    organ: [{id: 'id1', name: 'blood'}],
    species: [{id: 'id5', name: 'mouse'}, {id: 'id7', name: 'human'}]
  }
}

const numericFacetMatchedStudy = {
  name: 'Tuberculosis subtypes in human male blood',
  description: 'stuff and things',
  cell_count: 130,
  facet_matches: {
    facet_search_weight: 1,
    organism_age: [{min: 30, max: 50, unit: 'years'}]
  }
}

const numericFacetMatchedRange0Study = {
  name: 'Tuberculosis subtypes in human male blood',
  description: 'stuff and things',
  cell_count: 130,
  facet_matches: {
    facet_search_weight: 1,
    organism_age: [{min: 0, max: 50, unit: 'years'}]
  }
}

const facetUnmatchedStudy = {
  name: 'Tuberculosis subtypes in human male blood',
  description: 'stuff and things'
}

describe('Facet match badges', () => {
  it('renders no badges with no matches', async () => {
    const wrapper = mount((
      <Study study={facetUnmatchedStudy}/>
    ))
    expect(wrapper.find('.facet-match').length).toEqual(0)
  })

  it('renders one badges with one match', async () => {
    const wrapper = mount((
      <Study study={facetMatchedStudy}/>
    ))
    expect(wrapper.find('.facet-match').length).toEqual(1)
    expect(wrapper.find('.facet-match').first().text().trim()).toEqual('blood')
  })

  it('renders two badges with two matches', async () => {
    const wrapper = mount((
      <Study study={complexFacetMatchedStudy}/>
    ))
    expect(wrapper.find('.facet-match').length).toEqual(2)
    expect(wrapper.find('.facet-match').first().text().trim()).toEqual('blood')
    expect(wrapper.find('.facet-match').last().text().trim()).toEqual('mouse,human')
  })

  it('renders badges for numeric facets', async () => {
    const wrapper = mount((
      <Study study={numericFacetMatchedStudy}/>
    ))
    expect(wrapper.find('.facet-match').length).toEqual(1)
    expect(wrapper.find('.facet-match').first().text().trim()).toEqual('organism age 30-50 years')
    const wrapper2 = mount((
      <Study study={numericFacetMatchedRange0Study}/>
    ))
    expect(wrapper2.find('.facet-match').length).toEqual(1)
    expect(wrapper2.find('.facet-match').first().text().trim()).toEqual('organism age 0-50 years')
  })
})
