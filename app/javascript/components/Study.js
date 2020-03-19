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

function highlightText(text, terms) {
  const matchedIndicies = []
  if (terms) {
    let match
    const regex = RegExp(terms, 'gi')
    // Find indices where match occured
    while ((match = regex.exec(text)) != null) {
      matchedIndicies.push(match.index)
    }
    if (matchedIndicies.length>0) {
      return { styledText: text.replace(regex, `<span id='highlight'>${terms}</span>`), matchedIndicies }
    }
  }
  return { styledText: text, matchedIndicies }
}

function shortenDescription(textDescription, term) {
  const { styledText, matchedIndicies } = highlightText(textDescription, term)
  const suffixTag = <span className="detail"> ...(continued)</span>

  // Check if there are matches outside of the descriptionWordLimit
  if (matchedIndicies.some(matchedIndex => matchedIndex >= descriptionWordLimit)) {
    // Find matches occur outside descriptionWordLimit
    const matchesOutSideDescriptionWordLimit = matchedIndicies.filter(matchedIndex => matchedIndex>descriptionWordLimit)

    const firstIndex = matchesOutSideDescriptionWordLimit[0]
    // Find matches that fit within the n+descriptionWordLimit
    const ranges = matchesOutSideDescriptionWordLimit.filter(index => index < descriptionWordLimit+firstIndex)
    // Determine where start and end index to ensure matched keywords are included
    const start = ((matchedIndicies.length- matchesOutSideDescriptionWordLimit.length)*(lengthOfHighlightTag+term.length)) +firstIndex
    const end = start + descriptionWordLimit + (ranges.length*(lengthOfHighlightTag+term.length))
    const descriptionText = styledText.slice(start-100, end)
    const displayedStudyDescription = { __html: descriptionText }
    // Determine if there are matches to display in summary paragraph
    const amountOfMatchesInSummaryWordLimit = matchedIndicies.filter(matchedIndex => matchedIndex <= summaryWordLimit).length
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

/* displays a brief summary of a study, with a link to the study page */
export default function Study(props) {
  const { terms, facets } = props
  const studyTitle= highlightText(props.study.name, terms).styledText
  const studyDescription = formatDescription(props.study.description, terms)
  const displayStudyTitle = { __html: studyTitle }


  return (
    <div key={props.study.accession}>
      <label htmlFor={props.study.name} id= 'result-title'>
        <a href={props.study.study_url} dangerouslySetInnerHTML = {displayStudyTitle}></a>
      </label>
      <div>
        <span id='cell-count' className='badge badge-secondary'>
          {props.study.cell_count} Cells
        </span>
      </div>
      {studyDescription}
    </div>
  )
}
