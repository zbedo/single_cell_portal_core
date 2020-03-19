import React from 'react'

const descriptionWordLimit = 100

/* converts description into text snippet */
export function formatDescription(rawDescription) {
  const textDescription = stripTags(rawDescription)
  return shortenDescription(textDescription)
}

// return the first 100 words, with a '...' appended if needed'
// this returns a node, not text, so we can italicize 'continued'
function shortenDescription(textDescription) {
  const wordArray = textDescription.split(' ')
  const numWords = wordArray.length
  // take the first 100 words, or the whole thing if shorter
  const shortenedText = wordArray.slice(0, descriptionWordLimit - 1)
                                 .join(' ')

  let suffixTag = <></>
  if (numWords > descriptionWordLimit) {
    suffixTag = <span className="detail"> ...(continued)</span>
  }
  return <span>{shortenedText}{suffixTag}</span>
}

/* removes html tags from a string */
function stripTags(rawString) {
  const tempDiv = document.createElement('div')
  // Set the HTML content with the providen
  tempDiv.innerHTML = rawString
  // Retrieve the text property of the element
  return tempDiv.textContent || ''
}

/* displays a brief summary of a study, with a link to the study page */
export default function Study({study}) {
  const studyDescription = formatDescription(study.description)
  let inferredBadge = <></>
  if (study.inferred_match) {
    const helpText = `${study.term_matches.join(', ')} was not found in study metadata, only in study title or description`
    inferredBadge = <span className="badge soft-badge"  data-toggle="tooltip" title={helpText}>text match only</span>
  }

  return (
    <>
      <label htmlFor={study.name} id= 'result-title'>
        <a href={study.study_url}>{study.name} </a> {inferredBadge}</label>
      <div>
        <span id='cell-count' className='badge badge-secondary'>
          {study.cell_count} Cells
        </span>
      </div>
      {studyDescription}
    </>
  )
}
