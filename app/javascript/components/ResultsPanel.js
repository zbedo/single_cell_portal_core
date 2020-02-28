import React, { useState, useEffect } from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import Pagination from 'react-bootstrap/lib/Pagination'
import { useTable } from 'react-table'


const ResultsPanel = props => {
  /*
   * const fakeData = React.useMemo(() => [
   *   {
   *     study: 'Title 1',
   *   },
   *   {
   *     study: 'Title 2',
   *   },
   *   {
   *     study: 'Title 3',
   *   },
   * ])
   */
  let displayedResults
  if (props.results.studies.length>0) {
    displayedResults = React.useMemo(() => props.results.studies.map(result => (
      {
        study: <Study
          study={result}
          key={result.accession}
          className='card'
        />,
      }
    ),
    ))
  }
  const column = React.useMemo(() => [{ Header: 'First Name', accessor: 'study' }])
  console.log(props)
  const {
    getTableProps,
    getTableBodyProps,
    rows,
    prepareRow,
  } = useTable({
    columns: column,
    data: displayedResults,
  })
  return (
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

  )


  /*
   * return (
   *   <div id="results-panel">
   *     <Tab.Container id="result-tabs" defaultActiveKey="study">
   *       <Tabs defaultActiveKey='study' animation={false} >
   *         <Tab eventKey='study' title="Studies" >
   *           <Results results={props.results} handlePageTurn={props.handlePageTurn}/>
   *         </Tab>
   *         <Tab eventKey='files' title='Files'/>
   *       </Tabs>
   *     </Tab.Container>
   */

  /*
   *   </div>
   * )
   */
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

const Results = props => {
  const columns = React.useMemo(
    () => [{
      Header: 'Studies',
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
    displayedResults = <p>No Results</p>
  }
  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    rows,
    prepareRow,
  }= useTable(
    {
      columns,
      displayedResults,
    })
  return (<ReactTable
    data={data}
    columns={columns}
  />)
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
