import { configure } from 'enzyme'
import Adapter from 'enzyme-adapter-react-16'

configure({ adapter: new Adapter() })

import { setGlobalMockFlag, setMockOrigin } from 'lib/scp-api'

setGlobalMockFlag(true)
if (process.env.NOT_DOCKERIZED) {
  setMockOrigin('http://localhost:3000')
} else {
  setMockOrigin('https://localhost')
}

// convert scrolls to no-ops as otherwise they will error
global.scrollTo = jest.fn()

// Google Analytics fallback: remove once Bard and Mixpanel are ready for SCP
// This enables tests for SCP
global.ga = function(mock1, mock2, mock3, mock4) {
  return
}
