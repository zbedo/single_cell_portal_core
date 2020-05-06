// Without disabling eslint code, Promises are auto inserted
/* eslint-disable*/

import React from 'react'
import { render, fireEvent, waitFor, waitForElementToBeRemoved, screen } from '@testing-library/react'
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

// // https://github.com/wesbos/waait/blob/master/index.js
// export function wait(amount = 0) {
//   return new Promise(resolve => setTimeout(resolve, amount));
// }

// // Use this in your test after mounting if you need just need to let the query finish without updating the wrapper
// export async function actWait(amount = 0) {
//   await act(async () => {
//     await wait(amount);
//   });
// }

// // Use this in your test after mounting if you want the query to finish and update the wrapper
// export async function updateWrapper(wrapper, amount = 0) {
//   await act(async () => {
//     await wait(amount);
//     wrapper.update();
//   });
// }

describe('Violin plot in global gene search', () => {
  beforeEach(() => {
    fetch.resetMocks()
  })

  it('shows studies when empty', async() => {
    fetch.mockResponseOnce(violins)

    render(<StudyViolinPlot study={study} gene={study.gene_matches[0]}/>)

    await waitForElementToBeRemoved(() => screen.getByTestId('expGraph-SCP25-gad2-loading-icon'))

    expect(fetch).toBeCalled()

    // return promise.then(() => {
    //   expect(wrapper.state()).to.have.property('dataReady', true);

    //   wrapper.update();
    // }).then(() => {
    //   expect(wrapper.text()).to.contain('data is ready');
    // });

    // console.log("screen.getByTestId('expGraph-SCP25-gad2')")
    // console.log(screen.getByTestId('expGraph-SCP25-gad2'))

    expect(screen.getAllByTestId('expGraph-SCP25-gad2')).toHaveLength(1)

  })
})
