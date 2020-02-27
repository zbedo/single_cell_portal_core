import React, { useState, useEffect, useRef } from 'react';
import FiltersBox from './FiltersBox';

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

  function handleButtonClick() {
    setShowFilters(!showFilters);
  }
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

  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return;
    }
    setShowFilters(false)
  };

  return (
      <span ref={node}
        id={facetId}
        className={`facet ${showFilters ? 'active' : ''}`}>
        <a
          onClick={handleButtonClick}>
          {facetName}
        </a>
        <FiltersBox show={showFilters} facet={props.facet} />
      </span>
    );

}
