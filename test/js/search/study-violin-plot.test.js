// Without disabling eslint code, Promises are auto inserted
/* eslint-disable*/

import React from 'react'
import { render, waitForElementToBeRemoved, screen } from '@testing-library/react'
import { enableFetchMocks } from 'jest-fetch-mock'

import StudyViolinPlot from 'components/search/genes/StudyViolinPlot'
import * as plotLib from 'lib/plot'

const fs = require('fs')

enableFetchMocks()

const mockStudyPath = 'public/mock_data/search/violin_plot/study_small_intestinal_epithelium.json'
const study = JSON.parse(fs.readFileSync(mockStudyPath), 'utf8')

const mockViolinsPath =
  'public/mock_data/search/violin_plot/expression_violin_mrpl15_small_intestinal_epithelium.json'
const violins = fs.readFileSync(mockViolinsPath)

describe('Violin plot in global gene search', () => {
  beforeEach(() => {
    fetch.resetMocks()
  })

  it('configures Plotly violin plot', async() => {
    fetch.mockResponseOnce(violins)
    const mockPlot = jest.spyOn(plotLib, 'plot');
    mockPlot.mockImplementation(() => {});

    render(<StudyViolinPlot study={study} gene={study.gene_matches[0]}/>)

    await waitForElementToBeRemoved(() => screen.getByTestId('expGraph-SCP25-mrpl15-loading-icon'))

    var args = mockPlot.mock.calls[0];

    expect(args[0]).toBe('expGraph-SCP25-mrpl15')

    const firstTrace = args[1][0]
    expect(firstTrace.type).toBe('violin')
    expect(firstTrace.name).toBe('Enterocyte.Immature.Distal')
    expect(firstTrace.y).toHaveLength(512)

    expect(args[2].xaxis.type).toBe('category')

  })

})
