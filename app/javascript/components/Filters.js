import React from 'react';
import { Slider, Rail, Handles, Tracks, Ticks } from "react-compound-slider";
import { Handle, Track, Tick } from './slider/components';

/**
 * Component for a list of string-based filters, e.g. disease, species
 */
function FilterList(props) {
  if (typeof props.filters === 'undefined') return (<></>); // TODO: Remove this once /search/facets response is fixed
  return (
    <ul>
    {
      props.filters.map((filter) => {
        return (
          <li key={'li-' + filter.id}>
            <input
              type='checkbox'
              aria-label='checkbox'
              onClick={props.onClick}
              id={filter.id}
              name={filter.id}
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
// function FilterSlider(props) {
//   const facet = props.facet;

//   const sliderStyle = {
//     position: "relative",
//     width: "100%",
//   };

//   console.log('FacetSlider facet:')
//   console.log(facet)
//   // React Compound Slider
//   // API: https://react-compound-slider.netlify.com/docs
//   // Examples: https://react-compound-slider.netlify.com/horizontal
//   return (
//     <li>
//       <Slider
//         mode={2}
//         domain={[facet.min, facet.max]}
//         rootStyle={sliderStyle}
//         values={[0, 43, 86, 130]}
//       />
//     </li>
//   );
// }

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

const domain = [0, 130];

class FilterSlider extends React.Component {
  state = {
    values: domain,
    inputValues: domain
  };

  onChange = (values) => {
    const inputValues = values;
    this.setState({ values, inputValues });
  };

  onTextInputChange = (event) => {
    const target = event.target;
    const rawValue = target.value;
    const float = parseFloat(rawValue);
    const index = target.id.includes('min') ? 0 : 1;
    let values = this.state.values.slice();
    let inputValues = this.state.values.slice();

    let value = float;
    if (isNaN(float)) value = values[index]; // ignore invalid input

    values[index] = value;
    inputValues[index] = rawValue;

    this.setState({ values, inputValues });
  }

  render() {
    const {
      state: { values, inputValues }
    } = this;

    return (
      <>
        <input
          id="input-min-organism-age"
          onChange={(event) => this.onTextInputChange(event)}
          type="number"
          min={domain[0]}
          max={domain[1]}
          value={inputValues[0]}
          style={{'width': '60px'}}
        />
        <span style={{'margin': '0 4px 0 4px'}}>-</span>
        <input
          id="input-max-organism-age"
          onChange={(event) => this.onTextInputChange(event)}
          type="number"
          min={domain[0]}
          max={domain[1]}
          value={inputValues[1]}
          style={{'width': '60px', 'marginRight': '8px'}}
        />
        <select>
          <option>Years</option>
          <option>Months</option>
          <option>Weeks</option>
          <option>Days</option>
          <option>Hours</option>
        </select>
        <div style={{ height: 120, width: '100%' }}>
          <Slider
            mode={1}
            step={1}
            domain={domain}
            rootStyle={sliderStyle}
            onChange={this.onChange}
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
}

/**
 * Component for filter list and filter slider
 */
export default function Filters(props) {
  const filters = props.filters;
  // console.log('in Filters, props:')
  // console.log(props)
  if (props.facet.type !== 'number') {
    return <FilterList filters={filters} onClick={props.onClick} />;
  } else {
    return <FilterSlider facet={props.facet} />;
  }
}
