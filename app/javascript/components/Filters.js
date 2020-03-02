import React from 'react';
import { Slider, Rail, Handles, Tracks, Ticks } from "react-compound-slider";

/**
 * Component for a list of string-based filters, e.g. disease, species
 */
function FilterList(props) {
  return (
    <ul>
    {
      props.filters.map((filter) => {
        return (
          <li key={'li-' + filter.id}>
            <input
              type='checkbox'
              aria-label='checkbox'
              onChange={(e) => {props.onChange(filter.id, e.target.checked)}}
              id={filter.id}
              name={filter.id}
              checked={props.selection.includes(filter.id)}
            />
            <label htmlFor={filter.id}>{filter.name}</label>
          </li>
        );
      })
    }
    </ul>
  );
}

/**
 * Component for slider to filter numerical facets, e.g. organism age
 *
 * Stub, will develop.
 */
function FilterSlider(props) {
  const facet = props.facet;

  // React Compound Slider
  // API: https://react-compound-slider.netlify.com/docs
  // Examples: https://react-compound-slider.netlify.com/horizontal
  return (
    <li>
      <Slider
        domain={[facet.min, facet.max]}
      />
    </li>
  );
}

/**
 * Component for filter list and filter slider
 */
export default function Filters(props) {
  const filters = props.filters;
  if (props.facet.type !== 'number') {
    return <FilterList filters={filters} onChange={props.onFilterValueChange} selection={props.selection} />;
  } else {
    return <FilterSlider facet={props.facet} />;
  }
}
