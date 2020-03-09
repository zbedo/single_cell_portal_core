/**
 * Slider components that are not part of react-compound-slider package
 *
 * Source (Typescript): https://codesandbox.io/s/zl8nrlp9x
 * Converted to ES6 via https://www.typescriptlang.org/play
 */

import * as React from 'react'
// *******************************************************
// RAIL
// *******************************************************
const railOuterStyle = {
  position: 'absolute',
  width: '100%',
  height: 42,
  // transform: 'translate(0%, -50%)',
  borderRadius: 7,
  cursor: 'pointer'
}
const railInnerStyle = {
  position: 'absolute',
  width: '100%',
  height: 14,
  // transform: 'translate(0%, -50%)',
  borderRadius: 7,
  pointerEvents: 'none',
  backgroundColor: 'rgb(155,155,155)'
}
export const SliderRail = ({ getRailProps }) => {
  return (React.createElement(React.Fragment, null,
    React.createElement('div',
      Object.assign({ style: railOuterStyle }, getRailProps())
    ),
    React.createElement('div', { style: railInnerStyle })))
}
export const Handle = ({
  domain: [min, max],
  handle: { id, value, percent },
  disabled = false, getHandleProps
}) => {
  return (React.createElement(React.Fragment, null,
    React.createElement('div', Object.assign({
      style: {
        left: `${percent}%`,
        position: 'absolute',
        transform: 'translate(-50%, -25%)',
        WebkitTapHighlightColor: 'rgba(0,0,0,0)',
        zIndex: 5,
        width: 28,
        height: 42,
        cursor: 'pointer',
        backgroundColor: 'none'
      }
    }, getHandleProps(id))),
    React.createElement('div', {
      'role': 'slider',
      'aria-valuemin': min,
      'aria-valuemax': max,
      'aria-valuenow': value,
      'style': {
        left: `${percent}%`,
        position: 'absolute',
        transform: 'translate(-50%, -25%)',
        zIndex: 2,
        width: 24,
        height: 24,
        borderRadius: '50%',
        boxShadow: '1px 1px 1px 1px rgba(0, 0, 0, 0.3)',
        backgroundColor: disabled ? '#666' : '#9BBFD4'
      }
    })))
}
// *******************************************************
// KEYBOARD HANDLE COMPONENT
// Uses a button to allow keyboard events
// *******************************************************
export const KeyboardHandle = ({
  domain: [min, max],
  handle: { id, value, percent },
  disabled = false,
  getHandleProps
}) => {
  return (React.createElement('button', Object.assign({
    'role': 'slider',
    'aria-valuemin': min,
    'aria-valuemax': max,
    'aria-valuenow': value,
    'style': {
      left: `${percent}%`,
      position: 'absolute',
      transform: 'translate(-50%, -50%)',
      zIndex: 2,
      width: 24,
      height: 24,
      borderRadius: '50%',
      boxShadow: '1px 1px 1px 1px rgba(0, 0, 0, 0.3)',
      backgroundColor: disabled ? '#666' : '#9BBFD4'
    }
  }, getHandleProps(id))))
}
export const Track = ({ source, target, getTrackProps, disabled = false }) => {
  return (React.createElement('div', Object.assign({
    style: {
      position: 'absolute',
      // transform: 'translate(0%, -50%)',
      height: 14,
      zIndex: 1,
      backgroundColor: disabled ? '#999' : '#607E9E',
      borderRadius: 7,
      cursor: 'pointer',
      left: `${source.percent}%`,
      width: `${target.percent - source.percent}%`
    }
  }, getTrackProps())))
}
export const Tick = ({ tick, count, format = d => d }) => {
  return (React.createElement('div', null,
    React.createElement('div', {
      style: {
        position: 'absolute',
        marginTop: 14,
        width: 1,
        height: 5,
        backgroundColor: 'rgb(200,200,200)',
        left: `${tick.percent}%`
      }
    }),
    React.createElement('div', {
      style: {
        position: 'absolute',
        marginTop: 22,
        fontSize: 14,
        textAlign: 'center',
        marginLeft: `${-(100 / count) / 2}%`,
        width: `${100 / count}%`,
        left: `${tick.percent}%`
      }
    }, format(tick.value))))
}

