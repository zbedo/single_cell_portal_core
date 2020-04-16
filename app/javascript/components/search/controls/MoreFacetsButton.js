import React, { useState, useRef, useEffect, useContext } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faSlidersH } from '@fortawesome/free-solid-svg-icons'

import FacetsAccordion from './FacetsAccordion'
import { StudySearchContext } from 'providers/StudySearchProvider'

/**
 * Component for "More Facets" button.  Clicking shows facets accordion box.
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387756/preview
 */
export default function MoreFacetsButton(props) {
  const searchContext = useContext(StudySearchContext)
  const [show, setShow] = useState(false)

  // const facetName = props.facet.name;

  function handleClick() {
    setShow(!show)
  }

  // add event listener to detect mouseclicks outside the accordion, so we
  // know to close it if we have any more controls like this, consider a HOC
  // or custom hook for this behavior (shared in FacetControl as well)
  useEffect(() => {
    // add when mounted
    document.addEventListener('mousedown', handleOtherClick)
    // return function to be called when unmounted
    return () => {
      document.removeEventListener('mousedown', handleOtherClick)
    }
  }, [])

  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return
    }
    setShow(false)
  }

  const numFacetsApplied = props.facets.filter(facet => {
    const facets = searchContext.params.facets
    return facets[facet.id] && facets[facet.id].length
  }).length
  const facetCountString = numFacetsApplied > 0 ? `(${numFacetsApplied})` : ''

  return (
    <span
      id='more-facets-button'
      className={`${show || numFacetsApplied ? 'active' : ''} facet`}
      ref={node}>
      <a
        onClick={handleClick}>
        <FontAwesomeIcon className="icon-left" icon={faSlidersH}/>
          More Facets { facetCountString }
      </a>
      {show && <FacetsAccordion facets={props.facets} setShow={setShow} />}
    </span>
  )
}
