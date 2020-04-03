import React from 'react';
import * as ReactAll from 'react';
import { mount } from 'enzyme';
import * as Reach from '@reach/router'

const fetch = require('node-fetch');

import FacetControl from 'components/FacetControl';
import KeywordSearch from 'components/KeywordSearch';
import { PropsStudySearchProvider } from 'providers/StudySearchProvider';
import * as ScpAPI from 'lib/scp-api'

const speciesFacet = {
    name: "Species",
    id: "species",
    type: "string",
    links: [{name: "NCBI Taxonomy", url: "https://foo.tdb"}],
    filters: [
      {id: 'speciesId1', name: 'name 1'},
      {id: 'speciesId2', name: 'name 2'},
      {id: 'speciesId3', name: 'name 3'},
      {id: 'speciesId4', name: 'name 4'},
      {id: 'speciesId5', name: 'name 5'},
      {id: 'speciesId6', name: 'name 6'}
    ],
    links: []
  }

  const diseaseFacet = {
    name: "Disease",
    id: "disease",
    type: "string",
    links: [{name: "NCBI Taxonomy", url: "https://foo.tdb"}],
    filters: [
      {id: 'disease1', name: 'd 1'},
      {id: 'disease2', name: 'd 2'},
      {id: 'disease3', name: 'd 3'},
      {id: 'disease4', name: 'd 4'},
      {id: 'disease5', name: 'd 5'},
      {id: 'disease6', name: 'd 6'}
    ],
    links: []
  }

describe('Apply applies all changes made in the search panel', () => {
  it('applies keyword changes when applying from a facet', async () => {
    const routerNav = jest.spyOn(Reach, 'navigate')

    const wrapper = mount((
      <PropsStudySearchProvider searchParams={{terms: '', facets:{}, page: 1}}>
        <KeywordSearch/>
        <FacetControl facet={speciesFacet}/>
      </PropsStudySearchProvider>
    ))

    let speciesControl = function() {
      return wrapper.find('#facet-species').first()
    }
    let keywordInput = function() {
      return wrapper.find('input[name="keywordText"]').first()
    }

    keywordInput().simulate('change', {target: {value: 'test123'}});
    wrapper.find('#facet-species > a').simulate('click')
    speciesControl().find('input#speciesId5').simulate('change', {target: {checked: true}})
    speciesControl().find('button.facet-apply-button').simulate('click')

    expect(routerNav).toHaveBeenLastCalledWith('?type=study&page=1&terms=test123&facets=species%3AspeciesId5')
  })

  it('applies facet changes when keyword searching', async () => {
    const routerNav = jest.spyOn(Reach, 'navigate')

    const wrapper = mount((
      <PropsStudySearchProvider searchParams={{terms: '', facets:{}, page: 1}}>
        <KeywordSearch/>
        <FacetControl facet={speciesFacet}/>
        <FacetControl facet={diseaseFacet}/>
      </PropsStudySearchProvider>
    ))

    let speciesControl = function() {
      return wrapper.find('#facet-species').first()
    }
    let diseaseControl = function() {
      return wrapper.find('#facet-disease').first()
    }
    let keywordInput = function() {
      return wrapper.find('input[name="keywordText"]').first()
    }

    wrapper.find('#facet-species > a').simulate('click')
    speciesControl().find('input#speciesId2').simulate('change', {target: {checked: true}})
    wrapper.find('#facet-disease > a').simulate('click')
    diseaseControl().find('input#disease4').simulate('change', {target: {checked: true}})
    keywordInput().simulate('change', {target: { value: 'test345'}});
    keywordInput().simulate('submit')

    expect(routerNav).toHaveBeenLastCalledWith('?type=study&page=1&terms=test345&facets=species%3AspeciesId2%2Bdisease%3Adisease4')
  })
})
