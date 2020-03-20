import React from 'react'
import * as ReactAll from 'react'
import { highlightText } from '../../app/javascript/components/Study'


const text = 'Study: Single nucleus RNA-seq of cell diversity in the adult mouse hippocampus (sNuc-Seq)'
const highlightedText = 'Study: Single <span id=\'highlight\'>nucleus</span> RNA-seq of cell <span id=\'highlight\'>diversity</span> in the adult mouse hippocampus (sNuc-Seq)'
const unMatchedTerms = ['tuberculosis', 'population']
const matchedTerms = ['nucleus', 'and', 'diversity']

describe('highlightText', () => {
  it('returns unaltered text when there are no matches', () => {
    const unHighlightedText = highlightText(text, unMatchedTerms).styledText
    expect(unHighlightedText).toEqual(text)
  })
  it('returns highlighted text', () => {
    const matchIndexes = matchedTerms.map(term => text.indexOf(term))
    const { styledText, matchedIndices } = highlightText(text, matchedTerms)

    // Check terms were matched in the correct place
    expect(matchedIndices).toEqual(matchIndexes)
    // Check text highlighted properly
    expect(styledText).toEqual(highlightedText)
  })
})
