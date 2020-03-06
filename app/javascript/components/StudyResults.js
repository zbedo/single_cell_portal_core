import React from 'react'
import Tab from 'react-bootstrap/lib/Tab'
import Tabs from 'react-bootstrap/lib/Tabs'
import { useTable, usePagination } from 'react-table'

/**
 * Wrapper component for studies tab on homepage
 */
export default function StudyResultsContainer(props) {
  const studies = <StudiesList studies={props.results}/>
  console.log('foo')
  return (
    <Tab.Container id="result-tabs" defaultActiveKey="study">
      <Tabs defaultActiveKey='study' animation={false} >
        <Tab eventKey='study' title="Studies" >
          <StudiesResults changePage ={props.handlePageTurn} data= {studies}/>
        </Tab>
        <Tab eventKey='files' title='Files'></Tab>
      </Tabs>
    </Tab.Container>
  )
}

const StudiesList = studies => {
  studies.studies.map(result => (
    {
      study: <Study
        study={result}
        key={result.accession}
        className='card'
      />,
    }
  ),
  )
}

/**
 * Component for the content of the 'Studies' tab
 */
export function StudiesResults({ studies, changePage }) {
  const columns = React.useMemo(
    () => [{
      accessor: 'study',
    }])
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
      pageIndex: studies.currentPage -1,
      // This will change when there's a way to determine amount of results per page via API endpoint
      pageSize: 5,
    },
    pageCount: studies.totalPages,
    manualPagination: true,
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
                  return <td key {...cell.getCellProps()} id='result-cell'>{cell.render('Cell')}</td>
                })}
              </tr>
            )
          })}
        </tbody>
      </table>
      {
        // Taken from https://codesandbox.io/s/github/tannerlinsley/react-table/tree/master/examples/pagination
      }
      <div className="pagination">
        <button
          onClick={() => {gotoPage(0); changePage(1)}}
          disabled={!canPreviousPage}>
          {'<<'}
        </button>{' '}
        <button
          onClick={() => {previousPage(); changePage(studies.currentPage-1)}}
          disabled={!canPreviousPage}>
          {'<'}
        </button>{' '}
        <button
          onClick={() => {nextPage(); changePage(studies.currentPage+1)}}
          disabled={!canNextPage}>
          {'>'}
        </button>{' '}
        <button
          onClick={() => {gotoPage(pageCount); changePage(studies.totalPages)}}
          disabled={!canNextPage}>
          {'>>'}
        </button>{' '}
        <span>
          Page{' '}
          <strong>
            {studies.currentPage} of {studies.totalPages}
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
        <span id='cell-count' className='badge badge-secondary'>{props.study.cell_count} Cells </span>
      </div>
      <span dangerouslySetInnerHTML={studyDescription} id='descrition-text-area' disabled accession = {props.study.name}></span>
    </div>
  )
}
