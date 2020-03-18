import React from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import { useTable, usePagination } from 'react-table'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import {
  faAngleDoubleLeft, faAngleLeft, faAngleRight, faAngleDoubleRight
} from '@fortawesome/free-solid-svg-icons'
import Study from './Study'
import PagingControl from './PagingControl'
/**
 * Wrapper component for studies on homepage
 */
export default function StudyResultsContainer(props) {
  // const studies = <StudiesList studies={props.results}/>
  return (
    <Tab.Container id="result-tabs" defaultActiveKey="study">
      <Tabs defaultActiveKey='study' animation={false} >
        <Tab eventKey='study' title="Studies" >
          <StudiesResults changePage ={props.changePage} results={props.results}/>
        </Tab>
        <Tab eventKey='files' title='Files'></Tab>
      </Tabs>
    </Tab.Container>
  )
}

export const StudiesList = ({ studies }) => {
  return studies.studies.map(result => (
    {
      study: <Study
        study={result}
        key={result.accession}
        className='card'
      />
    }
  )
  )
}

/**
 * Component for the content of the 'Studies' tab
 */
export function StudiesResults(props) {
  const { results, changePage } = props
  const columns = React.useMemo(
    () => [{
      accessor: 'study'
    }])
  const data = results.studies.map(result => (
    {
      study: <Study
        terms={results.terms}
        facets = {results.facets}
        study={result}
        key={result.accession}
      />
    }
  )
  )
  const {
    getTableProps,
    getTableBodyProps,
    prepareRow,
    rows,
    canPreviousPage,
    canNextPage
  } = useTable({
    columns,
    data,
    // holds pagination states
    initialState: {
      pageIndex: results.currentPage -1,
      // This will change when there's a way to determine amount of results
      // per page via API endpoint
      pageSize: 5
    },
    pageCount: results.totalPages,
    manualPagination: true
  },
  usePagination)
  return (
    <>
      <div className="row results-header">
        <div className="col-md-4 results-totals">
          <strong>{ results.totalStudies }</strong> total studies found
        </div>
        <div className="col-md-4">
          <PagingControl
            currentPage={results.currentPage}
            totalPages={results.totalPages}
            changePage={changePage}
            canPreviousPage={canPreviousPage}
            canNextPage={canNextPage}
          />
        </div>
      </div>
      <table {...getTableProps()}>
        <tbody {...getTableBodyProps()}>
          {rows.map((row, i) => {
            prepareRow(row)
            return (
              <tr {...row.getRowProps()} className='result-row'>
                {row.cells.map(cell => {
                  return <td key {...cell.getCellProps()} id='result-cell'>{cell.render('Cell')}</td> // eslint-disable-line max-len
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
      <PagingControl
        currentPage={results.currentPage}
        totalPages={results.totalPages}
        changePage={changePage}
        canPreviousPage={canPreviousPage}
        canNextPage={canNextPage}
      />
    </>
  )
}
