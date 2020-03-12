import React from 'react';
import * as ReactAll from 'react';
import { mount } from 'enzyme';
import * as Reach from '@reach/router'

const fetch = require('node-fetch');

import MoreFacetsButton from 'components/MoreFacetsButton';
import StudySearchProvider from 'components/search/StudySearchProvider';
import * as ScpAPI from 'lib/scp-api'

const testFacets = [{
    id: 'sex',
    name: 'sex',
    filters: [
      {id: 'male', name: 'male'},
      {id: 'female', name: 'female'}
    ],
    links: []
  },{
    id: 'library_protocol',
    name: 'Protocol',
    filters: [
      {id: 'Seq-Well', name: 'Seq-Well'},
      {id: 'inDrop', name: 'inDrop'},
      {id: '10X 3\' v2 sequencing', name: '10X 3\' v2 sequencing'}
    ],
    links: []
  },{
    name: "organism_age",
    type: "number",
    id: "organism_age",
    links: [],
    filters: [],
    unit: null,
    max: 180,
    min: 1,
    allUnits: ["years", "months", "weeks", "days", "hours"]
  }]

describe('Basic "More Facets" capability for faceted search', () => {
  it('the More Facets Button should correctly render when facets are selected', async () => {
    const routerNav = jest.spyOn(Reach, 'navigate')

    let moreButton = function() {
      return wrapper.find('#more-facets-button').first()
    }
    const wrapper = mount((
      <StudySearchProvider terms={''} facets={{}} page={1}>
        <MoreFacetsButton facets={testFacets}/>
      </StudySearchProvider>
    ))
    expect(moreButton()).toHaveLength(1)
    expect(moreButton().hasClass('active')).toEqual(false)
    wrapper.find('#more-facets-button > a').simulate('click')
    expect(moreButton().hasClass('active')).toEqual(true)

    wrapper.find('#facet-sex > a').simulate('click')
    expect(wrapper.find('#facet-sex button.facet-apply-button').hasClass('disabled')).toEqual(true)

    wrapper.find('#facet-sex input#female').simulate('change', {target: {checked: true}})
    expect(wrapper.find('#facet-sex button.facet-apply-button').hasClass('active')).toEqual(true)

    wrapper.find('#facet-sex button.facet-apply-button').simulate('click')
    expect(routerNav).toHaveBeenLastCalledWith('?type=study&terms=&facets=sex%3Afemale&page=1')
  });

});
