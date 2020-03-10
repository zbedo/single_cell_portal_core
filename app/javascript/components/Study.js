import React from 'react'

const descriptionCharLimit = 750

export function formatDescription(rawDescription) {

  let textDescription = stripTags(rawDescription)
  let suffixString = ''
  if (textDescription.length > descriptionCharLimit) {
    suffixString = '... (continued)'
  }
  return `${textDescription.substring(0, descriptionCharLimit)}${suffixString}`
}

function stripTags(rawString) {
  let tempDiv = document.createElement('div');
  // Set the HTML content with the providen
  tempDiv.innerHTML = rawString;
  // Retrieve the text property of the element
  return tempDiv.textContent || '';
}

export default function Study(props) {
  const studyDescription = { __html: formatDescription(props.study.description) }

  return (
    <div key={props.study.accession}>
      <label htmlFor={props.study.name} id= 'result-title'>
        <a href={props.study.study_url}>{props.study.name} </a></label>
      <div>
        <span id='cell-count' className='badge badge-secondary'>{props.study.cell_count} Cells </span>
      </div>
      <span dangerouslySetInnerHTML={studyDescription} id='descrition-text-area' disabled accession = {props.study.name}></span>
    </div>
  )
}