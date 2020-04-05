import React from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import { useTable, usePagination } from 'react-table'
import PagingControl from './PagingControl'
/**
 * Wrapper component for studies on homepage
 */
export default function StudyResultsContainer(props) {
  return (
    <Tab.Container id="result-tabs" defaultActiveKey="study">
      <Tabs defaultActiveKey='study' animation={false} >
        <Tab eventKey='study' title="Studies" >
          <StudyResults changePage ={props.changePage} results={props.results} />
        </Tab>
      </Tabs>
    </Tab.Container>
  )
}


/**
 * Component for the content of the 'Studies' tab
 */
export function StudyResults({ results, changePage, StudyComponent }) {
  const columns = React.useMemo(
    () => [{
      accessor: 'study'
    }])

  // convert to an array of objects with a 'study' property for react-table
  const data = results.studies.map(study => {return { study }})

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

  let pageControlDisplay = <></>
  if (results.totalPages > 1) {
    pageControlDisplay = <PagingControl currentPage={results.currentPage}
      totalPages={results.totalPages}
      changePage={changePage}
      canPreviousPage={canPreviousPage}
      canNextPage={canNextPage}/>
  }

  function getRowProps(row) {
    const studyClass = row.values.study.inferred_match ? 'inferred-match result-row' : 'result-row'
    return { className: studyClass }
  }
  return (
    <>
      <div className="row results-header">
        <div className="col-md-4 results-totals">
          <strong>{ results.totalStudies }</strong> total studies found
        </div>
        <div className="col-md-4">
          { pageControlDisplay }
        </div>
      </div>
      <table {...getTableProps({ className: 'result-table' }) }>
        <tbody {...getTableBodyProps()}>
          {rows.map((row, i) => {
            prepareRow(row)
            return (
              <tr {...row.getRowProps(getRowProps(row))}>
                {row.cells.map(cell => {
                  return (
                    <td key {...cell.getCellProps()}>
                      <StudyComponent study={ cell.value }/>
                    </td>
                  )
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
      { pageControlDisplay }
    </>
  )
}
