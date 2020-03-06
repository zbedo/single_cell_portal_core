import React from 'react'
import StudyResultsContainer, { StudiesResults } from '../../app/javascript/components/StudyResults'
import { shallow, mount } from 'enzyme'
import Tab from 'react-bootstrap/lib/Tab'
import { useTable, usePagination } from 'react-table'

const fetch = require('node-fetch')
let studyResultsContainer
describe('<StudyResultsContainer/> rendering>', () => {
  beforeAll(() => {
    studyResultsContainer = shallow(<StudyResultsContainer/>)
  })

  it('should render 1 <Tab.container/>', () => {
    expect(studyResultsContainer.find(Tab.Container)).toHaveLength(1)
  })

  it('should render 2 <Tab/>s', () => {
    expect(studyResultsContainer.find(Tab)).toHaveLength(2)
  })
  it('should render 1 <StudiesResults/>', () => {
    expect(studyResultsContainer.find(StudiesResults)).toHaveLength(1)
  })
})
