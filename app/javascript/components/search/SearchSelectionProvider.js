import React, { useContext, useState, useEffect } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import _clone from 'lodash/clone'

/** The currently selected state of the search panel */
export const SearchSelectionContext = React.createContext({
  terms: '',
  facets: {},
  updateSelection: undefined,
  performSearch: undefined
})

/** Renders its children within a SearchSelectionContext provider */
export default function SearchSelectionProvider(props) {
  const searchContext = useContext(StudySearchContext)
  const appliedSelection = _clone(searchContext.params)
  const [selection, setSelection] = useState(
    appliedSelection ?
      appliedSelection :
      { terms: '', facets: {} })
  selection.updateSelection = updateSelection
  selection.updateFacet = updateFacet
  selection.performSearch = performSearch

  /** merges the update into the current selection */
  function updateSelection(value, searchNow) {
    const newSelection = Object.assign({}, selection, value)
    if (searchNow) {
      searchContext.updateSearch(newSelection)
    }
    setSelection(newSelection)
  }

  /** merges the facet update into the current selection */
  function updateFacet(facetId, value, searchNow) {
    const updatedFacet = {}
    updatedFacet[facetId] = value
    const facetObj = Object.assign({}, selection.facets, updatedFacet)
    const newSelection = Object.assign({}, selection)
    newSelection.facets = facetObj
    if (searchNow) {
      searchContext.updateSearch(newSelection)
    }
    setSelection(newSelection)
    setSelection(newSelection)
  }
  /** execute the search on the server */
  function performSearch() {
    searchContext.updateSearch(selection)
  }


  return (
    <SearchSelectionContext.Provider value={selection}>
      { props.children }
    </SearchSelectionContext.Provider>
  )
}
