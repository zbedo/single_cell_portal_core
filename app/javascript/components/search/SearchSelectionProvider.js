import React, { useContext, useState } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import _clone from 'lodash/clone'

export const SearchSelectionContext = React.createContext({
  terms: '',
  facets: {},
  updateSelection: undefined,
  performSearch: undefined
})

export default function SearchSelectionProvider(props) {
  const searchContext = useContext(StudySearchContext)
  const appliedSelection = _clone(searchContext.params)
  const [selection, setSelection] = useState(appliedSelection ? appliedSelection : {
    terms: '',
    facets: {}
  })
  selection.updateSelection = updateSelection
  selection.updateFacet = updateFacet
  selection.performSearch = performSearch

  function updateSelection(value) {
    setSelection(Object.assign({}, selection, value))
  }

  function updateFacet(facetId, value, searchNow) {
    let updatedFacet = {}
    updatedFacet[facetId] = value
    let facetObj = Object.assign({}, selection.facets, updatedFacet)
    let newSelection = Object.assign({}, selection)
    newSelection.facets = facetObj
    if (searchNow) {
      searchContext.updateSearch(newSelection)
    }
    setSelection(newSelection)
  }

  function performSearch() {
    searchContext.updateSearch(selection)
  }

  return (
    <SearchSelectionContext.Provider value={selection}>
      { props.children }
    </SearchSelectionContext.Provider>
  )
}
