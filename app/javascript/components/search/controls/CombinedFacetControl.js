import React, { useContext, useRef, useEffect, useState } from 'react'
import _find from 'lodash/find'

import FacetControl from './FacetControl'
import { SearchFacetContext } from 'providers/SearchFacetProvider'
import FiltersBoxSearchable from './FiltersBoxSearchable'
import { SearchSelectionContext } from 'providers/SearchSelectionProvider'
import useCloseableModal from 'hooks/closeableModal'
/**
 * Component for combining two facets into a single panel control.
 * They will be rendered more or less independently, but with a single 'apply' button
 */
export default function CombinedFacetControl({ controlName, facetNames }) {
  const [showFilters, setShowFilters] = useState(false)
  const facetContext = useContext(SearchFacetContext)
  const selectionContext = useContext(SearchSelectionContext)
  const facetContents = facetNames.map((facetId) => {
    let facet = _find(facetContext.facets, {id: facetId})
    let facetSelection = []
    if (selectionContext.facets[facetId]) {
      facetSelection = selectionContext.facets[facetId]
    }
    return { facet, facetSelection }
  })

  const { node, clearNode, handleButtonClick } = useCloseableModal(showFilters, setShowFilters)

  return (
    <span ref={node} className={`facet ${showFilters ? 'active' : ''}`}>
      <a onClick={handleButtonClick}>
        {controlName}
      </a>
      {
        showFilters && <div className="filters-box-searchable combined-facet">
          <div className="multi-facet-container">
            { facetContents.map((facetContent, index) => {
                return facetContent.facet && <div className="single-facet" key={facetContent.facet.id}>
                  <h4>{facetContent.facet.name}</h4>
                  <FiltersBoxSearchable
                    show={showFilters}
                    facet={facetContent.facet}
                    setShow={ () => {} }
                    selection={facetContent.facetSelection}
                    setSelection={selection =>
                      selectionContext.updateFacet(facetContent.facet.id, selection)
                    }
                    hideApply={ index + 1 < facetNames.length }/>
                </div>
              })
            }
          </div>
        </div>
      }
    </span>
  )
}
