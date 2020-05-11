import Plotly from 'plotly.js-dist'

/**
 * Plots expression data
 *
 * Having this function in a separate module is needed for mocking in related
 * test (study-violin-plot.test.js), due to (1) and buggy workaround (2).
 *
 * 1) SVG path getTotalLength method is undefined in jsdom library used by Jest
 *    Details: https://github.com/jsdom/jsdom/issues/1330
 *
 * 2) jest.mock() does not work when module name has ".js" in it
 *    Details: https://github.com/facebook/jest/issues/6420
 */
export function plot(graphElementId, expressionData, expressionLayout) {
  Plotly.newPlot(
    graphElementId,
    expressionData,
    expressionLayout
  )
}
