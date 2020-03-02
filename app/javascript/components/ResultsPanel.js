import React, { useState, useEffect, useContext } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import Panel from 'react-bootstrap/lib/Panel'
import Pagination from 'react-bootstrap/lib/Pagination'
import { useTable, usePagination } from 'react-table'

const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
  return (
    <div id="results-panel">
      <Tab.Container id="result-tabs" defaultActiveKey="study">
        <Tabs defaultActiveKey='study' animation={false} >
          <Tab eventKey='study' title="Studies" >
            <StudyResults results={searchContext.results} handlePageTurn={(pageNum) => {searchContext.updateSearch({page: pageNum})}}/>
          </Tab>
          <Tab eventKey='files' title='Files'/>
        </Tabs>
      </Tab.Container>
    </div>
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
  if (props.results.studies && props.results.studies.length>0) {
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
    displayedResults = [{ study: <p>No Results</p> }]
  }
  const {
    getTableProps,
    getTableBodyProps,
    prepareRow,
    rows,
    /*
     * Instead of using 'rows', we'll use page,
     * which has only the rows for the active page
     */

    // The rest of these things are super handy, too ;)
    canPreviousPage,
    canNextPage,
    pageOptions,
    pageCount,
    gotoPage,
    nextPage,
    previousPage,
    setPageSize,
    state: { pageIndex, pageSize },
  } = useTable({
    columns,
    data: displayedResults,
    // holds pagination states
    initialState: {
      pageIndex: props.results.currentPage,
      manualPagination: true,
      pageCount: props.results.totalPages,
      // This will change when there's a way to determine amount of results per page via API endpoint
      pageSize: 5,
    },
  },
  usePagination)
  return (
    <Tab.Content id ='results-content'>
      <table {...getTableProps()}>
        <tbody {...getTableBodyProps()}>
          {rows.map((row, i) => {
            prepareRow(row)
            return (
              <tr {...row.getRowProps()} className='result-row'>
                {row.cells.map(cell => {
                  return <td {...cell.getCellProps()} id='result-cell'>{cell.render('Cell')}</td>
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
      <div className="pagination">
        <button onClick={() => gotoPage(0)} disabled={!canPreviousPage}>
          {'<<'}
        </button>{' '}
        <button onClick={() => previousPage()} disabled={!canPreviousPage}>
          {'<'}
        </button>{' '}
        <button onClick={() => nextPage()} disabled={!canNextPage}>
          {'>'}
        </button>{' '}
        <button onClick={() => gotoPage(pageCount - 1)} disabled={!canNextPage}>
          {'>>'}
        </button>{' '}
        <span>
        Page{' '}
          <strong>
            {pageIndex} of {pageCount}
          </strong>{' '}
        </span>
      </div>
    </Tab.Content>

  )
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
