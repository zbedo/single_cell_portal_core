import React, { useState, useEffect } from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import Pagination from 'react-bootstrap/lib/Pagination'

const ResultsPanel = props => {
  return (
    <div id="results-panel">
      <Tab.Container id="result-tabs" defaultActiveKey="study">
        <Tabs defaultActiveKey='study' animation={false} >
          <Tab eventKey='study' title="Studies" >
            <StudyResults results={props.results}/>
          </Tab>
          <Tab eventKey='files' title='Files'/>
        </Tabs>
      </Tab.Container>

    </div>
  )
}

const ResultsPagination = props => {
  const [activePage, setActivePage] = useState(1)
  const pageItems = []
  for (let pageIndex =1; pageIndex <= props.totalPages; pageIndex++) {
    pageItems.push(
      <Pagination.Item key={pageIndex} active={pageIndex === activePage}>
        {pageIndex}
      </Pagination.Item>,
    )
  }


  return (
    <Pagination>
      {pageItems}
    </Pagination>
  )
}

const StudyResults = props => {
  let displayedResults
  if (props.results.studies.length>0) {
    displayedResults = props.results.studies.map(result => (
      <Study
        study={result}
        handleStudyLabel = {props.handleStudyLabel}
        key={result.accession}
        className='card'
      />
    ),
    )
  } else {
    displayedResults = <p>No Results</p>
  }

  return (
    <Tab.Content id ='results-content'>
      {displayedResults}
      <ResultsPagination totalPages = {props.results.totalPages}/>
    </Tab.Content>)
}

const Study =props => {
  const studyDescription = { __html: props.study.description }

  return (
    <div key={props.study.accession}>
      <label htmlFor={props.study.name} id= 'result-title'>
        <a href={props.study.study_url}>{props.study.name} </a></label>
      <div>
        <span id = 'cell-count'className="badge badge-secondary">{props.study.cell_count} Cells </span>
      </div>

      <span dangerouslySetInnerHTML={studyDescription} id='descrition-text-area' disabled accession = {props.study.name}></span>
    </div>
  )
}

export default ResultsPanel
