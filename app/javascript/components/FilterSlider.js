import React from 'react'
import { Slider, Rail, Handles, Tracks, Ticks } from 'react-compound-slider'

import { Handle, Track, Tick } from './slider/components'
import _clone from 'lodash/clone'

const sliderStyle = {
  margin: '5%',
  position: 'relative',
  width: '90%'
}

const railStyle = {
  position: 'absolute',
  width: '100%',
  height: 14,
  borderRadius: 7,
  cursor: 'pointer',
  backgroundColor: 'rgb(155,155,155)'
}

/**
 * Component for slider to filter numerical facets, e.g. organism age
 *
 * TODO (SCP-2201):
 * - Support unit-less numerical facets, e.g. bmi, number_of_reads
 * - Support rate units, e.g. small_molecule_perturbation__concentration
 */
 /*
  * props.selection should be an array of [min,max,unit]
  */
export default function FilterSlider(props) {
  const facet = props.facet

  const [min, max] = [parseInt(facet.min), parseInt(facet.max)]
  const domain = [min, max]



  let propsSelection = _clone(props.selection)
  // propsRange indicates the current numeric range for the slider
  // it will always be numeric even if the text values are not (e.g. a text box is blank)
  let propsRange = []
  let propsUnit = ''
  let minTextValue = propsSelection[0]
  let maxTextValue = propsSelection[1]

  if (propsSelection && propsSelection.length === 3) {
    propsRange = propsSelection.slice(0, 2)
    propsRange = propsRange.map((value, index) => {
      const intVal = parseInt(value)
      // convert blanks to min/max as appropriate so the slider can still render
      if (isNaN(intVal) ) {
        return domain[index]
      }
      return intVal
    })
    propsUnit = propsSelection[2]
  } else {
    propsRange = domain.slice()
    minTextValue = min
    maxTextValue = max
    propsUnit = facet.unit
  }


  function handleUpdate(update) {
    if ('min' in update) {
      propsRange[0] = update.min
    }
    if ('max' in update) {
      propsRange[1] = update.max
    }
    if ('unit' in update) {
      propsUnit = update.unit
    }
    props.setSelection([propsRange[0], propsRange[1], propsUnit])
  }

  let unitControl = ''
  if (facet.allUnits && facet.allUnits.length) {
    const units = facet.allUnits
    const unit = propsUnit ? propsUnit : facet.allUnits[0]
    unitControl = (
        <select value={unit}
                onChange={event => handleUpdate({unit: event.target.value})}>
          {units.map((unit, i) =>
            <option key={i}>{unit}</option>
          )}
        </select>
      )
  }

  return (
    <>
      <input
        id='input-min-organism-age'
        onChange={event => handleUpdate({min: event.target.value})}
        type="number"
        min={min}
        max={max}
        value={minTextValue}
        style={{ 'width': '60px' }}
      />
      <span style={{ 'margin': '0 4px 0 4px' }}>-</span>
      <input
        id='input-max-organism-age'
        onChange={event => handleUpdate({max: event.target.value})}
        type='number'
        min={min}
        max={max}
        value={maxTextValue}
        style={{ 'width': '60px', 'marginRight': '8px' }}
      />
      { unitControl }
      <div style={{ height: 60, width: '100%' }}>
        <Slider
          mode={1}
          step={1}
          domain={domain}
          rootStyle={sliderStyle}
          onChange={newValues =>
            handleUpdate({min: newValues[0], max: newValues[1]})
          }
          values={propsRange}
        >
          <Rail>
            {({ getRailProps }) => (
              <div style={railStyle} {...getRailProps()} />
            )}
          </Rail>
          <Handles>
            {({ handles, getHandleProps }) => (
              <div className='slider-handles'>
                {handles.map(handle => (
                  <Handle
                    key={handle.id}
                    handle={handle}
                    domain={domain}
                    getHandleProps={getHandleProps}
                  />
                ))}
              </div>
            )}
          </Handles>
          <Tracks left={false} right={false}>
            {({ tracks, getTrackProps }) => (
              <div className='slider-tracks'>
                {tracks.map(({ id, source, target }) => (
                  <Track
                    key={id}
                    source={source}
                    target={target}
                    getTrackProps={getTrackProps}
                  />
                ))}
              </div>
            )}
          </Tracks>
          <Ticks count={6}>
            {({ ticks }) => (
              <div className='slider-ticks'>
                {ticks.map(tick => (
                  <Tick key={tick.id} tick={tick} count={ticks.length} />
                ))}
              </div>
            )}
          </Ticks>
        </Slider>
      </div>
    </>
  )
}
