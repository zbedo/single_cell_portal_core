import React from 'react'
import FilterSlider from './FilterSlider'

/**
 * Component for a list of checkbox filters, e.g. disease, species
 */
function FilterCheckboxes(props) {
  return (
    <ul className="facet-filter-list">
      {
        props.filters.map(filter => {
          return (
            <li key={`li-${filter.id}`}>
              <input
                type='checkbox'
                aria-label='checkbox'
                onChange={e => {props.onChange(filter.id, e.target.checked)}}
                id={filter.id}
                name={filter.id}
                checked={props.selection.includes(filter.id)}
              />
              <label htmlFor={filter.id}>{filter.name}</label>
            </li>
          )
        })
      }
    </ul>
  )
}

/**
 * Component for filter list and filter slider
 */
export default function Filters(props) {
  const filters = props.filters
  if (props.facet.type !== 'number') {
    return (
      <FilterCheckboxes
        filters={filters}
        onChange={props.updateSelectionForFilterCheckboxes}
        selection={props.selection}
      />
    )
  } else {
    return (
      <FilterSlider
        facet={props.facet}
        onChange={props.updateSelectionForFilterSlider}
        selection={props.selection}
      />
    )
  }
}
