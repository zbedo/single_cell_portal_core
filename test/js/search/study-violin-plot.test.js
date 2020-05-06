// Without disabling eslint code, Promises are auto inserted
/* eslint-disable*/

import React from 'react'
import { render, queryByAttribute,  waitForElementToBeRemoved, screen } from '@testing-library/react'
import { act } from 'react-dom/test-utils';
import camelcaseKeys from 'camelcase-keys'

import { enableFetchMocks } from 'jest-fetch-mock'
enableFetchMocks()

import StudyViolinPlot from 'components/search/genes/StudyViolinPlot'

const fs = require('fs')

const mockStudyPath = 'public/mock_data/search/violin_plot/study.json'
const study = JSON.parse(fs.readFileSync(mockStudyPath), 'utf8')

const mockViolinsPath =
  'public/mock_data/search/violin_plot/expression_violin_api.json'
const violins = fs.readFileSync(mockViolinsPath)

describe('Violin plot in global gene search', () => {
  beforeEach(() => {
    fetch.resetMocks()
  })

  it('constructs Plotly chart', async() => {
    fetch.mockResponseOnce(violins)

    render(<StudyViolinPlot study={study} gene={study.gene_matches[0]}/>)

    await waitForElementToBeRemoved(() => screen.getByTestId('expGraph-SCP25-gad2-loading-icon'))

    // console.log("screen.getByTestId('expGraph-SCP25-gad2').data[0].y.length")
    // console.log(screen.getByTestId('expGraph-SCP25-gad2').data[0].y.length)

    expect(screen.getAllByTestId('expGraph-SCP25-gad2')).toHaveLength(1)

    expect(screen.getByTestId('expGraph-SCP25-gad2').data[0].y).toHaveLength(4548)

  })
})
