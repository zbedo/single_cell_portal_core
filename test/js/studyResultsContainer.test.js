import React from 'react'
import StudyResultsContainer, { StudyResults } from '../../app/javascript/components/StudyResultsContainer'
import { shallow } from 'enzyme'
import Tab from 'react-bootstrap/lib/Tab'

describe('<StudyResultsContainer/> rendering>', () => {
  it('should render <StudyResultsContainer/> elements', () => {
    const studyResultsContainer = shallow(<StudyResultsContainer/>)
    expect(studyResultsContainer.find(Tab.Container)).toHaveLength(1)
    expect(studyResultsContainer.find(Tab)).toHaveLength(1)
    expect(studyResultsContainer.find(StudyResults)).toHaveLength(1)
  })
})
