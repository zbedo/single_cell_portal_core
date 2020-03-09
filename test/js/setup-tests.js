import { configure } from 'enzyme'
import Adapter from 'enzyme-adapter-react-16'

configure({ adapter: new Adapter() })

import {
  setGlobalMockFlag,
  setMockOrigin
} from '../../app/javascript/lib/scp-api'

setGlobalMockFlag(true)
setMockOrigin('http://localhost:3000')

// convert scrolls to no-ops as otherwise they will error
global.scrollTo = jest.fn()
