import React, { useState, useEffect, useRef, useContext } from 'react'

export default function useCloseableModal(show, setShow) {
   const clearNode = useRef()
  /**
    * Click on the facet control itself
    */
  function handleButtonClick(e) {
    if (clearNode.current && clearNode.current.contains(e.target)) {
      setShow(false)
    } else {
      setShow(!show)
    }
  }

  /**
    * Clear the selection and update search results
    */
  function clearFacet() {
    selectionContext.updateFacet(props.facet.id, [], true)
  }


  const node = useRef()
  const handleOtherClick = e => {
    if (node.current.contains(e.target)) {
      // click was inside the modal, do nothing
      return
    }
    setShow(false)
  }

  // add event listener to detect clicks outside the modal,
  // so we know to close it
  // see https://medium.com/@pitipatdop/little-neat-trick-to-capture-click-outside-with-react-hook-ba77c37c7e82
  useEffect(() => {
    // add when mounted
    document.addEventListener('mousedown', handleOtherClick)
    // return function to be called when unmounted
    return () => {
      document.removeEventListener('mousedown', handleOtherClick)
    }
  }, [])

  return { node, clearNode, handleButtonClick }
}
