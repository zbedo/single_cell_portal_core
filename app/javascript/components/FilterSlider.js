import React, { useState } from 'react';
import { Slider, Rail, Handles, Tracks, Ticks } from "react-compound-slider";

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
 */
export default function FilterSlider(props) {

  const facet = props.facet

  const domain = [parseInt(facet.min), parseInt(facet.max)]

  const units = facet.all_units.slice()

  let [propsRange, propsUnit] = [domain, facet.unit]
  if (props.selection !== '') {
    [propsRange, propsUnit] = props.selection
    propsRange = propsRange.split('-').map(value => parseInt(value))
  }

  const [values, setValues] = useState(propsRange)
  const [inputValues, setInputValues] = useState(propsRange)
  const [unit, setUnit] = useState(propsUnit)

  function updateValues(values) {
    setValues(values)
    setInputValues(values)
    const ranges = values.join('-') + ',' + propsUnit.toLowerCase()
    props.onChange(ranges)
  }

  function onChange(values) {
    updateValues(values)
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
        id="input-min-organism-age"
        onChange={(event) => onNumberInputChange(event)}
        type="number"
        min={domain[0]}
        max={domain[1]}
        value={inputValues[0]}
        style={{'width': '60px'}}
      />
      <span style={{'margin': '0 4px 0 4px'}}>-</span>
      <input
        id="input-max-organism-age"
        onChange={(event) => onNumberInputChange(event)}
        type="number"
        min={domain[0]}
        max={domain[1]}
        value={inputValues[1]}
        style={{'width': '60px', 'marginRight': '8px'}}
      />
      <select onChange={(event) => {setUnit(event.target.value)}}>
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
          onChange={onChange}
          values={values}
        >
          <Rail>
            {({ getRailProps }) => (
              <div style={railStyle} {...getRailProps()} />
            )}
          </Rail>
          <Handles>
            {({ handles, getHandleProps }) => (
              <div className="slider-handles">
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
              <div className="slider-tracks">
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
              <div className="slider-ticks">
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
