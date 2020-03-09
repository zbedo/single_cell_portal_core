import React, { useContext } from 'react'

// window.SCP is not available when running via Jest tests,
// so default such cases to a blank string
const accessToken = 'SCP' in window ? window.SCP.userAccessToken : ''

const user = {
  accessToken
}

export const UserContext = React.createContext(user)

export function useContextUser() {
  return useContext(UserContext)
}

export default function UserProvider(props) {
  return (
    <UserContext.Provider value={user}>
      { props.children }
    </UserContext.Provider>
  )
}
