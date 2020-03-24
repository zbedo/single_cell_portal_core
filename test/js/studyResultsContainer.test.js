import React from 'react'
import { StudyResults } from '../../app/javascript/components/StudyResultsContainer'
import PagingControl from '../../app/javascript/components/PagingControl'
import Study from '../../app/javascript/components/Study'
import { mount } from 'enzyme'

describe('<StudyResults/> rendering>', () => {
  const props = {
    changePage: jest.fn(),
    results: {
      currentPage: 1,
      totalPages: 4,
      studies: [{
        'accession': 'SCP1',
        'name': 'Study: Single nucleus RNA-seq of ',
        'cell_count': 0,
        'gene_count': 0,
        'study_url': '/single_cell/study/SCP1/study-single-nucleus'
      }]
    }
  }
  it('should render <StudyResults/> elements', () => {
    const wrapper = mount(<StudyResults changePage ={props.changePage} results={props.results}/>)
    expect(wrapper.find(PagingControl)).toHaveLength(2)
    expect(wrapper.find(Study)).toHaveLength(1)
  })
})
