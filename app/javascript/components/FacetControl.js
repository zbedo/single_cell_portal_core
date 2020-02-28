
import React, { useState, useEffect, useRef, useContext } from 'react';
import FiltersBoxSearchable from './FiltersBoxSearchable';
import { StudySearchContext } from 'components/search/StudySearchProvider';
import _filter from 'lodash/filter'

/**
 * Converts string value to lowercase, hyphen-delimited version
 * e.g. "Cell type" -> "cell-type"
 */
function slug(value) {
  return value.toLowerCase().replace(/ /g, '-');
}

export default function FacetControl(props) {

  const [showFilters, setShowFilters] = useState(false);

  const facetName = props.facet.name;
  const facetId = `facet-${slug(facetName)}`;
  const searchContext = useContext(StudySearchContext)
  const facetParams = searchContext.params.facets[props.facet.id]
  var selectedFilterString
  if (facetParams && facetParams.length) {
    let selectedFilters = props.facet.filters.filter(filter => { return facetParams.indexOf(filter.id) >= 0})
    selectedFilterString = selectedFilters.map(filter => filter.name).join(', ')
  }

  function handleButtonClick() {
    setShowFilters(!showFilters);
  }


  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return;
    }
    setShowFilters(false)
  };

  // add event listener to detect mouseclicks outside the modal, so we know to close it
  // see https://medium.com/@pitipatdop/little-neat-trick-to-capture-click-outside-with-react-hook-ba77c37c7e82
  useEffect(() => {
    // add when mounted
    document.addEventListener("mousedown", handleOtherClick);
    // return function to be called when unmounted
    return () => {
      document.removeEventListener("mousedown", handleOtherClick);
    };
  }, []);

  return (
      <span ref={node}
        id={facetId}
        className={`facet ${showFilters ? 'active' : ''} ${selectedFilterString ? 'selected' : ''}`}>
        <a
          onClick={handleButtonClick}>
          { selectedFilterString ? selectedFilterString : facetName }
        </a>
        <FiltersBoxSearchable show={showFilters} facet={props.facet} setShow={setShowFilters}/>
      </span>
    );

}
