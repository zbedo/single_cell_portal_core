/* eslint-disable require-jsdoc */
import React from 'react'

const descriptionWordLimit = 750
const summaryWordLimit = 150
const lengthOfHighlightTag = 21

/* converts description into text snippet */
export function formatDescription(rawDescription, term) {
  const textDescription = stripTags(rawDescription)
  return shortenDescription(textDescription, term)
}

function highlightText(text, termMatches) {
  const matchedIndices = []
  if (termMatches) {
    termMatches.forEach((term, index) => {
      let match
      const regex = RegExp(term, 'gi')
      // Find indices where match occured
      while ((match = regex.exec(text)) != null) {
        matchedIndices.push(match.index)
      }
    })
    if (matchedIndices.length>0) {
      termMatches.forEach((term, index) => {
        const regex = RegExp(term, 'gi')
        text = text.replace(regex, `<span id='highlight'>${term}</span>`)
      })
    }
  }
  return { styledText: text, matchedIndices }
}

function shortenDescription(textDescription, term) {
  const { styledText, matchedIndices } = highlightText(textDescription, term)
  const suffixTag = <span className="detail"> ...(continued)</span>

  // Check if there are matches outside of the descriptionWordLimit
  if (matchedIndices.some(matchedIndex => matchedIndex >= descriptionWordLimit)) {
    // Find matches occur outside descriptionWordLimit
    const matchesOutSideDescriptionWordLimit = matchedIndices.filter(matchedIndex => matchedIndex>descriptionWordLimit)

    const firstIndex = matchesOutSideDescriptionWordLimit[0]
    // Find matches that fit within the n+descriptionWordLimit
    const ranges = matchesOutSideDescriptionWordLimit.filter(index => index < descriptionWordLimit+firstIndex)
    // Determine where start and end index to ensure matched keywords are included
    const start = ((matchedIndices.length- matchesOutSideDescriptionWordLimit.length)*(lengthOfHighlightTag+term.length)) +firstIndex
    const end = start + descriptionWordLimit + (ranges.length*(lengthOfHighlightTag+term.length))
    const descriptionText = styledText.slice(start-100, end)
    const displayedStudyDescription = { __html: descriptionText }
    // Determine if there are matches to display in summary paragraph
    const amountOfMatchesInSummaryWordLimit = matchedIndices.filter(matchedIndex => matchedIndex <= summaryWordLimit).length
    if (amountOfMatchesInSummaryWordLimit>0) {
      //  Need to recaluculate index positions because added html changes size of textDescription
      const beginningTextIndex= (amountOfMatchesInSummaryWordLimit *(lengthOfHighlightTag+term.length))
      const displayedBeginningText = { __html: styledText.slice(0, beginningTextIndex+summaryWordLimit) }
      return <><span dangerouslySetInnerHTML={displayedBeginningText}></span> <span className="detail">... </span><span dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}</>
    }
    const displayedBeginningText = styledText.slice(0, summaryWordLimit)
    return <><span>{displayedBeginningText} </span><span className="detail">... </span> <span dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}</>
  }
  const displayedStudyDescription = { __html: styledText.slice(0, descriptionWordLimit) }
  if (textDescription.length>descriptionWordLimit) {
    return <><span dangerouslySetInnerHTML={displayedStudyDescription}></span>{suffixTag}</>
  } else {
    return <><span dangerouslySetInnerHTML={displayedStudyDescription}></span></>
  }
}

/* removes html tags from a string */
function stripTags(rawString) {
  const tempDiv = document.createElement('div')
  // Set the HTML content with the provided
  tempDiv.innerHTML = rawString
  // Retrieve the text property of the element
  return tempDiv.textContent || ''
}

/* generate a badge for each matched facet, containing the filter names */
function facetMatchBadges(study) {
  const matches = study.facet_matches
  if (!matches) {
    return <></>
  }
  const matched_keys = Object.keys(matches)
                       .filter(key => key != 'facet_search_weight')
  return (<>
    { matched_keys.map((key, index) => {
      const helpText = `Metadata match for ${key}`
      return (
        <span key={index}
          className="badge badge-secondary facet-match"
          data-toggle="tooltip"
          title={helpText}>
          {
            matches[key].map(filter => {
              if (filter.min) { // numeric facet
                return `${key} ${filter.min}-${filter.max} ${filter.unit}`
              } else {
                return filter.name
              }
            }).join(',')
          }
        </span>)
    })}
  </>)
}

/* displays a brief summary of a study, with a link to the study page */
export default function Study({ study }) {
  const { term_matches, facets } = study
  const studyTitle= highlightText(study.name, term_matches).styledText
  const studyDescription = formatDescription(study.description, term_matches)
  const displayStudyTitle = { __html: studyTitle }

  let inferredBadge = <></>
  if (study.inferred_match) {
    const helpText = `${study.term_matches.join(', ')} was not found in study metadata, only in study title or description`
    inferredBadge = <span className="badge soft-badge" data-toggle="tooltip" title={helpText}>text match only</span>
  }

  return (
    <>
      <div key={study.accession}>
        <label htmlFor={study.name} id= 'result-title'>
          <a href={study.study_url} dangerouslySetInnerHTML = {displayStudyTitle}></a>{inferredBadge}
        </label>
        <div>
          <span className='badge badge-secondary cell-count'>
            {study.cell_count} Cells
          </span>
          { facetMatchBadges(study) }
        </div>
        {studyDescription}
      </div>
    </>
  )
}
