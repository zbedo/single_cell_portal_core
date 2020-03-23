import React from 'react'
import { mount } from 'enzyme'
import { highlightText, shortenDescription, descriptionWordLimit, summaryWordLimit, stripTags } from '../../app/javascript/components/Study'


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
    const actualText = mount(shortenDescription(text, keywordTerms)).find('#studyDescription').text()
    expect(expectedText).toEqual(actualText)
  })


  // Matches are within 750 character boundary
  // it('shortens description for study descriptions > 170 characters', () => {
  //   const expectedText = 'This study presents an example analysis of a decidua dataset from the Human Cell Atlas (HCA) \
  //   Data Coordination Platform (DCP) Project entitled "Reconstructing the human first trimester fetal-maternal     \
  //   interface using single cell transcriptomics". It is part of the HCA March 2020 Release (INSERT Link to the DCP page)     \
  //   and showcases HCA single-cell data that were processed with standardized DCP pipelines, further analyzed by Cumulus (LINK)      \
  //   , and annotated using published annotations. In this study, you can explore the biological and technical attributes of the analyzed HCA DCP data.      \
  //   Additionally, you can view all HCA Release study pages and'
  //   const actualText = mount(shortenDescription(text, ['study']))
  //   console.log(actualText.find('span'))
  //   expect(actualText.find('span')[0].text()).toEqual(expectedText)
  // })

  // Matches are outside of 750 charcter boundary

  // Matches are within 100 summary work boundary, and outside 750 charcter boundary
})
