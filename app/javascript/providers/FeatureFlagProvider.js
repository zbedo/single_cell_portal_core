import React from 'react'
import $ from 'jquery'

export function getAllFlags() {
  // for now, read it off the home page.  Eventually, this will want to be an API call
  return JSON.parse($('#feature-flags').attr('value'))
}

export const FeatureFlagContext = React.createContext({})

export default function FeatureFlagProvider(props) {
  const flagState = getAllFlags()
  return (
    <FeatureFlagContext.Provider value={flagState}>
      { props.children }
    </FeatureFlagContext.Provider>
  )
}
