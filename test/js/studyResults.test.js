import React from 'react'
import StudyResultsContainer, { StudiesResults, StudiesList, Study } from '../../app/javascript/components/StudyResultsContainer'
import { shallow } from 'enzyme'
import Tab from 'react-bootstrap/lib/Tab'
import { useTable, usePagination } from 'react-table'

const fetch = require('node-fetch')
describe('<StudyResultsContainer/> rendering>', () => {
  let studyResultsContainer
  beforeAll(() => {
    studyResultsContainer = shallow(<StudyResultsContainer/>)
  })

  it('should render 1 <StudiesResults/>', () => {
    expect(studyResultsContainer.find(StudiesResults)).toHaveLength(1)
  })
})

// describe('<StudiesList/> returning data correctly', () => {
//   const studyMock = jest.mock(Study, () => {
//     return <div/>
//   })
//   const mockList = { studies: [1, 2, 3, 4, 5] }
//   const studiesList = shallow(<StudiesList studies={mockList}/>)
//   it('should return list of 5 {study: <Study/>', () => {
//     expect(studiesList).toHaveLength(5)
//   })
// })
