import React from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import { useTable, usePagination } from 'react-table'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faCaretLeft, faCaretRight, faBackward, faForward } from '@fortawesome/free-solid-svg-icons';

/**
 * Wrapper component for studies on homepage
 */
const StudyResults = ({ results, changePage }) => {
  const columns = React.useMemo(
    () => [{
      accessor: 'study',
    }])

  const data = results.studies.map(result => (
    {
      study: <Study
        study={result}
        key={result.accession}
        className='card'
      />,
    }
  ),
  )

  const {
    getTableProps,
    getTableBodyProps,
    prepareRow,
    rows,
    canPreviousPage,
    canNextPage,
    pageCount,
    gotoPage,
    nextPage,
    previousPage,
    state: { pageIndex, pageSize },
  } = useTable({
    columns,
    data,
    // holds pagination states
    initialState: {
      pageIndex: results.currentPage -1,
      // This will change when there's a way to determine amount of results per page via API endpoint
      pageSize: 5,
    },
    pageCount: results.totalPages,
    manualPagination: true,
  },
  usePagination)
  return (
    <>
      <div className="row">
        <div className="col-md-4">
          { results.totalStudies } total studies found
        </div>
        <div className="col-md-4">
          <PagingControl currentPage={results.currentPage}
                         totalPages={results.totalPages}
                         changePage={changePage}
                         canPreviousPage={canPreviousPage}
                         canNextPage={canNextPage}/>
        </div>
      </div>
      <table {...getTableProps()}>
        <tbody {...getTableBodyProps()}>
          {rows.map((row, i) => {
            prepareRow(row)
            return (
              <tr {...row.getRowProps()} className='result-row'>
                {row.cells.map(cell => {
                  return <td key {...cell.getCellProps()} id='result-cell'>{cell.render('Cell')}</td>
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
      <PagingControl currentPage={results.currentPage}
                     totalPages={results.totalPages}
                     changePage={changePage}
                     canPreviousPage={canPreviousPage}
                     canNextPage={canNextPage}/>
    </>
  )
}
// Taken from https://codesandbox.io/s/github/tannerlinsley/react-table/tree/master/examples/pagination
const PagingControl = ({currentPage, totalPages, changePage, canPreviousPage, canNextPage}) => {
  return (
    <div className="pagination">
      <button
        className="text-button"
        onClick={() => {changePage(1)}}
        disabled={!canPreviousPage}>
        <FontAwesomeIcon icon={faBackward}/>
      </button>
      <button
        className="text-button"
        onClick={() => {changePage(currentPage - 1)}}
        disabled={!canPreviousPage}>
        <FontAwesomeIcon icon={faCaretLeft}/>
      </button>
      <span className="currentPage">
        Page {currentPage} of {totalPages}
      </span>
      <button
        className="text-button"
        onClick={() => {changePage(currentPage + 1)}}
        disabled={!canNextPage}>
        <FontAwesomeIcon icon={faCaretRight}/>
      </button>
      <button
        className="text-button"
        onClick={() => {changePage(totalPages)}}
        disabled={!canNextPage}>
        <FontAwesomeIcon icon={faForward}/>
      </button>
    </div>
  )
}

const Study =props => {
  const studyDescription = { __html: props.study.description }

  return (
    <div key={props.study.accession}>
      <label htmlFor={props.study.name} id= 'result-title'>
        <a href={props.study.study_url}>{props.study.name} </a></label>
      <div>
        <span id='cell-count' className='badge badge-secondary'>{props.study.cell_count} Cells </span>
      </div>
      <span dangerouslySetInnerHTML={studyDescription} id='descrition-text-area' disabled accession = {props.study.name}></span>
    </div>
  )
}
export default StudyResults
