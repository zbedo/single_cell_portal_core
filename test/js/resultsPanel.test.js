import React from 'react'
import StudyResultsContainer from
  '../../app/javascript/components/StudyResultsContainer'
import { StudySearchContext } from
  '../../app/javascript/components/search/StudySearchProvider'
import ResultsPanel from '../../app/javascript/components/ResultsPanel'
import { mount } from 'enzyme'

describe('<StudyResultsContainer/> rendering>', () => {
  it('should render error panel', () => {
    const resultsPanel = mount(
      <StudySearchContext.Provider value={{ isError: true }}>
        <ResultsPanel/>
      </StudySearchContext.Provider>)
    const panel = resultsPanel.find('.error-panel')
    expect(panel).toHaveLength(1)
  })
  it('should render loading-panel', () => {
    const resultsPanel = mount(
      <StudySearchContext.Provider value={
        {
          isError: false,
          isLoaded: false
        }}>
        <ResultsPanel/>
      </StudySearchContext.Provider>)
    const panel = resultsPanel.find('.loading-panel')
    expect(panel).toHaveLength(1)
  })
  it('should render 1 <StudyResultsContainer/>', () => {
    const resultsPanel = mount(
      <StudySearchContext.Provider value={
        {
          isError: false,
          isLoaded: true,
          results: { studies: ['SCP1', 'SCP2'] }
        }}>
        <ResultsPanel/>
      </StudySearchContext.Provider>)

    expect(resultsPanel.find(StudyResultsContainer)).toHaveLength(1)
  })
})
