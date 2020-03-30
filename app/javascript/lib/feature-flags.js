export function getFlagValue(flagId) {
  return getAllFlags()[flagId]
}

export function getAllFlags() {
  // for now, read it off the home page.  Eventually, this will want to be an API call
  return JSON.parse($('#feature-flags').attr('value'))
}
