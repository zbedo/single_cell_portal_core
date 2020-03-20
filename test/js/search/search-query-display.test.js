import React from 'react';
import * as ReactAll from 'react';
import { mount } from 'enzyme';

const fetch = require('node-fetch');

import SearchQueryDisplay from 'components/SearchQueryDisplay';

const oneStringFacet = [
  {id: 'species', filters: [{id: "NCBITaxon_9606", name: "Homo sapiens"}]}
]

const twoStringFacets = [
  {id: 'disease', filters: [{id: "id1", name: "disease1"}]},
  {id: 'species', filters: [{id: "NCBITaxon_9606", name: "Homo sapiens"}]}
]

const stringAndNumericFacets = [
  {id: 'species', filters: [
    {id: "NCBITaxon_9606", name: "Homo sapiens"},
    {id: "NCBITaxon_10090", name: "Mus musculus"}
  ]},
  {id: "organism_age", filters: {min: 14, max: 180, unit: "years"}}
]

describe('Search query display text', () => {
  it('renders a single facet', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={oneStringFacet} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (species: Homo sapiens)')
  })

  it('renders multiple facets', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={twoStringFacets} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (disease: disease1) AND (species: Homo sapiens)')
  })

  it('renders string and numeric facets', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={stringAndNumericFacets} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (species: Homo sapiens OR Mus musculus) AND (organism_age: 14 - 180 years)')
  })

  it('renders terms', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={[]} terms={['foo']}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Text contains (foo)')
  })

  it('renders terms and a single facet', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={oneStringFacet} terms={['foo', 'bar']}/>
    ))
    expect(wrapper.text().trim()).toEqual(': (Text contains (foo OR bar)) AND (Metadata contains (species: Homo sapiens))')
  })
})
