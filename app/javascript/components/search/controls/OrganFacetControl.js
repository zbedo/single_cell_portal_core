import React, { useContext, useRef, useEffect, useState } from 'react'
import _find from 'lodash/find'

import FacetControl from './FacetControl'
import { SearchFacetContext } from 'providers/SearchFacetProvider'
import FiltersBoxSearchable from './FiltersBoxSearchable'
import { SearchSelectionContext } from 'providers/SearchSelectionProvider'

/**
 * Component for filter search and filter lists
 */
export default function OrganFacetFilter() {
  const [showFilters, setShowFilters] = useState(false)
  const facetContext = useContext(SearchFacetContext)
  const selectionContext = useContext(SearchSelectionContext)
  const facetContents = ['organ', 'organ_region', 'cell_type', 'organ_cell_type'].map((facetId) => {
    let facet = _find(facetContext.facets, {id: facetId})
    let facetSelection = []
    if (selectionContext.facets[facetId]) {
      facetSelection = selectionContext.facets[facetId]
    }
    return { facet, facetSelection }
  })


  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return
    }
    setShowFilters(false)
  }
  const clearNode = useRef()
  function handleButtonClick(e) {
    if (clearNode.current && clearNode.current.contains(e.target)) {
      setShowFilters(false)
    } else {
      setShowFilters(!showFilters)
    }
  }

  // add event listener to detect clicks outside the modal,
  // so we know to close it
  // see https://medium.com/@pitipatdop/little-neat-trick-to-capture-click-outside-with-react-hook-ba77c37c7e82
  useEffect(() => {
    // add when mounted
    document.addEventListener('mousedown', handleOtherClick)
    // return function to be called when unmounted
    return () => {
      document.removeEventListener('mousedown', handleOtherClick)
    }
  }, [])
  return (
    <span ref={node} className={`facet`}>
      <a onClick={handleButtonClick}>
        tissue
      </a>
      {
        showFilters && <div className="filters-box-searchable organ-facet">
          <div className="multi-facet-container">
            { facetContents.map((facetContent) => {
                return facetContent.facet && <div className="single-facet" key={facetContent.facet.id}>
                  <h4>{facetContent.facet.name}</h4>
                  <FiltersBoxSearchable
                    show={showFilters}
                    facet={facetContent.facet}
                    setShow={true}
                    selection={facetContent.facetSelection}
                    setSelection={selection =>
                      selectionContext.updateFacet(facetContent.facet.id, selection)
                    }/>
                </div>
              })
            }
          </div>
        </div>
      }
    </span>
  )
}
