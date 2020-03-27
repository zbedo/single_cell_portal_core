import React from 'react'
import { mount } from 'enzyme'

const fetch = require('node-fetch')

import SearchQueryDisplay, { ClearAllButton } from 'components/SearchQueryDisplay'
import { PropsStudySearchProvider } from 'components/search/StudySearchProvider'
import KeywordSearch from 'components/KeywordSearch'


const oneStringFacet = [
  { id: 'species', filters: [{ id: 'NCBITaxon_9606', name: 'Homo sapiens' }] }
]

const twoStringFacets = [
  { id: 'disease', filters: [{ id: 'id1', name: 'disease1' }] },
  { id: 'species', filters: [{ id: 'NCBITaxon_9606', name: 'Homo sapiens' }] }
]

const stringAndNumericFacets = [
  {
    id: 'species', filters: [
      { id: 'NCBITaxon_9606', name: 'Homo sapiens' },
      { id: 'NCBITaxon_10090', name: 'Mus musculus' }
    ]
  },
  { id: 'organism_age', filters: { min: 14, max: 180, unit: 'years' } }
]

describe('Search query display text', () => {
  it('renders a single facet', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={oneStringFacet} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (species: Homo sapiens) Clear All')
  })

  it('renders multiple facets', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={twoStringFacets} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (disease: disease1) AND (species: Homo sapiens) Clear All')
  })

  it('renders string and numeric facets', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={stringAndNumericFacets} terms={''}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Metadata contains (species: Homo sapiens OR Mus musculus) AND (organism age: 14 - 180 years) Clear All')
  })

  it('renders terms', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={[]} terms={['foo']}/>
    ))
    expect(wrapper.text().trim()).toEqual(': Text contains (foo) Clear All')
  })

  it('renders terms and a single facet', async () => {
    const wrapper = mount((
      <SearchQueryDisplay facets={oneStringFacet} terms={['foo', 'bar']}/>
    ))
    expect(wrapper.text().trim()).toEqual(': (Text contains (foo OR bar)) AND (Metadata contains (species: Homo sapiens)) Clear All')
  })
})

describe('Clearing search query', () => {
  it('clears search params', () => {
    const component = <PropsStudySearchProvider searchParams={{ terms: 'foo' }}>
      <ClearAllButton/>
      <KeywordSearch/>
    </PropsStudySearchProvider>
    const wrapper = mount(component)
    expect(wrapper.find('input[name="keywordText"]').first().props().value).toEqual('foo')
    wrapper.find(ClearAllButton).simulate('click')
    expect(wrapper.find('input[name="keywordText"]').first().props().value).toEqual('')
  })
})
