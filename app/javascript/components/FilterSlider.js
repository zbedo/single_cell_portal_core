import React, { useState } from 'react';
import { Slider, Rail, Handles, Tracks, Ticks } from 'react-compound-slider';

import { Handle, Track, Tick } from './slider/components';

const sliderStyle = {
  margin: '5%',
  position: 'relative',
  width: '90%'
};

const railStyle = {
  position: 'absolute',
  width: '100%',
  height: 14,
  borderRadius: 7,
  cursor: 'pointer',
  backgroundColor: 'rgb(155,155,155)'
};

/**
 * Component for slider to filter numerical facets, e.g. organism age
 *
 * TODO:
 * - Support unit-less numerical facets, e.g. bmi, number_of_reads (SCP-2201)
 * - Support rate units, e.g. small_molecule_perturbation__concentration (SCP-2201)
 */
export default function FilterSlider(props) {

  const facet = props.facet

  const [min, max] = [parseInt(facet.min), parseInt(facet.max)]
  const domain = [min, max]

  const units = facet.all_units.slice()

  let propsRange = ''
  let propsUnit = ''

  if (props.selection.length > 0) {
    // If filling with pre-selected values, e.g. reloading page with previous
    // selection in URL, or from "Apply" button click
    let rangeAndUnit = props.selection;
    propsRange = rangeAndUnit.slice(0, 2)
    propsUnit = rangeAndUnit.slice(-1)[0]
    propsRange = propsRange.map(value => parseInt(value))
  } else {
    // If freshly loading
    propsRange = domain.slice()
    propsUnit = facet.unit
  }

  const [values, setValues] = useState(propsRange)
  const [inputValues, setInputValues] = useState(propsRange)
  const [unit, setUnit] = useState(propsUnit)

  /**
   * Propagates changes upstream, so results get filtered and URL updates
   * upon clicking "Apply"
   */
  function updateAppliedSelection(values, unit) {
    const ranges = values.join(',') + ',' + unit
    props.onChange(ranges)
  }

  function updateValues(values) {
    setValues(values)
    setInputValues(values)
    updateAppliedSelection(values, unit)
  }

  function updateUnit(unit) {
    setUnit(unit)
    updateAppliedSelection(values, unit)
  }

  /**
   * Changes slider value upon changing the number input control value.
   */
  function onNumberInputChange(event) {
    const target = event.target;
    const rawValue = target.value;
    const float = parseFloat(rawValue);
    const index = target.id.includes('min') ? 0 : 1;
    let changedValues = values.slice();
    let changedInputValues = values.slice();

    let value = float;
    if (isNaN(float)) value = changedValues[index]; // ignore invalid input

    changedValues[index] = value;
    changedInputValues[index] = rawValue;

    updateValues(values)
  }

  return (
    <>
      <input
        id='input-min-organism-age'
        onChange={(event) => onNumberInputChange(event)}
        type="number"
        min={min}
        max={max}
        value={inputValues[0]}
        style={{'width': '60px'}}
      />
      <span style={{'margin': '0 4px 0 4px'}}>-</span>
      <input
        id='input-max-organism-age'
        onChange={(event) => onNumberInputChange(event)}
        type='number'
        min={min}
        max={max}
        value={inputValues[1]}
        style={{'width': '60px', 'marginRight': '8px'}}
      />
      <select onChange={(event) => {updateUnit(event.target.value)}}>
        {units.map((unit, i) =>
          <option key={i}>{unit}</option>
        )}
      </select>
      <div style={{ height: 120, width: '100%' }}>
        <Slider
          mode={1}
          step={1}
          domain={domain}
          rootStyle={sliderStyle}
          onChange={updateValues}
          values={values}
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
  );

}
