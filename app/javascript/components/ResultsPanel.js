import React, { useState, useEffect } from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import Panel from 'react-bootstrap/lib/Panel'
import Pagination from 'react-bootstrap/lib/Pagination'
import { useTable } from 'react-table'


const ResultsPanel = props => {
  return (
    <Panel id="results-panel">
      <Tab.Container id="result-tabs" defaultActiveKey="study">
        <Tabs defaultActiveKey='study' animation={false} >
          <Tab eventKey='study' title="Studies" >
            <StudyResults results={props.results} handlePageTurn={props.handlePageTurn}/>
          </Tab>
          <Tab eventKey='files' title='Files'/>
        </Tabs>
      </Tab.Container>
    </Panel>
  )
}

const ResultsPagination = props => {
  const [activePageIndex, setActivePage] = useState(1)
  const amountOfPages = 0
  const pageItems = []

  const turnPage = pageIndex => {
    setActivePage(pageIndex)
    props.handlePageTurn(pageIndex)
  }

  for (let pageIndex =1; pageIndex <= props.totalPages; pageIndex++) {
    pageItems.push(
      <Pagination.Item key={pageIndex} active={pageIndex === activePageIndex} onClick= {() => turnPage(pageIndex)}>
        {pageIndex}
      </Pagination.Item>,
    )
  }


  return (
    <Pagination>
      <Pagination.First key={1} onClick= {() => turnPage(pageIndex)} />
      <Pagination.Prev onClick= {() => turnPage(pageIndex)}/>
      {pageItems}
      <Pagination.Next onClick= {() => turnPage(pageIndex)} />
      <Pagination.Last onClick= {() => turnPage(pageIndex)} />
    </Pagination>

  )
}

const StudyResults = props => {
  const columns = React.useMemo(
    () => [{
      accessor: 'study',
    }])
  let displayedResults
  if (props.results.studies.length>0) {
    displayedResults = props.results.studies.map(result => (
      {
        study: <Study
          study={result}
          key={result.accession}
          className='card'
        />,
      }
    ),
    )
  } else {
    displayedResults = { study: <p>No Results</p> }
  }
  const {
    getTableProps,
    getTableBodyProps,
    rows,
    prepareRow,
  } = useTable({
    columns,
    data: displayedResults,
  })
  return (
    <Tab.Content id ='results-content'>
      <table {...getTableProps()}>
        <tbody {...getTableBodyProps()}>
          {rows.map((row, i) => {
            prepareRow(row)
            return (
              <tr {...row.getRowProps()}>
                {row.cells.map(cell => {
                  return <td {...cell.getCellProps()}>{cell.render('Cell')}</td>
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
    </Tab.Content>

  )
  /*
   * return (
   *   <Tab.Content id ='results-content'>
   *     {displayedResults}
   *     <ResultsPagination totalPages = {props.results.totalPages} handlePageTurn={props.handlePageTurn}/>
   *   </Tab.Content>)
   */
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
