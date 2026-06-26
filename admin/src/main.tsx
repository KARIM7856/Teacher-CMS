import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { DirectionProvider, MantineProvider } from '@mantine/core'
import { ModalsProvider } from '@mantine/modals'
import { Notifications } from '@mantine/notifications'
import '@mantine/core/styles.css'
import '@mantine/notifications/styles.css'
import './index.css'
import { theme } from './theme'
import { AuthProvider } from './auth/AuthProvider'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <DirectionProvider initialDirection="rtl">
      <MantineProvider theme={theme} defaultColorScheme="light">
        <Notifications position="top-center" />
        <ModalsProvider>
          <AuthProvider>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </AuthProvider>
        </ModalsProvider>
      </MantineProvider>
    </DirectionProvider>
  </React.StrictMode>,
)
