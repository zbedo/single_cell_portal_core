import React from 'react'
import { mount } from 'enzyme'
import { highlightText, shortenDescription, descriptionWordLimit } from '../../app/javascript/components/Study'


describe('highlightText', () => {
  const text = 'Study: Single nucleus RNA-seq of cell diversity in the adult mouse hippocampus (sNuc-Seq)'
  const highlightedText = 'Study: Single <span id=\'highlight\'>nucleus</span> RNA-seq of cell <span id=\'highlight\'>diversity</span> in the adult mouse hippocampus (sNuc-Seq)'
  const unMatchedTerms = ['tuberculosis', 'population']
  const matchedTerms = ['nucleus', 'and', 'diversity']

  it('returns unaltered text when there are no matches', () => {
    const unhighlightedText = highlightText(text, unMatchedTerms).styledText
    expect(unhighlightedText).toEqual(text)
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

describe('shortenDescription', () => {
  // 845 characters 133 words
  const text = 'This study presents an example analysis of an eye (retina) dataset from the Human Cell Atlas (HCA)\
 Data Coordination Platform (DCP) Project entitled "A single-cell transcriptome atlas of the adult human retina".\
 It is part of the HCA March 2020 Release (INSERT Link to the DCP page) and showcases HCA single-cell data that were\
processed with standardized DCP pipelines, further analyzed by Cumulus (LINK), and annotated using published annotations. \
In this study, you can explore the biological and technical attributes of the analyzed HCA DCP data. Additionally, you can \
view all HCA Release study pages and search genes across all projects by visiting the Single Cell Portal Release Page. Please \
note that Release data is not corrected for batch-effects, but is stratified by organ and (in some cases) developmental stage as described below. '

  // For default state where there are no keyword search inquiries
  it('shortens description for study descriptions > 170 characters', () => {
    const expectedText = text.slice(0, descriptionWordLimit)
    const keywordTerms = []
    const actualText = mount(shortenDescription(text, keywordTerms)).find('.studyDescription').text()
    expect(expectedText).toEqual(actualText)
  })


  // Matches are within 750 character boundary
  it('show matches when matches are within 750 character boundary', () => {
    const expectedText = 'This study presents an example analysis of an eye (retina) dataset from the Human Cell Atlas (HCA) Data Coordination Platform (DCP) Project entitled "A single-cell transcriptome\
 atlas of the adult human retina". It is part of the HCA March 2020 Release (INSERT Link to the DCP page)\
 and showcases HCA single-cell data that wereprocessed with standardized DCP pipelines, further analyzed by\
 Cumulus (LINK), and annotated using published annotations. In this study, you can explore the biological and\
 technical attributes of the analyzed HCA DCP data. Additionally, you can view all HCA Release study pages and\
 search genes across all projects by visiting the Single C'
    const keywordTerms = ['study']
    const wrapper = mount(shortenDescription(text, keywordTerms))
    // Find span tag with openingText
    const openingTextSpan= wrapper.find('span').findWhere(n => n.hasClass('openingText'))
    // Span tag for opening text should not exist
    expect(openingTextSpan).toHaveLength(0)

    // Find span with matched text
    const matchedDescription= wrapper.find('span').findWhere(n => n.hasClass('studyDescription'))
    expect(matchedDescription).toHaveLength(1)
    const actualMatchedDescription = matchedDescription.text()
    expect(actualMatchedDescription).toEqual(expectedText)
  })

  it('shows opening text and matches outside of 750 charcter boundary', () => {
    const expectedOpeningText ='This study presents an example analysis of an eye (retina) dataset from the Human Cell Atlas (HCA) Data Coordination Platform (DCP) Project entitled \" '
    const expectedMatchedDescription= 'hat Release data is not corrected for batch-effects, but is stratified by organ and (in some cases) developmental stage as described below. '
    const keywordTerms = ['developmental']

    const wrapper = mount(shortenDescription(text, keywordTerms))

    // Find span tag with openingText
    const openingTextSpan= wrapper.find('span').findWhere(n => n.hasClass('openingText'))
    expect(openingTextSpan).toHaveLength(1)
    const actualopeningText = openingTextSpan.text()
    expect(actualopeningText).toEqual(expectedOpeningText)


    // Find span with matched text
    const matchedDescription= wrapper.find('span').findWhere(n => n.hasClass('studyDescription'))
    expect(matchedDescription).toHaveLength(1)
    const actualMatchedDescription = matchedDescription.text()
    expect(actualMatchedDescription).toEqual(expectedMatchedDescription)
  })
})
